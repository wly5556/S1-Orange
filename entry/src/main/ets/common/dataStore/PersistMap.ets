import { readJson, writeJson } from './JsonPersist'

export const DEFAULT_MAX_ENTRIES = 30000

const flushTasks: Array<() => void> = []

export function flushAllPersistMaps(): void {
  flushTasks.forEach(task => task())
}

/**
 * 内存 Map<key, value> 的 JSON 文件持久化：读一次性载入，写只在内存标记 dirty，进入后台时统一 flush。
 * 超过条目上限时按插入先后淘汰最早的条目。
 */
export class PersistMap<V> {
  private readonly bucket: string
  private readonly persistKey: string
  private readonly maxEntries: number
  private data: Map<string, V> = new Map<string, V>()
  private dirty: boolean = false

  constructor(bucket: string, persistKey: string, maxEntries: number = DEFAULT_MAX_ENTRIES) {
    this.bucket = bucket
    this.persistKey = persistKey
    this.maxEntries = maxEntries
    flushTasks.push(() => this.flush())
  }

  async load(): Promise<void> {
    const record = await readJson<Record<string, V>>(this.bucket, this.persistKey)
    if (record) {
      const map: Map<string, V> = new Map<string, V>()
      Object.keys(record).forEach(key => map.set(key, record[key]))
      this.data = map
    }
  }

  get(key: string): V | undefined {
    return this.data.get(key)
  }

  has(key: string): boolean {
    return this.data.has(key)
  }

  size(): number {
    return this.data.size
  }

  set(key: string, value: V): void {
    if (this.data.has(key)) {
      this.data.delete(key)
    }
    this.data.set(key, value)
    this.evictOverflow()
    this.dirty = true
  }

  delete(key: string): void {
    if (this.data.delete(key)) {
      this.dirty = true
    }
  }

  clear(): void {
    this.data.clear()
    this.dirty = true
  }

  private evictOverflow(): void {
    if (this.data.size <= this.maxEntries) {
      return
    }
    const overflow = this.data.size - this.maxEntries
    Array.from(this.data.keys()).slice(0, overflow).forEach(key => this.data.delete(key))
  }

  flush(): void {
    if (!this.dirty) {
      return
    }
    this.dirty = false
    const record: Record<string, V> = {}
    this.data.forEach((value, key) => {
      record[key] = value
    })
    writeJson<Record<string, V>>(this.bucket, this.persistKey, record)
  }
}
