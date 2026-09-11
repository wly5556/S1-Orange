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

export class PageLoadGuard {
  private loadedKey: string = ''

  shouldLoad(key: string): boolean {
    return key != this.loadedKey
  }

  markLoading(key: string): void {
    this.loadedKey = key
  }

  markFailed(): void {
    this.loadedKey = ''
  }
}

/**
 * 延迟等待提示：begin() 后 800ms 内未被 end() 时回调 true。
 * begin() / end() / destroy() 都会把等待态回落为 false（幂等），因此提示不会残留。
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

  destroy(): void {
    this.end()
  }

  private clearTimer(): void {
    if (this.timer !== undefined) {
      clearTimeout(this.timer)
      this.timer = undefined
    }
  }
}
