const inFlight: Map<string, Promise<object>> = new Map()

/**
 * 请求前置去重：key 相同且仍有未完成的请求时，直接复用该 Promise，不再发起新请求。
 * settle（无论成功失败）后从表中移除，失败后的下次触发可重新发起。
 */
export function joinInFlight<T>(key: string, issue: () => Promise<T>): Promise<T> {
  const existing = inFlight.get(key)
  if (existing !== undefined) {
    return existing as Promise<T>
  }
  const request = issue()
  const stored = request as Promise<object>
  inFlight.set(key, stored)
  const cleanup = (): void => {
    if (inFlight.get(key) === stored) {
      inFlight.delete(key)
    }
  }
  request.then(cleanup, cleanup)
  return request
}

/**
 * 页面级加载状态守卫，避免重复加载同一 key。
 */
export class PageLoadGuard {
  private loadedKey: string = ''

  shouldLoad(key: string): boolean {
    return key != this.loadedKey
  }

  /**
   * 领取一次加载会话。key 已加载（或正在加载）时返回 undefined，调用方应直接放弃本次加载。
   * 成功领取后 key 立即被占位，防止并发重入。
   */
  begin(key: string): LoadSession | undefined {
    if (!this.shouldLoad(key)) {
      return undefined
    }
    this.loadedKey = key
    return new LoadSession(this, key)
  }

  /** 确认 key 已加载完成（幂等）。仅供 LoadSession 调用。 */
  confirm(key: string): void {
    this.loadedKey = key
  }

  /** 回滚占位，允许该 key 重试；若占位已被更新的会话顶替则不动。仅供 LoadSession 调用。 */
  reset(key: string): void {
    if (this.loadedKey == key) {
      this.loadedKey = ''
    }
  }
}

/**
 * 一次加载会话：持有发起时捕获的 key，会话内可并发 join 多个请求
 */
class LoadSession {
  private guard: PageLoadGuard
  private key: string

  constructor(guard: PageLoadGuard, key: string) {
    this.guard = guard
    this.key = key
  }

  join<T>(flightKey: string, issue: () => Promise<T>): Promise<T> {
    return joinInFlight(flightKey, issue)
      .then((v): T => {
        this.guard.confirm(this.key)
        return v
      })
      .catch((e: Error): Promise<T> => {
        this.guard.reset(this.key)
        throw e
      })
  }
}

/**
 * 延迟等待提示：begin() 后 800ms 内未被 end() 时回调 true
 */
export class CacheWaitHint {
  private onWaitChange: (waiting: boolean) => void
  private timer?: number

  constructor(onWaitChange: (waiting: boolean) => void) {
    this.onWaitChange = onWaitChange
  }

  begin(): void {
    this.clearTimer()
    this.onWaitChange(false)
    this.timer = setTimeout((): void => {
      this.timer = undefined
      this.onWaitChange(true)
    }, 800)
  }

  end(): void {
    this.clearTimer()
    this.onWaitChange(false)
  }

  private clearTimer(): void {
    if (this.timer !== undefined) {
      clearTimeout(this.timer)
      this.timer = undefined
    }
  }
}
