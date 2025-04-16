import { preferences } from '@kit.ArkData';
import { clearApiCache } from '../common/dataStore/ApiCacheData';
import { ApplicationConfig } from './v1/default';

/**
 * Proxy包装@kit.ArkData.preferences来简化使用
 */
export class PreferencesWrapper implements ProxyHandler<ApplicationConfig> {
  private preferences?: preferences.Preferences
  private config: ApplicationConfig = new ApplicationConfig()
  private proxy?: ApplicationConfig
  private dirty: Set<string> = new Set()
  private initPromise?: Promise<void>
  private resolveInit?: () => void
  private initialized: boolean = false

  constructor() {
    this.initPromise = new Promise((resolve, reject) => {
      this.resolveInit = resolve
    })
  }

  async init(context: Context) {
    const pref = await preferences.getPreferences(context, { name: 'UserPreference' })
    this.preferences = pref
    const currentVersion = await this.preferences.get('version', '')
    const targetVersion = '2'
    if (currentVersion === '') {
      await this.preferences.put('version', targetVersion)
      await this.preferences.flush()
    } else {
      if (currentVersion === '1' && targetVersion === '2') {
        // 2025/4/16 版本1.3.0：论坛域名更换，需要将api缓存失效。
        clearApiCache()
        await this.preferences.put('version', targetVersion)
        await this.preferences.flush()
      }
      let storedConfig = await this.preferences.getAll() as ApplicationConfig
      Object.keys(storedConfig).forEach(k => Reflect.set(this.config, k, Reflect.get(storedConfig, k)))
    }

    this.proxy = new Proxy(this.config, this)
    this.initialized = true
    this.resolveInit?.()
    return this
  }

  get(target: ApplicationConfig, k: string): preferences.ValueType {
    const value = Reflect.get(this.config, k) as object
    if (value instanceof Object) {
      this.dirty.add(k)
    }
    return value
  }

  set(target: ApplicationConfig, k: string, newValue: preferences.ValueType): boolean {
    const result = Reflect.set(this.config, k, newValue)
    this.dirty.add(k)
    return result
  }

  /**
   * 修改配置项：在modifier回调中对于ApplicationConfig的修改将被flush
   *
   * 可被await来保证后续逻辑中对配置的修改已经生效
   */
  async modify(modifier: (conf: ApplicationConfig) => void) {
    if (!this.initialized) {
      await this.initPromise
    }
    modifier(this.proxy!)
    this.dirty.forEach(key => {
      this.preferences?.put(key, Reflect.get(this.config, key))
    })
    await this.preferences?.flush()
    this.dirty.clear()
  }

  /**
   * 只读访问配置项：不应在回调中修改ApplicationConfig，会导致配置项与存储的状态不同步
   */
  async readonly (reader: (conf: ApplicationConfig) => void) {
    if (!this.initialized) {
      await this.initPromise
    }
    reader(this.config)
  }
}

export const PreferenceManager = new PreferencesWrapper()