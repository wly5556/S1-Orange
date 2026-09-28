export class PageLoadGuard {
  private loadedKey: string = ''

  shouldLoad(key: string): boolean {
    return key != this.loadedKey
  }

  /**
   * 申请一次 Load。key 已被申请时返回 undefined，调用方应直接放弃本次加载
   * 成功申请后 key 立即被占位，防止并发
   */
  begin(key: string): LoadSession | undefined {
    if (!this.shouldLoad(key)) {
      return undefined
    }
    this.loadedKey = key
    return new LoadSession(this, key)
  }

  confirm(key: string): void {
    this.loadedKey = key
  }

  reset(key: string): void {
    if (this.loadedKey == key) {
      this.loadedKey = ''
    }
  }
}

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
