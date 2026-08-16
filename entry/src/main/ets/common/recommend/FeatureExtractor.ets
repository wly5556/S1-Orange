/**
 * 帖子推荐系统的特征提取：
 * 文本归一化、字符 1+2-gram、FNV-1a 特征哈希、数值分桶、特征组标记、tid 级文本特征 LRU 缓存
 */

export enum FeatureGroup {
  board = 0,
  type,
  titleText,
  contentText,
  hot,
  fresh,
  history,
  bias
}

/** 用户可调乘数的特征组数量（不含 bias） */
export const ADJUSTABLE_GROUP_COUNT = 7

export interface SparseFeature {
  i: number // 哈希桶坐标
  v: number // 特征值
  g: number // FeatureGroup
}

export interface ThreadTextFeature {
  title: SparseFeature[]
  content: SparseFeature[]
}

export interface ThreadFeatureInput {
  tid: string
  fid: string
  typeid: string
  subject: string
  message: string
  replyMessages: string[]
  replies: number
  newReplies: number // 自上次查看以来新增的回帖数；从未看过的帖子应传入全部回帖数
  viewed: boolean
}

const DIM = 262144 // 2^18
const SUBJECT_MAX_LEN = 80
const MESSAGE_MAX_LEN = 160
const REPLIES_TEXT_MAX_LEN = 120
const TEXT_CACHE_LIMIT = 500

export function fnv1a(str: string): number {
  let h = 0x811c9dc5
  for (let idx = 0; idx < str.length; idx++) {
    h = (h ^ str.charCodeAt(idx)) >>> 0
    h = Math.imul(h, 16777619) >>> 0
  }
  return h >>> 0
}

function featureIndex(key: string): number {
  return fnv1a(key) % DIM
}

/** 去除 BBCode 标签、URL、HTML 实体，合并连续空白 */
export function normalizeText(raw: string): string {
  return raw
    .replace(/https?:\/\/\S+/gi, ' ')
    .replace(/\[[^\]]*\]/g, ' ')
    .replace(/&[a-z#0-9]+;/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

/** 字符 1+2-gram，子线性 TF：1 + ln(tf) */
function ngramFeatures(prefix: string, text: string, group: FeatureGroup): SparseFeature[] {
  const counts = new Map<string, number>()
  for (let i = 0; i < text.length; i++) {
    counts.set(text.charAt(i), (counts.get(text.charAt(i)) || 0) + 1)
    if (i + 1 < text.length) {
      const bigram = text.substring(i, i + 2)
      counts.set(bigram, (counts.get(bigram) || 0) + 1)
    }
  }
  const feats: SparseFeature[] = []
  counts.forEach((tf: number, gram: string) => {
    feats.push({
      i: featureIndex(prefix + gram),
      v: 1 + Math.log(tf),
      g: group
    })
  })
  return feats
}

function expoBucket(count: number): number {
  if (count <= 1) {
    return 0
  }
  return count <= 4 ? 1 : 2
}

function freshBucket(count: number): number {
  if (count <= 5) {
    return 0
  }
  if (count <= 20) {
    return 1
  }
  return count <= 50 ? 2 : 3
}

export class FeatureExtractor {
  private textCache: Map<string, ThreadTextFeature> = new Map()

  /**
   * 取 tid 的文本特征（标题/正文两组）。标题与已发表楼层内容不可变，命中缓存即终身复用
   */
  getTextFeatures(input: ThreadFeatureInput): ThreadTextFeature {
    const cached = this.textCache.get(input.tid)
    if (cached) {
      this.textCache.delete(input.tid)
      this.textCache.set(input.tid, cached)
      return cached
    }
    const subject = normalizeText(input.subject).substring(0, SUBJECT_MAX_LEN)
    const message = normalizeText(input.message).substring(0, MESSAGE_MAX_LEN)
    let replyText = ''
    input.replyMessages.forEach(m => {
      if (m.length > 0) {
        replyText += ' ' + m
      }
    })
    replyText = normalizeText(replyText).substring(0, REPLIES_TEXT_MAX_LEN)
    // 不同板块内容风格差异大，文本特征按 fid 隔离命名空间，各自独立学习权重
    const entry: ThreadTextFeature = {
      title: ngramFeatures(`t${input.fid}:`, subject, FeatureGroup.titleText),
      content: ngramFeatures(`m${input.fid}:`, message, FeatureGroup.contentText)
        .concat(ngramFeatures(`r${input.fid}:`, replyText, FeatureGroup.contentText))
    }
    this.textCache.set(input.tid, entry)
    if (this.textCache.size > TEXT_CACHE_LIMIT) {
      const oldest = Array.from(this.textCache.keys())[0]
      if (oldest !== undefined) {
        this.textCache.delete(oldest)
      }
    }
    return entry
  }

  /**
   * 构造完整特征向量。文本特征来自缓存，其余特征（随回帖数/曝光/点击变化）每次现算
   */
  buildFeatures(input: ThreadFeatureInput, text: ThreadTextFeature, expoCount: number,
    clickCount: number): SparseFeature[] {
    const feats: SparseFeature[] = []
    feats.push({ i: featureIndex('bias'), v: 1, g: FeatureGroup.bias })
    feats.push({ i: featureIndex(`fid=${input.fid}`), v: 1, g: FeatureGroup.board })
    if (input.typeid.length > 0) {
      feats.push({ i: featureIndex(`type=${input.typeid}`), v: 1, g: FeatureGroup.type })
      feats.push({ i: featureIndex(`fidtype=${input.fid}|${input.typeid}`), v: 1, g: FeatureGroup.type })
    }
    feats.push(...text.title)
    feats.push(...text.content)
    const repliesBucket = Math.floor(Math.log10(Math.max(input.replies, 1)))
    feats.push({ i: featureIndex(`replies=b${repliesBucket}`), v: 1, g: FeatureGroup.hot })
    feats.push({ i: featureIndex(`expo=b${expoBucket(expoCount)}`), v: 1, g: FeatureGroup.hot })
    const freshCount = input.viewed ? input.newReplies : input.replies
    feats.push({ i: featureIndex(`new=b${freshBucket(freshCount)}`), v: 1, g: FeatureGroup.fresh })
    if (clickCount >= 1) {
      feats.push({ i: featureIndex(`clk=b${clickCount >= 2 ? 1 : 0}`), v: 1, g: FeatureGroup.history })
    }
    return feats
  }
}
