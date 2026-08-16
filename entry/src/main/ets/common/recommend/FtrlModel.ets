/**
 * FTRL-Proximal 在线逻辑回归（McMahan et al., KDD 2013）与滚动 AUC 评估
 */
import { ADJUSTABLE_GROUP_COUNT, SparseFeature } from './FeatureExtractor'

export interface EvalEntry {
  p: number // 曝光时刻的预测分数
  y: number // 后续标签 0/1
}

export class FtrlModel {
  alpha: number = 0.15
  beta: number = 1.0
  l1: number = 1e-5
  l2: number = 1.0
  z: Map<number, number> = new Map()
  n: Map<number, number> = new Map()

  /** 由 z, n 重导权重（w 不持久化） */
  weight(i: number): number {
    const zi = this.z.get(i) || 0
    if (Math.abs(zi) <= this.l1) {
      return 0
    }
    const ni = this.n.get(i) || 0
    const sign = zi > 0 ? 1 : -1
    return -(zi - sign * this.l1) / (this.l2 + (this.beta + Math.sqrt(ni)) / this.alpha)
  }

  /**
   * sigmoid 打分。groupWeights 为推理期各组乘数（训练时不应传入）
   */
  predict(features: SparseFeature[], groupWeights?: number[]): number {
    let sum = 0
    for (const f of features) {
      const w = this.weight(f.i)
      if (w === 0) {
        continue
      }
      let mult = 1
      if (groupWeights && f.g < ADJUSTABLE_GROUP_COUNT) {
        mult = groupWeights[f.g]
      }
      sum += w * f.v * mult
    }
    return 1 / (1 + Math.exp(-sum))
  }

  /**
   * 单样本 FTRL-Proximal 更新。sampleWeight 并入梯度
   */
  update(features: SparseFeature[], y: number, sampleWeight: number): void {
    const p = this.predict(features)
    for (const f of features) {
      const g = (p - y) * f.v * sampleWeight
      const ni = this.n.get(f.i) || 0
      const w = this.weight(f.i)
      const sigma = (Math.sqrt(ni + g * g) - Math.sqrt(ni)) / this.alpha
      this.z.set(f.i, (this.z.get(f.i) || 0) + g - sigma * w)
      this.n.set(f.i, ni + g * g)
    }
  }
}

/**
 * 无权 AUC（Mann-Whitney U 秩统计，并列取平均秩）。
 * 任一类为空时返回 -1 表示无法评估
 */
export function computeAUC(entries: EvalEntry[]): number {
  const sorted = entries.slice().sort((a: EvalEntry, b: EvalEntry): number => a.p - b.p)
  let posRankSum = 0
  let pos = 0
  let neg = 0
  let i = 0
  while (i < sorted.length) {
    let j = i
    while (j + 1 < sorted.length && sorted[j + 1].p === sorted[i].p) {
      j++
    }
    const avgRank = (i + j + 2) / 2 // 1-based 平均秩
    for (let k = i; k <= j; k++) {
      if (sorted[k].y > 0) {
        posRankSum += avgRank
        pos++
      } else {
        neg++
      }
    }
    i = j + 1
  }
  if (pos == 0 || neg == 0) {
    return -1
  }
  return (posRankSum - pos * (pos + 1) / 2) / (pos * neg)
}
