import { DownsampleStrategy, ImageKnife, ImageKnifeComponent, ImageKnifeRequest } from '@ohos/imageknife'
import { DomainRegex } from '../../api/base'
import { userCookieString } from '../../api/request'
import { openInBrowser } from '../WantUitl'
import { common } from '@kit.AbilityKit'
import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { markImageViewerTransitionFromClick } from './ImageViewer'
import { rcp } from '@kit.RemoteCommunicationKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { queryImageHash, queryImageSize, reportImageHash, reportImageSize } from '../dataStore/ImageSizeData'
import { encodeThumbHashFromFile, getPlaceholderPixelMap } from '../ThumbHash'
import { encodeThumbHashTask } from '../ThumbHashTask'
import { taskpool } from '@kit.ArkTS'
import { image } from '@kit.ImageKit'

export interface RectSize {
  w: number,
  h: number
}

const MAX_RETRY = 2
const NO_PROXY_FROM_RETRY = 2

/**
 * 切后台时组件的可见比例会归零，若照此释放图片组件，回前台需要重建才能恢复，
 * 而窗口尚不可见时重建的组件，其加载完成回调并不可靠（偶发残留占位图）
 * 故切后台时先记录活跃的图片，由于后台事件早于可见区域归零事件，
 * 可以使其紧接着的那次可见比例归零不生效，避免图片被意外释放
 */
class ImageBackgroundGuard {
  // id 到「该容器是否处于图片已加载/加载中激活态」的查询
  private activeChecks: Map<number, () => boolean> = new Map()
  private heldIds: Set<number> = new Set()
  private nextId: number = 1

  register(isActive: () => boolean): number {
    const id = this.nextId
    this.nextId += 1
    this.activeChecks.set(id, isActive)
    return id
  }

  unregister(id: number): void {
    this.activeChecks.delete(id)
    this.heldIds.delete(id)
  }

  isHeld(id: number): boolean {
    return this.heldIds.has(id)
  }

  release(id: number): void {
    this.heldIds.delete(id)
  }

  onAppBackground(): void {
    this.heldIds.clear()
    this.activeChecks.forEach((isActive: () => boolean, id: number) => {
      if (isActive()) {
        this.heldIds.add(id)
      }
    })
  }
}

export const imageBackgroundGuard = new ImageBackgroundGuard()

@Component
export struct ImageContainer {
  @Consume appState: PreferenceState
  @State imageUrl: string = ''
  @State loadComplete: boolean = false
  @State loadingProgress: number = 0
  @State loadFailed: boolean = false
  @State retryHint: string = ''
  @State placeholderPixelMap: image.PixelMap | undefined = undefined
  guardId: number = -1
  hashRequested: boolean = false
  imgSize?: RectSize
  @Prop @Watch('resize') constrainSize: RectSize | undefined = undefined
  @Prop @Watch('resize') fitWidth: number | undefined = undefined
  lastConstrainSizeWidth: number | undefined = undefined
  src: string = ''
  retry: number = 0
  usedByImageViewer: boolean = false
  // 仅查看器：入场转场动画结束后才按原图（不降采样）解码，动画期间与普通预览一样按显示区域尺寸降采样
  @Prop fullResolution: boolean = false
  @Prop imgHeight: number | string = 100 * FontSizeEnum[this.appState.fontSize].ratio
  @Prop imgWidth: number | string = '100%'
  lazyLoad: boolean = true
  // 由父级限定宽度并按列宽铺满（瀑布流单元），此时显示尺寸随列宽变化，不能套用缓存的显示尺寸
  fitCellWidth: boolean = false
  lastAreaWidth: number = -1
  afterResize: (imgDisplaySize: RectSize) => void = () => {
  }
  onFailed: () => void = () => {
  }
  onImgClick?: () => void

  aboutToAppear(): void {
    if (!this.lazyLoad) {
      if (this.imageUrl != this.src) {
        this.imageUrl = this.src
      }
    }
    if (!this.usedByImageViewer) {
      const cached = queryImageSize(this.src)
      if (cached) {
        this.imgSize = { w: cached.w, h: cached.h }
      }
      if (cached?.hash !== undefined) {
        this.placeholderPixelMap = getPlaceholderPixelMap(this.src, cached.hash)
      }
    }
    // 瀑布流列宽已知时先按列宽定好尺寸，使首次请求即按真实比例降采样，同时避免按占位框比例解码过小
    if (this.imgSize !== undefined && this.fitWidth !== undefined && this.fitWidth > 0) {
      this.resize(vp2px(this.fitWidth))
    }
    this.guardId = imageBackgroundGuard.register((): boolean => this.imageUrl.length > 0)
  }

  aboutToDisappear(): void {
    imageBackgroundGuard.unregister(this.guardId)
  }

  // 非瀑布流/非查看器：首次测量到父级可用宽度时就按缓存尺寸定好占位大小，避免加载后宽高跳变
  resizeOnAreaChange(width: number): void {
    if (width <= 0 || this.usedByImageViewer || this.fitCellWidth || this.imgSize === undefined) {
      return
    }
    const pxWidth = vp2px(width)
    if (Math.abs(pxWidth - this.lastAreaWidth) < 1) {
      return
    }
    this.lastAreaWidth = pxWidth
    this.resize(pxWidth)
  }

  /**
   *
   * @param componentWidth 单位px
   */
  resize(componentWidth: number) {
    if (!this.imgSize) {
      return
    }
    let resizeTo: RectSize
    const limitWidth = this.fitWidth
    if (limitWidth !== undefined && limitWidth > 0) { // 限定宽度的情况下按宽度铺满，如瀑布流单元
      resizeTo = resizeImgFitWidth(this.imgSize, vp2px(limitWidth))
      this.afterResize(resizeTo)
    } else if (this.constrainSize) { // 限制高度的情况下contain fit
      if (this.lastConstrainSizeWidth == this.constrainSize.w) {
        return
      }
      this.lastConstrainSizeWidth = this.constrainSize.w
      const containerRatio = this.constrainSize.w / this.constrainSize.h
      const imageRatio = this.imgSize.w / this.imgSize.h
      if (imageRatio > containerRatio) {
        resizeTo = resizeImgFitWidth(this.imgSize, this.constrainSize.w)
      } else {
        resizeTo = resizeImgFitHeight(this.imgSize, this.constrainSize.h)
      }
      this.afterResize(resizeTo)
    } else { // 其他情况占满横边适应：只依赖图片比例，解码尺寸变化不会引起布局跳变
      resizeTo = resizeImgFitWidth(this.imgSize, componentWidth)
      this.afterResize(resizeTo)
    }
    this.imgHeight = px2vp(resizeTo.h)
    this.imgWidth = px2vp(resizeTo.w)
  }

  // 已知尺寸时占位灰块铺满按比例算出的尺寸，避免加载前后宽高跳变
  private fillByKnownSize(): boolean {
    return this.fitCellWidth || this.imgSize !== undefined
  }

  // 首次加载完成后用文件缓存里的原图算一次 ThumbHash 并持久化，供二次查看时的占位模糊图使用
  async computeThumbHash(w: number, h: number): Promise<void> {
    if (this.hashRequested || queryImageHash(this.src) !== undefined) {
      return
    }
    this.hashRequested = true
    try {
      const path = await ImageKnife.getInstance().preLoadCache(encodeURI(this.src))
      let hash = ''
      try {
        hash = (await taskpool.execute(encodeThumbHashTask, path)) as string
      } catch (e) {
        // TaskPool 不可用时退回宿主线程
        hash = await encodeThumbHashFromFile(path)
      }
      if (hash.length == 0) {
        return
      }
      reportImageHash(this.src, w, h, hash)
      const pixelMap = getPlaceholderPixelMap(this.src, hash)
      if (pixelMap !== undefined) {
        this.placeholderPixelMap = pixelMap
      }
    } catch (e) {
      // 算不出来不影响图片展示
    }
  }

  build() {
    Column() {
      if ((!this.loadComplete && !this.usedByImageViewer) || this.loadFailed) {
        Stack() {
          if (this.placeholderPixelMap !== undefined && !this.loadFailed) {
            Image(this.placeholderPixelMap)
              .objectFit(ImageFit.Cover)
              .width('100%')
              .height('100%')
              .borderRadius(5)
          }
          Column({ space: 4 }) {
            if (this.loadFailed) {
              Text('图片加载失败').opacity(.6).fontSize(FontSizeEnum[this.appState.fontSize].vp12)
              Image($r('app.media.face_253_akarin'))
                .width(FontSizeEnum[this.appState.fontSize].vp40)
                .height(FontSizeEnum[this.appState.fontSize].vp40)
            } else if (this.retryHint) {
              Text(this.retryHint)
                .opacity(.4)
                .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
                .textAlign(TextAlign.Center)
            }
          }
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height('100%')
        }
        .onClick(e => {
          openInBrowser(getContext(this) as common.UIAbilityContext, this.imageUrl)
        })
        .width(this.fillByKnownSize() ? '100%' : 100 * FontSizeEnum[this.appState.fontSize].ratio)
        .height(this.fillByKnownSize() ? '100%' : 90 * FontSizeEnum[this.appState.fontSize].ratio)
        .margin({
          top: this.fillByKnownSize() ? 0 : 5,
          bottom: this.fillByKnownSize() ? 0 : 5
        })
        .backgroundColor(this.loadFailed ? (this.usedByImageViewer ? '#ffdbdbdb' : '#5F808080') : '#7F808080')
        .borderRadius(5)
        .alignSelf(ItemAlign.Start)
      }
      if (this.imageUrl && !this.loadFailed) {
        ImageKnifeComponent({
          imageKnifeOption: {
            headerOption: [{
              key: 'cookie',
              value: DomainRegex.test(this.imageUrl) ? userCookieString : ''
            }, {
              key: 'user-agent',
              value: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36'
            }],
            loadSrc: encodeURI(this.imageUrl),
            customGetImage: this.retry >= NO_PROXY_FROM_RETRY ? customGetImageNoProxy : undefined,
            objectFit: ImageFit.Contain,
            onLoadListener: {
              onLoadFailed: (err) => {
                if (this.retry >= MAX_RETRY) {
                  this.loadFailed = true
                  this.retryHint = ''
                  this.onFailed()
                } else {
                   this.retry += 1
                  this.retryHint = this.retry >= NO_PROXY_FROM_RETRY
                    ? '网络异常\n\n重试2次'
                    : '网络异常\n\n重试1次'
                  this.imageUrl = ''
                  setTimeout(() => {
                    this.imageUrl = this.src
                  }, 10)
                }
              }
            },
            // 预览只解码到显示区域大小；查看器在转场动画结束后才切到原图
            downsampleOf: this.usedByImageViewer && this.fullResolution
              ? DownsampleStrategy.NONE
              : DownsampleStrategy.FIT_CENTER_QUALITY,
            onComplete: (imageSize) => {
              // 给ImageKnifeComponent用auto height在显示动图的时候，会按height 100%来处理，而不是自适应图片高度
              // 暂时二次设置图片高度
              this.loadComplete = true
              this.retryHint = ''
              if (imageSize) {
                this.imgSize = {
                  w: imageSize.width,
                  h: imageSize.height
                }
                if (this.usedByImageViewer === false) {
                  reportImageSize(this.src, imageSize.width, imageSize.height)
                  this.computeThumbHash(imageSize.width, imageSize.height)
                }
                this.resize(imageSize.componentWidth)
              }
            }
          }
        }).onClick(this.onImgClick ? (e) => {
          // 先记录锚点并标记有效，再打开查看器。
          // 若先 onImgClick ，会导致查看器读到未标记的 valid=false，冷启动首次入场动画丢失位移。
          markImageViewerTransitionFromClick(e)
          this.onImgClick && this.onImgClick()
        } : undefined)
          .hitTestBehavior(this.onImgClick ? undefined : HitTestMode.None)
      }
    }.height(this.imgHeight)
    .width(this.loadFailed ? (this.usedByImageViewer ? 'auto' : '100%') : this.imgWidth)
    .onAreaChange((oldValue, newValue) => {
      this.resizeOnAreaChange(newValue.width as number)
    })
    .onVisibleAreaChange([0, 1], (isVisible: boolean, currentRatio: number) => {
      if (currentRatio > 0) {
        imageBackgroundGuard.release(this.guardId)
        if (this.imageUrl != this.src) {
          this.imageUrl = this.src
        }
      } else if (this.lazyLoad && !this.usedByImageViewer && this.imageUrl.length > 0 &&
        !imageBackgroundGuard.isHeld(this.guardId)) {
        // 出视野，销毁图片组件，释放显存
        this.imageUrl = ''
        this.loadComplete = false
      }
    })
  }
}


export function resizeImgFitHeight(imageSize: RectSize, height: number) {
  const result: RectSize = {
    w: imageSize.w * height / imageSize.h,
    h: imageSize.h * height / imageSize.h
  }
  return result
}

export function resizeImgFitWidth(imageSize: RectSize, width: number) {
  const result: RectSize = {
    w: imageSize.w * width / imageSize.w,
    h: imageSize.h * width / imageSize.w
  }
  return result
}

@Concurrent
async function customGetImageNoProxy(context: Context, src: string | PixelMap | Resource,
  headers?: Record<string, Object>): Promise<ArrayBuffer | undefined> {
  return new Promise((resolve, reject) => {
    if (typeof src !== 'string') {
      resolve(undefined)
      return
    }
    const session = rcp.createSession()
    try {
      const req = new rcp.Request(src, 'GET')
      req.configuration = {
        proxy: 'no-proxy',
        transfer: {
          autoRedirect: true
        }
      }
      const reqHeaders: Record<string, string> = {}
      if (headers) {
        const keys = Object.keys(headers)
        for (let i = 0; i < keys.length; i++) {
          const k = keys[i]
          reqHeaders[k] = `${headers[k]}`
        }
      }
      req.headers = reqHeaders
      session.fetch(req).then((response: rcp.Response) => {
        if (response.statusCode === 200 || response.statusCode === 206) {
          resolve(response.body as ArrayBuffer)
        } else {
          reject('rcp code:' + response.statusCode)
        }
      }).catch((err: BusinessError) => {
        reject('error rcp src:' + src + ',err:' + JSON.stringify(err))
      }).finally(() => {
        session.close()
      })
    } catch (e) {
      session.close()
      reject('customGetImageNoProxy error:' + JSON.stringify(e))
    }
  })
}