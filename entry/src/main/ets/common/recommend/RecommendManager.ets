/**
 * 推荐系统单例管理器：曝光批次管理、样本生成、FTRL 训练调度、激活状态机、持久化、配置缓存
 * 所有数据仅保存在本机，不上传
 */
import { ForumThreadDisplayOrder } from '../../api/model/thread'
import { PreferenceManager } from '../../config/UserConfig'
import { readJson, removeJson, writeJson } from '../dataStore/JsonPersist'
import {
  ADJUSTABLE_GROUP_COUNT,
  FeatureExtractor,
  SparseFeature,
  ThreadFeatureInput,
  ThreadTextFeature
} from './FeatureExtractor'
import { computeAUC, EvalEntry, FtrlModel } from './FtrlModel'

export enum RecommendState {
  collecting = 0,
  active = 1,
  degraded = 2
}

export interface RecommendExposureItem {
  tid: string
  fid: string
  typeid: string
  subject: string
  message: string
  replyMessages: string[]
  replies: number
  displayOrder: ForumThreadDisplayOrder
  viewedReply?: number // 上次查看时数据库记录的回帖数（含主楼），undefined 表示从未看过
}

export interface RecommendStatus {
  state: RecommendState
  sampleCount: number
  clickSampleCount: number
  aucHistory: number[]
  lastAuc: number // -1 表示暂无
  bufferPositives: number
}

interface BatchEntry {
  tid: string
  features: SparseFeature[]
  score: number // 曝光时刻的预测分数，用于 prequential AUC
  resolved: boolean
}

interface ExposureBatch {
  key: string
  fid: string
  createdAt: number
  entries: Map<string, BatchEntry>
}

interface PendingClick {
  tid: string
  ts: number
  features: SparseFeature[]
}

interface PersistClick {
  ts: number
  features: SparseFeature[]
}

interface RecommendModelData {
  version: number
  alpha: number
  beta: number
  l1: number
  l2: number
  z: Record<string, number>
  n: Record<string, number>
  expoCounts: Record<string, number>
  clickCounts: Record<string, number>
  sampleCount: number
  clickSampleCount: number
  state: number
  degradedStreak: number
  aucHistory: number[]
  evalBuffer: EvalEntry[]
  pendingClicks: Record<string, PersistClick>
}

const MODEL_VERSION = 1
export const RECOMMEND_MIN_SAMPLES = 300
export const RECOMMEND_MIN_CLICKS = 40
const MIN_BUFFER_POSITIVES = 20
const AUC_ACTIVATE = 0.65
const AUC_DEGRADED = 0.55
const DEGRADED_STREAK_LIMIT = 5
const EVAL_BUFFER_MAX = 500
const AUC_HISTORY_MAX = 30
const COUNTER_MAX = 2000
const SNAPSHOT_CACHE_MAX = 300
const BATCH_TIMEOUT_MS = 30 * 60 * 1000
const PERSIST_INTERVAL_MS = 60 * 1000
const PERSIST_WEIGHT_EPS = 1e-4
/** 高亮门槛：分数需达到用户滚动点击基准率的倍数（封顶），全都不感兴趣时自然无高亮 */
const SCORE_GATE_RATIO = 2
const SCORE_GATE_CAP = 0.8

class RecommendManager {
  private uid: string = 'guest'
  private loaded: boolean = false
  private loading?: Promise<void>
  private model: FtrlModel = new FtrlModel()
  private extractor: FeatureExtractor = new FeatureExtractor()
  private expoCounts: Map<string, number> = new Map()
  private clickCounts: Map<string, number> = new Map()
  private sampleCount: number = 0
  private clickSampleCount: number = 0
  private state: RecommendState = RecommendState.collecting
  private degradedStreak: number = 0
  private aucHistory: number[] = []
  private evalBuffer: EvalEntry[] = []
  private pendingClicks: Map<string, PendingClick> = new Map()
  private enterTs: Map<string, number> = new Map()
  private featureSnapshots: Map<string, SparseFeature[]> = new Map()
  private batch?: ExposureBatch
  private enabled: boolean = false
  private topK: number = 3
  private groupWeights: number[] = [1, 1, 1, 1, 1, 1, 1]
  private lastPersist: number = 0
  private persisting: boolean = false

  async ensureLoaded(): Promise<void> {
    if (this.loaded) {
      return
    }
    if (!this.loading) {
      this.loading = this.load()
    }
    await this.loading
  }

  private async load(): Promise<void> {
    await this.refreshConfig()
    let data = await readJson<RecommendModelData>('recommend', this.uid)
    if (data && data.version === MODEL_VERSION) {
      try {
        this.restore(data)
      } catch (e) {
        console.error('recommend model restore failed, reset to initial')
        this.resetMemory()
      }
    }
    this.loaded = true
    this.backfillPendingClicks()
    this.schedulePersist()
  }

  private restore(data: RecommendModelData): void {
    this.model = new FtrlModel()
    this.model.alpha = data.alpha
    this.model.beta = data.beta
    this.model.l1 = data.l1
    this.model.l2 = data.l2
    Object.keys(data.z).forEach(k => this.model.z.set(Number(k), data.z[k]))
    Object.keys(data.n).forEach(k => this.model.n.set(Number(k), data.n[k]))
    this.expoCounts = new Map()
    Object.keys(data.expoCounts).forEach(k => this.expoCounts.set(k, data.expoCounts[k]))
    this.clickCounts = new Map()
    Object.keys(data.clickCounts).forEach(k => this.clickCounts.set(k, data.clickCounts[k]))
    this.sampleCount = data.sampleCount
    this.clickSampleCount = data.clickSampleCount
    this.state = data.state as RecommendState
    this.degradedStreak = data.degradedStreak
    this.aucHistory = data.aucHistory
    this.evalBuffer = data.evalBuffer
    this.pendingClicks = new Map()
    Object.keys(data.pendingClicks).forEach(tid => {
      const p = data.pendingClicks[tid]
      this.pendingClicks.set(tid, { tid: tid, ts: p.ts, features: p.features })
    })
  }

  /** 点击后直接杀进程（无 dwell）时，加载后以 w=1 兜底补生成正样本 */
  private backfillPendingClicks(): void {
    this.pendingClicks.forEach((pending: PendingClick) => {
      if (pending.features.length == 0) {
        return
      }
      const p = this.model.predict(pending.features)
      this.model.update(pending.features, 1, 1)
      this.sampleCount++
      this.clickSampleCount++
      this.pushEval({ p: p, y: 1 })
    })
    this.pendingClicks.clear()
    this.enterTs.clear()
  }

  private resetMemory(): void {
    this.model = new FtrlModel()
    this.expoCounts = new Map()
    this.clickCounts = new Map()
    this.sampleCount = 0
    this.clickSampleCount = 0
    this.state = RecommendState.collecting
    this.degradedStreak = 0
    this.aucHistory = []
    this.evalBuffer = []
    this.pendingClicks = new Map()
    this.enterTs = new Map()
    this.featureSnapshots = new Map()
    this.batch = undefined
  }

  /** 账号切换时重新加载对应 uid 的模型（参照 HistoryDbSetUser 时机调用） */
  async setUser(uid: string): Promise<void> {
    const normalized = uid.length > 0 ? uid : 'guest'
    if (normalized === this.uid) {
      return
    }
    if (this.loaded) {
      await this.persistNow()
    }
    this.uid = normalized
    this.loaded = false
    this.loading = undefined
    this.resetMemory()
    this.extractor = new FeatureExtractor()
    await this.ensureLoaded()
  }

  /** 重新读取配置缓存（开关/K/权重变更后由 UI 调用；曝光时也会自动刷新） */
  async refreshConfig(): Promise<void> {
    await PreferenceManager.readonly(conf => {
      this.enabled = conf.recommend_enabled
      this.topK = conf.recommend_top_k
      const w = conf.recommend_weights
      this.groupWeights = [w.board, w.type, w.titleText, w.contentText, w.hot, w.fresh, w.history]
    })
  }

  private isEligible(item: RecommendExposureItem): boolean {
    if (item.displayOrder == ForumThreadDisplayOrder.top) {
      return false
    }
    if (item.viewedReply === undefined) {
      return true
    }
    // 已看过且自上次查看以来无新增回帖（v.replies 未计入主楼，数据库记录计入了主楼，需要 +1 对齐）
    return item.replies + 1 - item.viewedReply > 0
  }

  private newReplyCount(item: RecommendExposureItem): number {
    if (item.viewedReply === undefined) {
      return item.replies
    }
    return item.replies + 1 - item.viewedReply
  }

  private createBatch(pageKey: string, fid: string, items: RecommendExposureItem[]): void {
    const entries = new Map<string, BatchEntry>()
    items.forEach(item => {
      if (!this.isEligible(item)) {
        return
      }
      const expo = (this.expoCounts.get(item.tid) || 0) + 1
      this.expoCounts.set(item.tid, expo)
      const input: ThreadFeatureInput = {
        tid: item.tid,
        fid: item.fid,
        typeid: item.typeid,
        subject: item.subject,
        message: item.message,
        replyMessages: item.replyMessages,
        replies: item.replies,
        newReplies: this.newReplyCount(item),
        viewed: item.viewedReply !== undefined
      }
      const text: ThreadTextFeature = this.extractor.getTextFeatures(input)
      const features = this.extractor.buildFeatures(input, text, expo, this.clickCounts.get(item.tid) || 0)
      this.featureSnapshots.delete(item.tid)
      this.featureSnapshots.set(item.tid, features)
      entries.set(item.tid, {
        tid: item.tid,
        features: features,
        score: this.model.predict(features, this.groupWeights),
        resolved: false
      })
    })
    this.batch = { key: pageKey, fid: fid, createdAt: Date.now(), entries: entries }
    while (this.featureSnapshots.size > SNAPSHOT_CACHE_MAX) {
      const oldest = Array.from(this.featureSnapshots.keys())[0]
      if (oldest === undefined) {
        break
      }
      this.featureSnapshots.delete(oldest)
    }
  }

  /** 打分并返回 Top K tid 集合（仅 ACTIVE 状态返回非空集合） */
  private scoreBatch(batch: ExposureBatch): Set<string> {
    const top: Set<string> = new Set()
    if (this.state != RecommendState.active || batch.entries.size == 0) {
      return top
    }
    const base = this.bufferPositiveCount() / this.evalBuffer.length
    if (this.evalBuffer.length == 0 || base <= 0) {
      // 无正样本基准（如长期无任何点击）时无法判断兴趣，保守不高亮
      return top
    }
    const threshold = Math.min(base * SCORE_GATE_RATIO, SCORE_GATE_CAP)
    const ranked: BatchEntry[] = Array.from(batch.entries.values())
    ranked.sort((a: BatchEntry, b: BatchEntry): number => b.score - a.score)
    let picked = 0
    for (let i = 0; i < ranked.length && picked < this.topK; i++) {
      if (ranked[i].score < threshold) {
        break
      }
      top.add(ranked[i].tid)
      picked++
    }
    return top
  }

  private pushEval(entry: EvalEntry): void {
    this.evalBuffer.push(entry)
    if (this.evalBuffer.length > EVAL_BUFFER_MAX) {
      this.evalBuffer.shift()
    }
  }

  private bufferPositiveCount(): number {
    let count = 0
    this.evalBuffer.forEach(e => {
      if (e.y > 0) {
        count++
      }
    })
    return count
  }

  private updateState(auc: number): void {
    const condB = auc >= AUC_ACTIVATE && this.bufferPositiveCount() >= MIN_BUFFER_POSITIVES
    if (this.state == RecommendState.collecting) {
      if (this.sampleCount >= RECOMMEND_MIN_SAMPLES &&
        this.clickSampleCount >= RECOMMEND_MIN_CLICKS && condB) {
        this.state = RecommendState.active
        this.degradedStreak = 0
        this.schedulePersist(true)
      }
    } else if (this.state == RecommendState.active) {
      if (auc < AUC_DEGRADED) {
        this.degradedStreak++
        if (this.degradedStreak >= DEGRADED_STREAK_LIMIT) {
          this.state = RecommendState.degraded
          this.schedulePersist(true)
        }
      } else {
        this.degradedStreak = 0
      }
    } else {
      if (condB) {
        this.state = RecommendState.active
        this.degradedStreak = 0
        this.schedulePersist(true)
      }
    }
  }

  private evaluate(): void {
    const auc = computeAUC(this.evalBuffer)
    if (auc < 0) {
      return
    }
    this.aucHistory.push(auc)
    if (this.aucHistory.length > AUC_HISTORY_MAX) {
      this.aucHistory.shift()
    }
    this.updateState(auc)
  }

  private trimCounters(): void {
    while (this.expoCounts.size > COUNTER_MAX) {
      const oldest = Array.from(this.expoCounts.keys())[0]
      if (oldest === undefined) {
        break
      }
      this.expoCounts.delete(oldest)
    }
    while (this.clickCounts.size > COUNTER_MAX) {
      const oldest = Array.from(this.clickCounts.keys())[0]
      if (oldest === undefined) {
        break
      }
      this.clickCounts.delete(oldest)
    }
  }

  private closeBatchInternal(): void {
    const batch = this.batch
    if (!batch) {
      return
    }
    this.batch = undefined
    batch.entries.forEach(entry => {
      if (entry.resolved || this.pendingClicks.has(entry.tid)) {
        return
      }
      const expo = this.expoCounts.get(entry.tid) || 1
      this.model.update(entry.features, 0, 1 / Math.sqrt(expo))
      this.sampleCount++
      this.pushEval({ p: entry.score, y: 0 })
    })
    this.evaluate()
    this.trimCounters()
    this.schedulePersist()
  }

  /** 列表页销毁 / 版面退出等场景下关闭当前批次 */
  closeBatch(): void {
    if (!this.loaded || !this.enabled) {
      this.batch = undefined
      return
    }
    this.closeBatchInternal()
  }

  /**
   * 列表曝光（初次进入、翻页、刷新、缓存命中）。返回 Top K 高亮 tid 集合。
   * 同 key 数据重复到达时只重新打分，不重复建批
   */
  async onThreadListExposure(pageKey: string, fid: string,
    items: RecommendExposureItem[]): Promise<Set<string>> {
    await this.ensureLoaded()
    if (!this.enabled) {
      this.batch = undefined
      return new Set<string>()
    }
    const now = Date.now()
    if (this.batch && (pageKey !== this.batch.key || now - this.batch.createdAt > BATCH_TIMEOUT_MS)) {
      this.closeBatchInternal()
    }
    if (!this.batch) {
      this.createBatch(pageKey, fid, items)
    }
    return this.scoreBatch(this.batch!)
  }

  /** 帖子点击（列表 onClick / 长按） */
  onThreadClick(tid: string): void {
    if (!this.loaded || !this.enabled) {
      return
    }
    this.clickCounts.set(tid, (this.clickCounts.get(tid) || 0) + 1)
    const entry = this.batch?.entries.get(tid)
    const features = entry ? entry.features : this.featureSnapshots.get(tid)
    this.pendingClicks.set(tid, {
      tid: tid,
      ts: Date.now(),
      features: features || []
    })
    this.schedulePersist(true)
  }

  /** 进入帖子详情页（onReady / onShown 时调用；仅对有 pending 点击的 tid 生效） */
  onThreadPostShown(tid: string): void {
    if (!this.pendingClicks.has(tid)) {
      return
    }
    if (!this.enterTs.has(tid)) {
      this.enterTs.set(tid, Date.now())
    }
  }

  private positiveWeight(dwellSec: number, clicks: number): number {
    if (dwellSec < 5) {
      return 0.5
    }
    let w = 1
    if (dwellSec >= 30) {
      w += 0.5
    }
    if (dwellSec >= 120) {
      w += 0.5
    }
    if (clicks >= 2) {
      w += 0.5
    }
    return Math.min(w, 2)
  }

  /** 离开帖子详情页时生成正样本并立即更新模型 */
  onThreadPostHidden(tid: string): void {
    const enter = this.enterTs.get(tid)
    if (enter === undefined) {
      return
    }
    this.enterTs.delete(tid)
    const pending = this.pendingClicks.get(tid)
    this.pendingClicks.delete(tid)
    if (!pending || pending.features.length == 0) {
      return
    }
    const entry = this.batch?.entries.get(tid)
    const p = entry ? entry.score : this.model.predict(pending.features)
    if (entry) {
      entry.resolved = true
    }
    const dwellSec = (Date.now() - enter) / 1000
    const clicks = this.clickCounts.get(tid) || 1
    this.model.update(pending.features, 1, this.positiveWeight(dwellSec, clicks))
    this.sampleCount++
    this.clickSampleCount++
    this.pushEval({ p: p, y: 1 })
    this.schedulePersist()
  }

  private schedulePersist(force: boolean = false): void {
    const now = Date.now()
    if (!force && now - this.lastPersist < PERSIST_INTERVAL_MS) {
      return
    }
    this.lastPersist = now
    this.persistNow()
  }

  private async persistNow(): Promise<void> {
    if (!this.loaded || this.persisting) {
      return
    }
    this.persisting = true
    try {
      await writeJson('recommend', this.uid, this.toPersistData())
    } catch (e) {
      console.error('recommend model persist failed')
    } finally {
      this.persisting = false
    }
  }

  private toPersistData(): RecommendModelData {
    const z: Record<string, number> = {}
    const n: Record<string, number> = {}
    this.model.z.forEach((v: number, k: number) => {
      // 体积控制：清理 |w| < 1e-4 的坐标
      if (Math.abs(this.model.weight(k)) < PERSIST_WEIGHT_EPS) {
        return
      }
      z[`${k}`] = v
      n[`${k}`] = this.model.n.get(k) || 0
    })
    const expoCounts: Record<string, number> = {}
    this.expoCounts.forEach((v: number, k: string) => {
      expoCounts[k] = v
    })
    const clickCounts: Record<string, number> = {}
    this.clickCounts.forEach((v: number, k: string) => {
      clickCounts[k] = v
    })
    const pendingClicks: Record<string, PersistClick> = {}
    this.pendingClicks.forEach((v: PendingClick, k: string) => {
      pendingClicks[k] = { ts: v.ts, features: v.features }
    })
    return {
      version: MODEL_VERSION,
      alpha: this.model.alpha,
      beta: this.model.beta,
      l1: this.model.l1,
      l2: this.model.l2,
      z: z,
      n: n,
      expoCounts: expoCounts,
      clickCounts: clickCounts,
      sampleCount: this.sampleCount,
      clickSampleCount: this.clickSampleCount,
      state: this.state,
      degradedStreak: this.degradedStreak,
      aucHistory: this.aucHistory,
      evalBuffer: this.evalBuffer,
      pendingClicks: pendingClicks
    }
  }

  async getStatus(): Promise<RecommendStatus> {
    await this.ensureLoaded()
    return {
      state: this.state,
      sampleCount: this.sampleCount,
      clickSampleCount: this.clickSampleCount,
      aucHistory: this.aucHistory.slice(),
      lastAuc: this.aucHistory.length > 0 ? this.aucHistory[this.aucHistory.length - 1] : -1,
      bufferPositives: this.bufferPositiveCount()
    }
  }

  /** 清空模型与历史，状态回 COLLECTING；保留功能开关等配置 */
  async reset(): Promise<void> {
    await this.ensureLoaded()
    await removeJson('recommend', this.uid)
    this.resetMemory()
    this.lastPersist = 0
  }
}

export const Recommend = new RecommendManager()
