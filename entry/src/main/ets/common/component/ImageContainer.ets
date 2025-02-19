import { ImageKnifeComponent } from '@ohos/imageknife'
import { DomainRegex } from '../../api/base'
import { userCookieString } from '../../api/request'
import { openInBrowser } from '../WantUitl'
import { common } from '@kit.AbilityKit'
import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { ImageViewerTransitionToSize } from './ImageViewer'

export interface RectSize {
  w: number,
  h: number
}

@Component
export struct ImageContainer {
  @Consume appState: PreferenceState
  @State imageUrl: string = ''
  @State loadComplete: boolean = false
  @State loadingProgress: number = 0
  @State loadFailed: boolean = false
  imgSize?: RectSize
  @Prop @Watch('resize') constrainSize: RectSize | undefined = undefined
  lastConstrainSizeWidth: number | undefined = undefined
  src: string = ''
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
            loadSrc: this.imageUrl,
            objectFit: ImageFit.Contain,
            onLoadListener: {
              onLoadFailed: (err) => {
                this.loadFailed = true
                this.onFailed()
              }
            },
            onComplete: (imageSize) => {
              // 给ImageKnifeComponent用auto height在显示动图的时候，会按height 100%来处理，而不是自适应图片高度
              // 暂时二次设置图片高度
              this.loadComplete = true
              if (imageSize) {
                this.imgSize = {
                  w: imageSize.width,
                  h: imageSize.height
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