/**
 * 页面级加载状态守卫：同一个页面状态 key 只加载一次。
 * 网络请求在途去重由请求层负责（request.cache()），本模块与其无关。
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
 * 一次加载会话：持有发起时捕获的 key，负责在加载成功/失败后更新 guard 占位。
 */
class LoadSession {
  private guard: PageLoadGuard
  private key: string

  constructor(guard: PageLoadGuard, key: string) {
    this.guard = guard
    this.key = key
  }

  join<T>(issue: () => Promise<T>): Promise<T> {
    return issue()
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
