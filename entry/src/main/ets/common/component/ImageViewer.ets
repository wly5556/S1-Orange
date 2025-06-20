import { common } from '@kit.AbilityKit'
import { AniSpeed, HeavyClickEffect, SpringCurve } from '../Animation'
import { ImageContainer, RectSize } from './ImageContainer'
import { PageIndexDataSource } from './SwipePageViewer'
import { AppThemeColor } from '../theme/basic/basic'
import { themeColorDark } from '../theme/basic/dark'
import { curves, matrix4, window } from '@kit.ArkUI'
import { SetStatusBarColor } from '../theme/SetStatusBarColor'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { ImageKnife } from '@ohos/imageknife'
import { BusinessError } from '@kit.BasicServicesKit'
import { extractFileExtension } from '../TextUtil'
import { fileIo } from '@kit.CoreFileKit'
import { CopyHyperLink, ShareImage } from '../ShareKit'
import { displaySync } from '@kit.ArkGraphics2D'
import { openInBrowser } from '../WantUitl'
import { SafeArea } from '../Constants'

export interface ImageViewerParam {
  urls: string[],
  startAt: number
}

const imgContainerSize: RectSize = {
  w: 0,
  h: 0
}

const frameSync: displaySync.DisplaySync = displaySync.create()


let frameSyncIsOn: boolean = false

function useFrameSync(f: (ts: number) => boolean) {
  if (frameSyncIsOn) {
    frameSync?.off('frame')
  }
  frameSync?.on('frame', e => {
    if (!f(e.timestamp)) {
      offFrameSync()
    }
  })
  frameSync.start()
  frameSyncIsOn = true
}

function offFrameSync() {
  if (frameSyncIsOn) {
    frameSync?.off('frame')
    frameSync.stop()
    frameSyncIsOn = false
  }
}

const ImageViewerCacheCount = 1

export let ImageViewerTransitionToSize: RectSize = {
  w: 0,
  h: 0
}

@Component
export struct ImageViewer {
  context = getContext(this) as common.UIAbilityContext
  dataSource: PageIndexDataSource = new PageIndexDataSource(0)
  @Consume appTheme: AppThemeColor
  @Prop param: ImageViewerParam = { urls: [], startAt: 0 }
  @State swiperIndex: number = 0
  @State targetSwiperIndex: number = 0
  @State imgCount: number = 0
  @Link @Watch('showUpChanged') showUp: boolean
  @State imgMatrix: matrix4.Matrix4Transit[] = []
  @StorageProp(SafeArea.top) topRectHeight: number = 0
  imgTransform: matrixHelper[] = []
  @State imgLoaded: boolean[] = []
  @State imgLoadFailed: boolean[] = []
  @State showButton: boolean = true
  @State imgContainerSizeState: RectSize = imgContainerSize // 用于旋屏后刷新图片大小
  @State transitionExitEffect: TransitionEffect | undefined = undefined

  aboutToAppear(): void {
    this.targetSwiperIndex = this.swiperIndex = this.param.startAt
    this.dataSource.setPageCount(this.param.urls.length)
    for (let i = 0; i < this.param.urls.length; i++) {
      this.imgTransform[i] = new matrixHelper()
      this.imgMatrix[i] = matrix4.identity()
    }
    this.imgCount = this.param.urls.length
    SetStatusBarColor(this.context, themeColorDark)
  }

  showUpChanged() {
    if (this.showUp === false && this.imgCount > 0) {
      SetStatusBarColor(this.context, this.appTheme)
      this.showStatusBar()
      this.imgTransform[this.swiperIndex].reset()
      // geometryTransition会将组件左上角对齐，但不会匹配大小
      // 还需要添加图片缩放退场动画
      const scale = ImageViewerTransitionToSize.w / this.imgTransform[this.swiperIndex].width
      this.transitionExitEffect = TransitionEffect.scale({
        centerX: 0,
        centerY: 0,
        x: scale,
        y: scale
      })
      this.updateImageTransformMatrix()
    }
  }

  showStatusBar() {
    window.getLastWindow(this.context).then(w => {
      if (canIUse('SystemCapability.Window.SessionManager')) {
        w.setSpecificSystemBarEnabled('status', true, true)
        w.setSpecificSystemBarEnabled('navigation', true, true)
        w.setSpecificSystemBarEnabled('navigationIndicator', true, true)
      }
    })
  }

  hideStatusBar() {
    window.getLastWindow(this.context).then(w => {
      if (canIUse('SystemCapability.Window.SessionManager')) {
        w.setSpecificSystemBarEnabled('status', false, true)
        w.setSpecificSystemBarEnabled('navigation', false, true)
        w.setSpecificSystemBarEnabled('navigationIndicator', false, true)
      }
    })
  }

  @Builder
  imageSave() {
    SaveButton({
      text: SaveDescription.SAVE_TO_GALLERY
    })
      .height(48)
      .width('100%')
      .fontColor(this.appTheme.fontPrimary)
      .backgroundColor(this.appTheme.backgroundPrimary)
      .onClick(async (event: ClickEvent, result: SaveButtonOnClickResult) => {
        if (result != SaveButtonOnClickResult.SUCCESS) {
          return
        }
        const helper = photoAccessHelper.getPhotoAccessHelper(this.context);
        try {
          const imageUrl = this.param.urls[this.swiperIndex]
          const fileExtname = extractFileExtension(imageUrl)
          const saveToFile = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, fileExtname)
          if (typeof saveToFile == 'string') {
            const knife = ImageKnife.getInstance()
            const cacheFilePath = await knife.preLoadCache(imageUrl)
            const readFile = await fileIo.open(cacheFilePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
            const writeFile = await fileIo.open(saveToFile, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
            const buf = new ArrayBuffer(4096)
            let fileSize = 0
            let readByte = 0
            while ((readByte = await fileIo.read(readFile.fd, buf)) > 0) {
              await fileIo.write(writeFile.fd, buf)
              fileSize += readByte
            }
            fileIo.close(readFile.fd)
            fileIo.close(writeFile.fd)
            this.getUIContext().getPromptAction().showToast({
              message: `保存成功, 文件大小${(fileSize / 1024 / 1024).toFixed(2)}MB`
            })
          }
        } catch (error) {
          const err: BusinessError = error as BusinessError;
          console.error(`Failed to save photo. Code is ${err.code}, message is ${err.message}`);
        }
      })
  }

  @Builder
  menuItem(text: string) {
    Button(text)
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .width('100%')
      .fontColor(this.appTheme.fontPrimary) // 只是为了和save button样式一致
  }

  @Builder
  imageMenu() {
    Menu() {
      MenuItem(this.imageSave)
      MenuItem(this.menuItem('分享')).onClick(async e => {
        const imageUrl = this.param.urls[this.swiperIndex]
        const cacheFilePath = await ImageKnife.getInstance().preLoadCache(imageUrl)
        const ext = extractFileExtension(imageUrl)
        if (cacheFilePath && ext != null) {
          ShareImage(cacheFilePath, ext, this.context)
        }
      })
      MenuItem(this.menuItem('复制链接')).onClick(() => {
        CopyHyperLink(this.param.urls[this.swiperIndex])
      })
      MenuItem(this.menuItem('浏览器打开')).onClick(e => {
        openInBrowser(this.context, this.param.urls[this.swiperIndex])
      })
    }.backgroundColor(this.appTheme.backgroundPrimary)
    .width(160)
  }

  build() {
    Stack() {
      Column() {

      }.width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .transition(TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms300 }))

      Swiper() {
        LazyForEach(this.dataSource, (pageIndex: number, compIndex: number) => {
          Stack() {
            if (!this.imgLoaded[compIndex] && !this.imgLoadFailed[compIndex]) {
              LoadingProgress()
                .width(64)
                .height(64)
                .color($r('sys.color.ohos_id_color_emphasize'))
            }
            ImageContainer({
              src: this.param.urls[compIndex],
              usedByImageViewer: true,
              lazyLoad: false,
              constrainSize: this.imgContainerSizeState,
              imgWidth: '100%',
              imgHeight: '100%',
              afterResize: (size) => {
                this.imgLoaded[compIndex] = true
                this.imgTransform[compIndex].setImageSize(size.w, size.h)
              },
              onFailed: () => {
                this.imgLoadFailed[compIndex] = true
              }
            })
              .transform(this.imgMatrix[compIndex])
              .geometryTransition(generateImageViewerTransitionKey(this.param.urls[compIndex], compIndex.toString()))
              .transition(this.transitionExitEffect)
          }
          .width('100%')
          .height('100%')
          .onTouch(e => {
            offFrameSync()
          })
          .gesture(TapGesture({ count: 2, distanceThreshold: 1 }).onAction(e => {
            this.imgTransform[this.swiperIndex].onTap(vp2px(e.fingerList[0].localX), vp2px(e.fingerList[0].localY))
            animateTo(SpringCurve, () => {
              this.updateImageTransformMatrix()
            })
          }))
          .gesture(PinchGesture({ distance: 0.1 }).onActionStart(e => {
            this.imgTransform[this.swiperIndex].beginPinch()
          }).onActionUpdate(e => {
            this.imgTransform[this.swiperIndex].updatePinch(vp2px(e.pinchCenterX), vp2px(e.pinchCenterY), e.scale)
            this.updateImageTransformMatrix()
          }).onActionEnd(e => {
            this.imgTransform[this.swiperIndex].endPinch()
            animateTo(SpringCurve, () => {
              this.updateImageTransformMatrix()
            })
          }))
          .gesture(PanGesture({ distance: 0.1 }).onActionStart(e => {
          }).onActionStart(e => {
            this.imgTransform[this.swiperIndex].beginTranslate(e.timestamp)
          }).onActionUpdate(e => {
            this.imgTransform[this.swiperIndex].updateTranslate(vp2px(e.offsetX), vp2px(e.offsetY), e.timestamp)
            this.updateImageTransformMatrix()
          }).onActionEnd(e => {
            this.imgTransform[this.swiperIndex].updateTranslate(vp2px(e.offsetX), vp2px(e.offsetY), e.timestamp)
            this.imgTransform[this.swiperIndex].beginFling(e.timestamp)
            this.updateImageTransformMatrix()
            useFrameSync(ts => {
              const moved = this.imgTransform[this.swiperIndex].fling(ts) || false
              this.updateImageTransformMatrix()
              return moved
            })
          }))
          .onGestureJudgeBegin((gestureInfo: GestureInfo, event: BaseGestureEvent) => {
            if (this.imgLoadFailed[this.swiperIndex]) {
              return GestureJudgeResult.REJECT
            }
            if (gestureInfo.type == GestureControl.GestureType.PAN_GESTURE) {
              const panEvent = event as PanGestureEvent
              if (Math.abs(panEvent.velocityX) > Math.abs(panEvent.velocityY) &&
                !this.imgTransform[this.swiperIndex].selfScrollFirst(panEvent.offsetX > 0)) {
                return GestureJudgeResult.REJECT
              }
            }
            return GestureJudgeResult.CONTINUE
          })
        })
      }
      .indicator(false)
      .loop(false)
      .width('100%')
      .height('100%')
      .cachedCount(ImageViewerCacheCount)
      .index($$this.swiperIndex)
      .onAnimationStart((index: number, targetIndex: number) => {
        this.targetSwiperIndex = targetIndex
        this.updateButtonVisibility()
      })
      .onSizeChange((old, newVal) => {
        imgContainerSize.w = vp2px(parseFloat(newVal.width?.toString() || '0'))
        imgContainerSize.h = vp2px(parseFloat(newVal.height?.toString() || '0'))
        this.imgContainerSizeState = imgContainerSize
        this.imgTransform[this.swiperIndex].reset()
        this.updateImageTransformMatrix()
      })

      Row() {
        Stack() {
          Image($r('app.media.arrow_left')).width(28).height(28)
            .fillColor(Color.White)
        }.StackBlurButton().ultraThinBlur()
        .onClick(e => {
          this.getUIContext()
            .animateTo(SpringCurve, () => {
              this.showUp = false
            })
        })

        Row() {
          Text(`${this.targetSwiperIndex + 1}/${this.imgCount}`).fontColor(Color.White)
        }.padding({ left: 6, right: 6 })
        .height(32)
        .borderRadius(16)
        .ultraThinBlur()

        Stack() {
          Image($r('app.media.dot_grid')).width(28).height(28)
            .fillColor(Color.White)
        }.StackBlurButton()
        .bindMenu(this.imageMenu)
        .ultraThinBlur()
        .visibility(this.imgLoaded[this.targetSwiperIndex] ? Visibility.Visible : Visibility.Hidden)
      }
      .visibility(this.showButton ? Visibility.Visible : Visibility.Hidden)
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.asymmetric(
        TransitionEffect.scale({ x: 0.8, y: 0.8 }),
        TransitionEffect.scale({ x: 1.2, y: 1.2 })
      )))
      .margin({ top: px2vp(this.topRectHeight) })
      .width('100%')
      .padding(10)
      .justifyContent(FlexAlign.SpaceBetween)
    }.alignContent(Alignment.Top)
  }

  updateImageTransformMatrix() {
    this.imgMatrix[this.swiperIndex] = this.imgTransform[this.swiperIndex].getMat()
    this.updateButtonVisibility()
  }

  updateButtonVisibility() {
    if (this.imgTransform[this.targetSwiperIndex].scaleRatio == 1 && this.showButton == false) {
      animateTo(SpringCurve, () => {
        this.showButton = true
        this.showStatusBar()
      })
    }
    if (this.imgTransform[this.targetSwiperIndex].scaleRatio > 1 && this.showButton == true) {
      animateTo({
        curve: curves.springMotion(0.35), onFinish: () => {
          if (this.showButton === false) {
            this.hideStatusBar()
          }
        }
      }, () => {
        this.showButton = false
      })
    }
  }
}

/**
 * 注意确保传入的一切尺寸单位为px
 */
class matrixHelper {
  private translate = new TranslateHelper()
  scaleRatio: number = 1
  transitionExitScale: number = 1
  width: number = 0
  height: number = 0
  private fitScale: number = 1

  setImageSize(width: number, height: number) {
    this.width = width
    this.height = height
    this.onContainerSizeChange()
  }

  onContainerSizeChange() {
    if (this.width == imgContainerSize.w && this.height < imgContainerSize.h) {
      this.fitScale = imgContainerSize.h / this.height
    } else if (this.height == imgContainerSize.h && this.width < imgContainerSize.w) {
      this.fitScale = imgContainerSize.w / this.width
    }
  }

  reset() {
    this.translate = new TranslateHelper()
    this.scaleRatio = 1
  }

  private limitInScreen() {
    const centerX = imgContainerSize.w / 2 + this.translate.X * this.scaleRatio
    const centerY = imgContainerSize.h / 2 + this.translate.Y * this.scaleRatio
    const scaledW = this.width * this.scaleRatio
    const scaledH = this.height * this.scaleRatio
    const leftTopX = centerX - scaledW / 2
    const leftTopY = centerY - scaledH / 2
    if (scaledW > imgContainerSize.w) {
      const maxX = 0
      const minX = imgContainerSize.w - scaledW
      this.translate.X += (Math.min(Math.max(leftTopX, minX), maxX) - leftTopX) / this.scaleRatio
    } else {
      this.translate.X = 0
    }
    if (scaledH > imgContainerSize.h) {
      const maxY = 0
      const minY = imgContainerSize.h - scaledH
      this.translate.Y += (Math.min(Math.max(leftTopY, minY), maxY) - leftTopY) / this.scaleRatio
    } else {
      this.translate.Y = 0
    }
  }

  getMat(): matrix4.Matrix4Transit {
    return matrix4.identity().translate({
      x: this.translate.X,
      y: this.translate.Y
    }).scale({
      x: this.scaleRatio,
      y: this.scaleRatio,
      // centerX: ,
      // centerY:    // 变换原点默认位于控件中心
    })
  }

  scale(newScale: number, scaleCenterX: number, scaleCenterY: number) { // scaleCenter.XY的数值相对于容器左上角，需要转换到缩放变换中心
    const centerX = imgContainerSize.w / 2 + this.translate.X * this.scaleRatio
    const centerY = imgContainerSize.h / 2 + this.translate.Y * this.scaleRatio
    const dx = centerX - scaleCenterX
    const dy = centerY - scaleCenterY
    this.translate.X =
      (dx * (newScale - this.scaleRatio) / this.scaleRatio + this.translate.X * this.scaleRatio) / newScale
    this.translate.Y =
      (dy * (newScale - this.scaleRatio) / this.scaleRatio + this.translate.Y * this.scaleRatio) / newScale
    this.scaleRatio = newScale
  }

  onTap(tapX: number, tapY: number) {
    let newScale = 1
    if (this.scaleRatio >= this.fitScale * 2) {
      newScale = 1
    } else if (this.scaleRatio >= this.fitScale) {
      newScale = 2 * this.fitScale
    } else { // current scale == 1
      newScale = this.fitScale
    }
    this.scale(newScale, tapX, tapY)
    this.limitInScreen()
  }

  scaleConstraint() {
    this.scaleRatio = Math.min(Math.max(this.scaleRatio, 1), this.fitScale * 6)
  }

  initialScale: number = 0

  beginPinch() {
    this.initialScale = this.scaleRatio
  }

  updatePinch(pinchX: number, pinchY: number, scale: number) {
    this.scale(scale * this.initialScale, pinchX, pinchY)
  }

  endPinch() {
    this.scaleConstraint()
    this.limitInScreen()
  }

  beginTranslate(nanoTs: number) {
    this.translate.reset(nanoTs)
  }

  updateTranslate(offsetX: number, offsetY: number, nanoTs: number) {
    this.translate.updatePos(offsetX / this.scaleRatio, offsetY / this.scaleRatio, nanoTs)
    this.limitInScreen()
  }

  beginFling(nanoTs: number) {
    this.translate.beginFling(nanoTs)
  }

  fling(ts: number) {
    const moved = this.translate.fling(ts)
    this.limitInScreen()
    return moved
  }

  /**
   *
   * @param directionX 手势是否沿X轴正向
   * @returns true，当图片的滑动手势需要优先响应（而不是swiper的左右切换）
   */
  selfScrollFirst(directionX: boolean) {
    const centerX = imgContainerSize.w / 2 + this.translate.X * this.scaleRatio
    const width = this.width * this.scaleRatio
    const leftTopX = centerX - width / 2
    if (width > imgContainerSize.w) {
      const minX = imgContainerSize.w - width
      if ((leftTopX - minX) < 1 && directionX == false) {
        return false
      }
      if (-1 < leftTopX && directionX == true) {
        return false
      }
      return true
    }
    return false
  }
}


const SHORT_DRAG_DISTANCE_CLAMP = 5 // vp
const LONG_DRAG_DISTANCE_CLAMP = 60 // vp

const MIN_FRICTION = 0.1
const MAX_FRICTION = 5

const STOP_FLING_VEL = vp2px(3e-8) // vp / ns

const INPUT_PAUSE_THRESHOLD_NS = 60_000_000
const VELOCITY_HALF_LIFE_NS = 10_000_000
const VELOCITY_TAU_MS = VELOCITY_HALF_LIFE_NS / Math.LN2

/**
 * 辅助处理惯性滚动
 */
class TranslateHelper {
  X: number = 0
  Y: number = 0
  private startX: number = 0 // 完整拖拽的起止点
  private startY: number = 0
  private lastTime: number = 0
  private velocityX: number = 0 // px / ns
  private velocityY: number = 0 // px / ns
  private pauseX: number = 0 // 拖拽过程中的停顿位置
  private pauseY: number = 0

  reset(lastTime: number) {
    this.startX = this.pauseX = this.X
    this.startY = this.pauseY = this.Y
    this.lastTime = lastTime
    this.velocityX = 0
    this.velocityY = 0
    this.flingTs = 0
  }

  updatePos(dx: number, dy: number, nanoTs: number) {
    const deltaTimeNs = nanoTs - this.lastTime

    if (deltaTimeNs <= 0) {
      this.lastTime = nanoTs
      this.X = dx + this.startX
      this.Y = dy + this.startY
      return
    }

    const newX = dx + this.startX
    const newY = dy + this.startY
    const instVelX = (newX - this.X) / deltaTimeNs
    const instVelY = (newY - this.Y) / deltaTimeNs

    // 发生停顿，将速度重置为0，记录停顿点
    if (deltaTimeNs > INPUT_PAUSE_THRESHOLD_NS) {
      this.velocityX = 0
      this.velocityY = 0
      this.pauseX = newX
      this.pauseY = newY
    }

    const alpha = 1 - Math.exp(-deltaTimeNs / VELOCITY_TAU_MS)

    this.velocityX = alpha * instVelX + (1 - alpha) * this.velocityX
    this.velocityY = alpha * instVelY + (1 - alpha) * this.velocityY

    this.X = newX
    this.Y = newY
    this.lastTime = nanoTs
  }

  private flingInitialVelX: number = 0
  private flingInitialVelY: number = 0
  private flingTs: number = 0
  private flingFriction: number = MAX_FRICTION

  calculateFling() {
    const dragDistance = Math.hypot(px2vp(this.X - this.pauseX), px2vp(this.Y - this.pauseY))
    const t = Math.min(1, Math.max(0,
      (dragDistance - SHORT_DRAG_DISTANCE_CLAMP) /
        (LONG_DRAG_DISTANCE_CLAMP - SHORT_DRAG_DISTANCE_CLAMP)
    )) // t -> [0,1]，和拖动距离成正比
    // 距离越短摩擦越大
    this.flingFriction = MAX_FRICTION + t * (MIN_FRICTION - MAX_FRICTION)

    this.flingInitialVelX = this.velocityX
    this.flingInitialVelY = this.velocityY
  }

  beginFling(nanoTs: number) {
    this.calculateFling()
    this.reset(nanoTs)
  }

  fling(nanoTs: number) {
    if (this.flingTs === 0) {
      this.flingTs = nanoTs
      return true
    }
    const elapsedTime = (nanoTs - this.flingTs) / 1e9 // s
    if (elapsedTime <= 0) {
      return true
    }
    const decayFactor = Math.exp(-this.flingFriction * elapsedTime);

    const currentVelX = this.flingInitialVelX * decayFactor
    const currentVelY = this.flingInitialVelY * decayFactor

    // px / ns
    if (Math.hypot(currentVelX, currentVelY) < STOP_FLING_VEL) {
      return false
    }

    const displacementFactor = (1 - decayFactor) / this.flingFriction
    const dx = this.flingInitialVelX * 1e9 * displacementFactor
    const dy = this.flingInitialVelY * 1e9 * displacementFactor

    this.X = this.startX + dx
    this.Y = this.startY + dy

    return true
  }
}

@Styles
function StackBlurButton() {
  .width(40)
  .height(40)
  .borderRadius(40 / 2)
  .clickEffect(HeavyClickEffect)
}

@Styles
function ultraThinBlur() {
  .backgroundEffect({
    brightness: 0.8,
    radius: 12,
  })
}

export function generateImageViewerTransitionKey(url: string, indexInUrls: string) {
  return 'imageContainer_' + url + indexInUrls
}