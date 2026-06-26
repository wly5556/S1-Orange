import { DownsampleStrategy, ImageKnifeComponent, ImageKnifeRequest } from '@ohos/imageknife'
import { DomainRegex } from '../../api/base'
import { userCookieString } from '../../api/request'
import { openInBrowser } from '../WantUitl'
import { common } from '@kit.AbilityKit'
import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { ImageViewerTransitionToSize } from './ImageViewer'
import { rcp } from '@kit.RemoteCommunicationKit'
import { BusinessError } from '@kit.BasicServicesKit'

export interface RectSize {
  w: number,
  h: number
}

const MAX_RETRY = 2
const NO_PROXY_FROM_RETRY = 2

@Component
export struct ImageContainer {
  @Consume appState: PreferenceState
  @State imageUrl: string = ''
  @State loadComplete: boolean = false
  @State loadingProgress: number = 0
  @State loadFailed: boolean = false
  @State retryHint: string = ''
  @State downsampleStrategy: DownsampleStrategy = DownsampleStrategy.DEFAULT
  imgSize?: RectSize
  @Prop @Watch('resize') constrainSize: RectSize | undefined = undefined
  lastConstrainSizeWidth: number | undefined = undefined
  src: string = ''
  retry: number = 0
  usedByImageViewer: boolean = false
  @Prop imgHeight: number | string = 100 * FontSizeEnum[this.appState.fontSize].ratio
  @Prop imgWidth: number | string = '100%'
  lazyLoad: boolean = true
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
    if (this.constrainSize) { // 限制高度的情况下contain fit
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
    } else { // 其他情况占满横边适应
      resizeTo = resizeImgFitWidth(this.imgSize, Math.min(vp2px(this.imgSize.w), componentWidth))
    }
    this.imgHeight = px2vp(resizeTo.h)
    this.imgWidth = px2vp(resizeTo.w)
  }

  build() {
    Column() {
      if ((!this.loadComplete && !this.usedByImageViewer) || this.loadFailed) {
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
        .onClick(e => {
          openInBrowser(getContext(this) as common.UIAbilityContext, this.imageUrl)
        })
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .width(100 * FontSizeEnum[this.appState.fontSize].ratio)
        .height(90 * FontSizeEnum[this.appState.fontSize].ratio)
        .margin({
          top: 5,
          bottom: 5
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
            downsampleOf: this.downsampleStrategy,
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
                if (imageSize.width * imageSize.height >= 16777216 && this.usedByImageViewer === false) {
                  this.downsampleStrategy = DownsampleStrategy.FIT_CENTER_QUALITY
                }
                this.resize(imageSize.componentWidth)
              }
            }
          }
        }).onClick(this.onImgClick ? (e) => {
          this.onImgClick && this.onImgClick()
          ImageViewerTransitionToSize.w = vp2px(parseFloat(e.target.area.width.toString() || '0'))
        } : undefined)
          .hitTestBehavior(this.onImgClick ? undefined : HitTestMode.None)
      }
    }.height(this.imgHeight)
    .width(this.loadFailed ? (this.usedByImageViewer ? 'auto' : '100%') : this.imgWidth)
    .onVisibleAreaChange([0.01, 1], () => {
      if (this.imageUrl != this.src) {
        this.imageUrl = this.src
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