import { CacheStrategy, ImageKnife } from '@ohos/imageknife'
import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { getSmilyImageCache, putSmilyImageCache, SmilyImageCacheRow, SmilyImageType } from '../dataStore/SmilyCache'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { arrayToString, stringToArray } from '../TextUtil'
import { image } from '@kit.ImageKit'

const localSmilyCache: Map<string, PixelMap | string> = new Map()

@Component
export struct ImageSmily {
  src: string = ''
  @State imageData: PixelMap | ResourceStr | undefined = undefined
  @Consume appState: PreferenceState

  aboutToAppear(): void {
    this.loadImage()
  }

  async loadImage() {
    if (this.src == '') {
      return
    }
    const imageKnife = ImageKnife.getInstance()
    const memoryCache = localSmilyCache.get(this.src)
    let dbCache: SmilyImageCacheRow | undefined
    if (memoryCache != undefined) {
      let source = memoryCache
      setTimeout(() => this.imageData = source) // 如果不延迟设置imageData，会导致布局错误、显示不全
    } else if ((dbCache = await getSmilyImageCache(this.src)) != undefined) {
      if (dbCache.type == SmilyImageType.PNG) {
        const imageSource = image.createImageSource(dbCache.data.buffer) // 传入data(Uint8Array)会创建失败返回undefined;需要传入data.buffer(ArrayBuffer)
        this.imageData = await imageSource.createPixelMap()
      } else if (dbCache.type == SmilyImageType.GIF) {
        this.imageData = arrayToString(dbCache.data)
      }
      localSmilyCache.set(this.src, this.imageData as (PixelMap | string))
    } else {
      await imageKnife.preLoadCache(this.src)
      const fileCache = await imageKnife.getCacheImage(this.src, CacheStrategy.File)
      if (fileCache != undefined) {
        if (typeof fileCache.source == 'object') {
          this.imageData = fileCache.source
          const imagePackerApi: image.ImagePacker = image.createImagePacker()
          imagePackerApi.packing(fileCache.source, { format: 'image/png', quality: 100 })
            .then(buf => {
              putSmilyImageCache({
                key: this.src,
                data: new Uint8Array(buf),
                type: SmilyImageType.PNG
              })
            })
        } else {
          this.imageData = fileCache.source
          putSmilyImageCache({
            key: this.src,
            data: stringToArray(fileCache.source),
            type: SmilyImageType.GIF
          })
        }
        localSmilyCache.set(this.src, fileCache.source)
        // imageKnife.putCacheImage(this.src, fileCache.source as PixelMap, CacheStrategy.Memory) 用imageKnife管理内存缓存会使得载入时要和其它帖子图片、头像的加载队列竞争
      } else {
        // cache由于存储空间限制被删除
      }
    }
  }

  build() {
    ImageSpan(this.imageData)
      .objectFit(ImageFit.Contain)
      .constraintSize({
        minWidth: FontSizeEnum[this.appState.fontSize].vp36
      })
      .height(FontSizeEnum[this.appState.fontSize].vp36)
  }
}