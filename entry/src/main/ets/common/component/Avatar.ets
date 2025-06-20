import { ImageKnife, ImageKnifeComponent } from '@ohos/imageknife'
import { URL } from '../../api/base'
import { taskpool } from '@kit.ArkTS'
import { AvatarTtlDay } from './preference/AvatarCachePref'
import { PreferenceManager } from '../../config/UserConfig'
import { readJson, writeJson } from '../dataStore/JsonPersist'
import { ReloadController } from '../BasicDataSource'
import { waitFor } from '../AwaitUtil'
import { AniSpeed } from '../Animation'

let cacheMap: Map<string, CacheInfo> = new Map()
const expiredUid: string[] = []

enum AvatarType {
  NO_AVATAR = '0',
  CACHED = '1'
}

interface CacheInfo {
  date: number,
  type: AvatarType
}

function putCacheInfo(uid: string, type: AvatarType) {
  if (!cacheMap.has(uid)) {
    cacheMap.set(uid, {
      date: Date.now(),
      type: type
    })
  }
}

export function avatarPath(uid: string): string {
  const uidStr = uid.padStart(9, '0');
  return `${URL.AVATAR_BASE}${uidStr.slice(0, 3)}/${uidStr.slice(3, 5)}/${uidStr.slice(5,
    7)}/${uidStr.slice(7)}_avatar_big.jpg`;
}


export async function saveAvatarCacheState() {
  const record: Record<string, CacheInfo> = {}
  cacheMap.forEach((v, k) => {
    record[k] = v
  })
  writeJson<Record<string, CacheInfo>>('avatar', 'avatarCache', record)
}

export function initAvatarCacheState() {
  readJson<Record<string, CacheInfo>>('avatar', 'avatarCache').then(file => {
    try {
      if (file == null) {
        return
      }
      const data = Object.entries<CacheInfo>(file)
      PreferenceManager.readonly(conf => {
        const cacheTTL = AvatarTtlDay[conf.avatar_cache_ttl]
        const expireDate = Date.now() - cacheTTL * 24 * 60 * 60 * 1000
        const map = new Map<string, CacheInfo>(
          data
            .filter(v => {
              const alive = v[1].date > expireDate
              if (!alive) {
                expiredUid.push(v[0])
              }
              return alive
            })
        )
        cacheMap = map
      })
    } catch (e) {
    }
  })
}

@Component
export struct Avatar {
  @State imageSrc: string = ''
  avatarUrl: string = ''
  @State hideDefaultAvatar: boolean = false
  @Prop @Watch('uidChanged') uid: string = ''
  avatarSize: number = 40
  transitionIndex: string = ''
  reloadCtrl: ReloadController = new ReloadController()
  cacheInfo?: CacheInfo
  avatarLoaded: (url: string) => void = () => {
  }

  aboutToAppear(): void {
    this.reloadCtrl.reload = (): void => { this.load(true) }
    this.load()
  }

  uidChanged() {
    this.load()
    this.imageSrc = this.avatarUrl
  }

  async load(removeCache: boolean = false) {
    this.cacheInfo = cacheMap.get(this.uid)
    if (removeCache && this.cacheInfo != undefined) {
      if (this.cacheInfo.type = AvatarType.CACHED) {
        const knife: ImageKnife = ImageKnife.getInstance()
        const avatarUrl = avatarPath(this.uid)
        knife.removeMemoryCache(avatarUrl)
        knife.removeFileCache(avatarUrl)
        cacheMap.delete(avatarUrl)
      }
      this.cacheInfo = undefined
      this.imageSrc = ''
      this.hideDefaultAvatar = false
      await waitFor(50)
    }
    if (this.uid.length > 0) {
      if (this.cacheInfo == undefined) {
        this.avatarUrl = avatarPath(this.uid)
        this.hideDefaultAvatar = false
      } else {
        if (this.cacheInfo.type == AvatarType.NO_AVATAR) {
          this.avatarUrl = ''
          this.hideDefaultAvatar = false
        } else if (this.cacheInfo.type = AvatarType.CACHED) {
          this.avatarUrl = avatarPath(this.uid)
          this.hideDefaultAvatar = true
        }
      }
    }
  }

  build() {
    Stack() {
      ImageKnifeComponent({
        imageKnifeOption: {
          loadSrc: this.imageSrc,
          objectFit: ImageFit.Cover,
          priority: taskpool.Priority.LOW,
          border: {
            radius: this.avatarSize / 2
          },
          onLoadListener: {
            onLoadSuccess: () => {
              this.hideDefaultAvatar = true
              this.avatarLoaded(this.imageSrc)
              putCacheInfo(this.uid, AvatarType.CACHED)
            },
            onLoadFailed: (err) => {
              if (err.includes('404')) { // 未命中缓存也会触发load failed，但是只有http 404 message才说明用户用的默认头像
                putCacheInfo(this.uid, AvatarType.NO_AVATAR)
              }
            }
          }
        }
      })
        .height(this.avatarSize)
        .width(this.avatarSize)
        .opacity(this.hideDefaultAvatar ? 1 : 0)
        .animation({ duration: AniSpeed.ms120 })
        .draggable(false)
      if (!this.hideDefaultAvatar) {
        Image($r("app.media.avatar_base"))
          .height(this.avatarSize)
          .width(this.avatarSize)
          .borderRadius(this.avatarSize / 2)
          .transition(TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms120 }))
          .draggable(false)
      }
    }.onVisibleAreaChange([0.02, 1], () => {
      if (this.imageSrc.length == 0) {
        this.imageSrc = this.avatarUrl
      }
    })
    .geometryTransition(this.transitionIndex ? 'avatar_component' + this.uid + this.transitionIndex : undefined,
      { follow: true })
  }
}

export function removeExpiredAvatar() {
  const knife: ImageKnife = ImageKnife.getInstance()
  expiredUid.forEach((uid): void => knife.removeFileCache(avatarPath(uid)))
  expiredUid.splice(0, expiredUid.length)
}

export function clearAvatarCache() {
  for (let k of cacheMap.keys()) {
    if (cacheMap.get(k)?.type == AvatarType.CACHED) {
      cacheMap.delete(k)
    }
  }
}