import { common } from '@kit.AbilityKit'
import { AniSpeed, HeavyClickEffect, SpringCurve } from '../Animation'
import { ImageContainer, RectSize } from './ImageContainer'
import { LoadingIcon } from './LoadingIcon'
import { PageIndexDataSource } from './SwipePageViewer'
import { AppThemeColor } from '../theme/basic/basic'
import { themeColorDark } from '../theme/basic/dark'
import { curves, matrix4 } from '@kit.ArkUI'
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
import { Event } from '../Events'

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

const EXIT_PINCH_SCALE_THRESHOLD = 0.9 // 松手时缩放小于该值则直接退出大图查看器

export let ImageViewerTransitionToSize: RectSize = {
  w: 0,
  h: 0
}

// 缩略图窗口全局坐标(px)，入场对齐与退场对齐共用
export let ImageViewerTransitionToPos: RectSize = {
  w: 0,
  h: 0
}

// 最近一次点击缩略图时记录的数据是否有效（区别于头像等未记录尺寸的入口）
let viewerTransitionValid = false

/** 记录缩略图锚点（尺寸与窗口坐标均为px）并标记入场对齐有效 */
export function markImageViewerTransition(w: number, h: number, x: number, y: number) {
  viewerTransitionValid = true
  ImageViewerTransitionToSize.w = w
  ImageViewerTransitionToSize.h = h
  ImageViewerTransitionToPos.w = x
  ImageViewerTransitionToPos.h = y
}

/** 从点击事件目标区域提取锚点（vp转px）并标记有效 */
export function markImageViewerTransitionFromClick(e: ClickEvent) {
  markImageViewerTransition(
    vp2px(parseFloat(e.target.area.width.toString() || '0')),
    vp2px(parseFloat(e.target.area.height.toString() || '0')),
    vp2px(parseFloat(e.target.area.globalPosition.x?.toString() || '0')),
    vp2px(parseFloat(e.target.area.globalPosition.y?.toString() || '0')))
}

export function consumeImageViewerTransitionValid(): boolean {
  const valid = viewerTransitionValid
  viewerTransitionValid = false
  return valid
}

let activeExitHandler: (() => void) | null = null

/**
 * 请求退出当前大图查看器，由其自控退场动画
 * @returns 是否接管；false时调用方按原逻辑直接关闭
 */
export function requestImageViewerExit(): boolean {
  if (activeExitHandler == null) {
    return false
  }
  activeExitHandler()
  return true
}

const SHORT_DRAG_DISTANCE_CLAMP = 8 // vp
const LONG_DRAG_DISTANCE_CLAMP = 60 // vp
const MIN_FLING_DRAG_VP = 2 // 位移小于该值的手势不产生惯性（多为在惯性滚动中轻点刹车）
const MIN_FRICTION = 1 // 越小滑得越远越久
const MAX_FRICTION = 7
const STOP_FLING_VEL = vp2px(3e-8) // px / ns
const SIGNAL_BUFFER_SIZE = 64
const MAX_PREDICTION_LEAD_NS = 20_000_000 // 未来帧预测的提前量上限
const FULL_PREDICTION_NS = 10_000_000 // 采样间隔在该时长内按全额速度外推，直接决定急停后的过冲峰值
const STALE_EXTRAPOLATE_NS = 26_000_000 // 采样停更超过该时长后完全收回外推
const SMOOTH_TAU_NS = 36_000_000 // 输出一阶低通时间常数，越大越黏、跟随滞后约等于 v*τ
const VELOCITY_FIT_WINDOW_NS = 40_000_000 // 速度拟合的时间窗口
const MIN_VELOCITY_FIT_SPAN_NS = 8_000_000 // 视作有效拟合所需的最小时间跨度，过小会把采样噪声放大成高速
const INPUT_PAUSE_THRESHOLD_NS = 60_000_000 // 相邻采样间隔超过该值视为中途停顿
const FRAME_INTERVAL_ALPHA = 0.3 // 帧间隔估计的平滑系数
const APPLY_POS_EPSILON_PX = 0.05 // 相邻帧位移差小于该值时不触发重绘
const APPLY_SCALE_EPSILON = 1e-4

class SignalSample {
  ts: number = 0
  x: number = 0
  y: number = 0
  scale: number = 1

  set(ts: number, x: number, y: number, scale: number) {
    this.ts = ts
    this.x = x
    this.y = y
    this.scale = scale
  }
}

class SignalValue {
  x: number = 0
  y: number = 0
  scale: number = 1
}

/**
 * pan 与 pinch 互斥，共用同一条采样时间线：手势回调只负责塞采样，
 * 位移/缩放的实际求解全部推迟到帧回调里按时间插值（并做未来帧预测）后统一施加，
 * 拖拽末速度也由同一套速度估计给出，惯性滚动因此可以直接接续而不产生断层
 */
class GestureSignal {
  private samples: SignalSample[] = []
  private writeIndex: number = 0
  private size: number = 0
  private vx: number = 0 // px / ns
  private vy: number = 0 // px / ns
  private vs: number = 0 // 1 / ns
  private pauseX: number = 0 // 中途停顿点（手势位移空间，px）
  private pauseY: number = 0
  private clockOffset: number = 0 // 帧时钟与手势事件时钟的固定偏差
  private clockAligned: boolean = false

  constructor() {
    for (let i = 0; i < SIGNAL_BUFFER_SIZE; i++) {
      this.samples.push(new SignalSample())
    }
  }

  clear() {
    this.writeIndex = 0
    this.size = 0
    this.vx = 0
    this.vy = 0
    this.vs = 0
    this.pauseX = 0
    this.pauseY = 0
    this.clockAligned = false
  }

  count(): number {
    return this.size
  }

  /** i 为 0 时取最旧采样，为 count()-1 时取最新采样 */
  at(i: number): SignalSample {
    return this.samples[(this.writeIndex - this.size + i + SIGNAL_BUFFER_SIZE) % SIGNAL_BUFFER_SIZE]
  }

  push(ts: number, x: number, y: number, scale: number) {
    const prevTs = this.size > 0 ? this.at(this.size - 1).ts : 0
    const sampleTs = ts > prevTs ? ts : prevTs // 时间戳保持单调，防止时钟抖动打乱插值区间
    if (this.size > 0 && sampleTs - prevTs > INPUT_PAUSE_THRESHOLD_NS) {
      this.pauseX = x
      this.pauseY = y
    }
    this.samples[this.writeIndex].set(sampleTs, x, y, scale)
    this.writeIndex = (this.writeIndex + 1) % SIGNAL_BUFFER_SIZE
    if (this.size < SIGNAL_BUFFER_SIZE) {
      this.size++
    }
  }

  velocityX(): number {
    return this.vx
  }

  velocityY(): number {
    return this.vy
  }

  /** 最近一次停顿点到最新采样的位移（px） */
  pauseDistance(): number {
    if (this.size == 0) {
      return 0
    }
    const last = this.at(this.size - 1)
    return Math.hypot(last.x - this.pauseX, last.y - this.pauseY)
  }

  /**
   * 帧时钟与手势事件时钟未必同源，首帧用最新采样对两者做一次对齐，
   * 对齐后的帧时间加 lead 即为本次消费的时刻
   */
  consumeTime(frameTs: number, leadNs: number): number {
    if (!this.clockAligned) {
      this.clockOffset = frameTs - this.at(this.size - 1).ts
      this.clockAligned = true
    }
    return frameTs - this.clockOffset + leadNs
  }

  /** 窗口内采样做最小二乘线性拟合，兼作速度平滑与去抖 */
  updateVelocity() {
    const n = this.size
    if (n < 2) {
      this.vx = 0
      this.vy = 0
      this.vs = 0
      return
    }
    const lastTs = this.at(n - 1).ts
    const windowStart = lastTs - VELOCITY_FIT_WINDOW_NS
    let start = n - 1
    while (start > 0 && this.at(start - 1).ts >= windowStart) {
      start--
    }
    if (start == n - 1) {
      start = n - 2
    }
    const span = lastTs - this.at(start).ts
    if (span < MIN_VELOCITY_FIT_SPAN_NS) {
      this.vx = 0
      this.vy = 0
      this.vs = 0
      return
    }
    let st = 0
    let sx = 0
    let sy = 0
    let ss = 0
    let stt = 0
    let stx = 0
    let sty = 0
    let sts = 0
    for (let i = start; i < n; i++) {
      const s = this.at(i)
      const t = (s.ts - lastTs) / span // 归一化到[-1,0]，避免大数相减损失精度
      st += t
      sx += s.x
      sy += s.y
      ss += s.scale
      stt += t * t
      stx += t * s.x
      sty += t * s.y
      sts += t * s.scale
    }
    const cnt = n - start
    const denom = cnt * stt - st * st
    if (denom < 1e-6) {
      this.vx = 0
      this.vy = 0
      this.vs = 0
      return
    }
    this.vx = (cnt * stx - st * sx) / denom / span
    this.vy = (cnt * sty - st * sy) / denom / span
    this.vs = (cnt * sts - st * ss) / denom / span
  }

  /**
   * 求 t（手势时钟）时刻的信号值：区间内线性插值；越过最新采样后按拟合速度外推，
   * 外推量随采样停更（手指悬停时就是完全没有新采样的）逐步收回，避免残留预测偏移
   */
  evaluate(t: number, out: SignalValue) {
    const n = this.size
    if (n == 0) {
      return
    }
    const last = this.at(n - 1)
    if (t >= last.ts) {
      const dt = t - last.ts
      let extrapolate = 0
      if (dt <= FULL_PREDICTION_NS) {
        extrapolate = dt
      } else if (dt < STALE_EXTRAPOLATE_NS) {
        extrapolate = dt * (STALE_EXTRAPOLATE_NS - dt) / (STALE_EXTRAPOLATE_NS - FULL_PREDICTION_NS)
      }
      out.x = last.x + this.vx * extrapolate
      out.y = last.y + this.vy * extrapolate
      out.scale = last.scale + this.vs * extrapolate
      return
    }
    for (let i = n - 1; i > 0; i--) {
      const b = this.at(i)
      if (t >= b.ts) {
        continue
      }
      const a = this.at(i - 1)
      if (t >= a.ts) {
        const span = b.ts - a.ts
        const k = span > 0 ? (t - a.ts) / span : 1
        out.x = a.x + (b.x - a.x) * k
        out.y = a.y + (b.y - a.y) * k
        out.scale = a.scale + (b.scale - a.scale) * k
        return
      }
    }
    const first = this.at(0)
    out.x = first.x
    out.y = first.y
    out.scale = first.scale
  }
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
  dismissDragging: boolean = false
  @State exiting: boolean = false // 退场进行中：防重入并屏蔽手势
  @State imgLoaded: boolean[] = []
  @State imgLoadFailed: boolean[] = []
  @State showButton: boolean = true
  @State imgContainerSizeState: RectSize = imgContainerSize // 用于旋屏后刷新图片大小
  @State bgOpacity: number = 1
  @State imgOpacity: number = 1 // 非对齐退场时图片层淡出
  enterPending: boolean = false // 入场飞入待执行（等图片尺寸就绪）

  signal: GestureSignal = new GestureSignal()
  signalValue: SignalValue = new SignalValue()
  panning: boolean = false
  pinching: boolean = false
  flinging: boolean = false
  loopRunning: boolean = false
  lastFrameTs: number = 0
  frameIntervalNs: number = 0
  panBaseX: number = 0
  panBaseY: number = 0
  flingVx: number = 0
  flingVy: number = 0
  flingFriction: number = MAX_FRICTION
  smoothX: number = 0 // 施加到变换上的输出值（一阶低通的当前状态）
  smoothY: number = 0
  smoothScale: number = 1
  hasApplied: boolean = false

  aboutToAppear(): void {
    this.targetSwiperIndex = this.swiperIndex = this.param.startAt
    this.dataSource.setPageCount(this.param.urls.length)
    for (let i = 0; i < this.param.urls.length; i++) {
      this.imgTransform[i] = new matrixHelper()
      this.imgMatrix[i] = matrix4.identity()
    }
    this.imgCount = this.param.urls.length
    SetStatusBarColor(this.context, themeColorDark)
    activeExitHandler = (): void => this.beginExit()
    // 入场飞入：仅在点击ImageContainer打开（锚点数据有效）时进行
    this.enterPending = consumeImageViewerTransitionValid() &&
      ImageViewerTransitionToSize.w > 0 && ImageViewerTransitionToSize.h > 0
  }

  aboutToDisappear(): void {
    activeExitHandler = null
    this.haltGesture()
    this.showStatusBar()
  }

  showUpChanged() {
    if (this.showUp === false && this.imgCount > 0) {
      SetStatusBarColor(this.context, this.appTheme)
      this.showStatusBar()
    }
  }

  /**
   * 退场动画全部自控（bindContentCover 为 IDENTITY，关闭时无系统转场）：
   * 入场那张图对齐缩略图（图片本体不淡出），
   * 其余图片居中缩至0.65并淡出；动画结束后关闭。图片未就绪则直接关闭
   */
  beginExit() {
    if (this.exiting) {
      return
    }
    this.exiting = true
    this.haltGesture()
    const helper = this.imgTransform[this.swiperIndex]
    const canAlign = this.swiperIndex == this.param.startAt &&
      helper.width > 0 && ImageViewerTransitionToSize.w > 0 && ImageViewerTransitionToSize.h > 0
    if (canAlign) {
      this.playExit(ImageViewerTransitionToSize.w / helper.width,
        ImageViewerTransitionToPos.w + ImageViewerTransitionToSize.w / 2,
        ImageViewerTransitionToPos.h + ImageViewerTransitionToSize.h / 2,
        false)
      return
    }
    if (helper.width > 0) {
      this.playExit(0.65, imgContainerSize.w / 2, imgContainerSize.h / 2, true)
      return
    }
    this.finishExit()
  }

  playExit(targetScale: number, targetCenterX: number, targetCenterY: number, fadeImage: boolean) {
    this.getUIContext()
      .animateTo({
        duration: AniSpeed.ms200,
        onFinish: () => {
          this.finishExit()
        }
      }, () => {
        this.imgTransform[this.swiperIndex].setExitTarget(targetScale, targetCenterX, targetCenterY)
        this.updateImageTransformMatrix()
        if (fadeImage) {
          this.imgOpacity = 0
        }
        this.bgOpacity = 0
        this.showButton = false
      })
  }

  finishExit() {
    if (!this.exiting) {
      return
    }
    this.getUIContext()
      .animateTo(SpringCurve, () => {
        this.showUp = false
      })
  }

  showStatusBar() {
    this.context.eventHub.emit(Event.ShowSystemBars)
  }

  hideStatusBar() {
    this.context.eventHub.emit(Event.HideSystemBars)
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

      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .opacity(this.bgOpacity)

      Swiper() {
        LazyForEach(this.dataSource, (pageIndex: number, compIndex: number) => {
          Stack() {
            if (!this.imgLoaded[compIndex] && !this.imgLoadFailed[compIndex]) {
              LoadingIcon({ iconSize: 64 })
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
                if (compIndex == this.param.startAt && this.enterPending) {
                  this.startEnterFly()
                }
              },
              onFailed: () => {
                this.imgLoadFailed[compIndex] = true
                if (compIndex == this.param.startAt && this.enterPending) {
                  this.enterPending = false
                }
              }
            })
              .transform(this.imgMatrix[compIndex])
          }
          .width('100%')
          .height('100%')
          .onTouch(e => {
            // 触摸即接管：惯性滚动让位给即将到来的手势，位置不再变化
            this.flinging = false
          })
          .gesture(TapGesture({ count: 2, distanceThreshold: 1 }).onAction(e => {
            this.imgTransform[this.swiperIndex].onTap(vp2px(e.fingerList[0].localX), vp2px(e.fingerList[0].localY))
            animateTo(SpringCurve, () => {
              this.updateImageTransformMatrix()
            })
          }))
          .gesture(PinchGesture({ distance: 0.1 }).onActionStart(e => {
            this.pinching = true
            this.hasApplied = false
            this.signal.clear()
            this.imgTransform[this.swiperIndex].beginPinch()
            this.startFrameLoop()
          }).onActionUpdate(e => {
            const centerX = vp2px(e.pinchCenterX)
            const centerY = vp2px(e.pinchCenterY)
            if (e.scale > 0 && centerX > 0 && centerY > 0) {
              this.signal.push(e.timestamp, centerX, centerY, e.scale)
            }
          }).onActionEnd(e => {
            this.pinching = false
            this.finishScaleGesture(() => {
              this.imgTransform[this.swiperIndex].endPinch()
            })
          }).onActionCancel(() => {
            this.pinching = false
            this.finishScaleGesture(() => {
              this.imgTransform[this.swiperIndex].endPinch()
            })
          }))
          .gesture(PanGesture({ distance: 0.1 }).onActionStart(e => {
            // 100%缩放态进入垂直拖拽模式
            const helper = this.imgTransform[this.swiperIndex]
            this.dismissDragging = helper.scaleRatio == 1
            this.panning = true
            this.hasApplied = false
            this.panBaseX = helper.X
            this.panBaseY = helper.Y
            this.signal.clear()
            this.startFrameLoop()
          }).onActionUpdate(e => {
            this.signal.push(e.timestamp, vp2px(e.offsetX), vp2px(e.offsetY), 1)
          }).onActionEnd(e => {
            if (this.dismissDragging) {
              this.panning = false
              this.endDismissDrag()
              return
            }
            this.signal.push(e.timestamp, vp2px(e.offsetX), vp2px(e.offsetY), 1)
            this.panning = false
            this.beginFling()
          }).onActionCancel(() => {
            if (this.dismissDragging) {
              this.panning = false
              this.endDismissDrag()
              return
            }
            this.panning = false
          }))
          .onGestureJudgeBegin((gestureInfo: GestureInfo, event: BaseGestureEvent) => {
            if (this.exiting || this.imgLoadFailed[this.swiperIndex]) {
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
      .opacity(this.imgOpacity)
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
          this.beginExit()
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
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms200, curve: Curve.EaseIn }),
      TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms300, curve: Curve.EaseIn })
    ))
  }

  updateImageTransformMatrix() {
    this.imgMatrix[this.swiperIndex] = this.imgTransform[this.swiperIndex].getMat()
    this.updateButtonVisibility()
  }

  startFrameLoop() {
    if (this.loopRunning) {
      return
    }
    this.loopRunning = true
    this.lastFrameTs = 0
    useFrameSync(ts => this.frameTick(ts))
  }

  /** 手势进行中或惯性滚动中逐帧驱动，两者共用同一条循环 */
  haltGesture() {
    this.panning = false
    this.pinching = false
    this.flinging = false
    if (this.loopRunning) {
      this.loopRunning = false
      offFrameSync()
    }
  }

  frameTick(ts: number): boolean {
    const dtNs = this.lastFrameTs > 0 ? ts - this.lastFrameTs : 0
    this.lastFrameTs = ts
    if (dtNs > 0 && dtNs < 100_000_000) {
      this.frameIntervalNs = this.frameIntervalNs > 0
        ? this.frameIntervalNs + (dtNs - this.frameIntervalNs) * FRAME_INTERVAL_ALPHA
        : dtNs
    }
    const helper = this.imgTransform[this.swiperIndex]
    if (this.panning || this.pinching) {
      this.consumeGestureFrame(helper, ts)
      return true
    }
    if (this.flinging && this.stepFling(helper, dtNs)) {
      this.updateImageTransformMatrix()
      return true
    }
    this.flinging = false
    this.loopRunning = false
    return false
  }

  /**
   * 消费采样：消费时刻 = 对齐后的帧时间 + 一帧提前量（补偿输入/上屏延迟），
   * 采样稀疏时按拟合速度外推，采样密集时线性插值；
   * 结果再经一级帧率无关的一阶低通后才施加，用来抹掉外推尖峰（急停过冲）与采样抖动
   */
  consumeGestureFrame(helper: matrixHelper, ts: number) {
    if (this.signal.count() == 0) {
      return
    }
    this.signal.updateVelocity()
    const lead = Math.min(this.frameIntervalNs, MAX_PREDICTION_LEAD_NS)
    this.signal.evaluate(this.signal.consumeTime(ts, lead), this.signalValue)
    const v = this.signalValue
    if (!this.hasApplied) { // 手势起始帧直接落位，避免从上一手势的旧值平滑过去
      this.hasApplied = true
      this.smoothX = v.x
      this.smoothY = v.y
      this.smoothScale = v.scale
    } else {
      const alpha = 1 - Math.exp(-this.frameIntervalNs / SMOOTH_TAU_NS)
      const dx = (v.x - this.smoothX) * alpha
      const dy = (v.y - this.smoothY) * alpha
      const ds = (v.scale - this.smoothScale) * alpha
      if (Math.abs(dx) < APPLY_POS_EPSILON_PX && Math.abs(dy) < APPLY_POS_EPSILON_PX &&
        Math.abs(ds) < APPLY_SCALE_EPSILON) {
        return // 本帧平滑增量可忽略，省掉一次重绘
      }
      this.smoothX += dx
      this.smoothY += dy
      this.smoothScale += ds
    }
    if (this.pinching) {
      helper.applyPinch(this.smoothScale, this.smoothX, this.smoothY)
    } else if (this.dismissDragging) {
      helper.applyDismissDrag(this.smoothX, this.smoothY)
    } else {
      helper.applyPan(this.panBaseX, this.panBaseY, this.smoothX, this.smoothY)
    }
    if (this.pinching || this.dismissDragging) {
      this.bgOpacity = Math.min(1, Math.max(0, helper.scaleRatio))
    }
    this.updateImageTransformMatrix()
  }

  /** 直接沿用拖拽末速度（位移速度换算到图片平移空间），惯性滚动与拖拽无缝衔接 */
  beginFling() {
    const helper = this.imgTransform[this.swiperIndex]
    const dragVp = px2vp(this.signal.pauseDistance())
    if (dragVp < MIN_FLING_DRAG_VP) {
      // 极短手势（多用于在惯性滚动中反手轻点刹车）的位移与采样噪声同量级，
      // 拟合出的速度方向和大小都不可信，直接不产生惯性：把原有的惯性刹住即可
      this.flinging = false
      return
    }
    this.signal.updateVelocity()
    this.flingVx = this.signal.velocityX() / helper.scaleRatio
    this.flingVy = this.signal.velocityY() / helper.scaleRatio
    const t = Math.min(1, Math.max(0,
      (dragVp - SHORT_DRAG_DISTANCE_CLAMP) / (LONG_DRAG_DISTANCE_CLAMP - SHORT_DRAG_DISTANCE_CLAMP)))
    // 距离越短摩擦越大
    this.flingFriction = MAX_FRICTION + t * (MIN_FRICTION - MAX_FRICTION)
    this.flinging = true
  }

  /** 常摩擦力的指数衰减，按帧积分（每帧位移为精确解），便于随时被新输入接管 */
  stepFling(helper: matrixHelper, dtNs: number): boolean {
    if (dtNs <= 0) {
      return true
    }
    if (Math.hypot(this.flingVx, this.flingVy) < STOP_FLING_VEL) {
      return false
    }
    const decay = Math.exp(-this.flingFriction * dtNs / 1e9)
    const displacementFactor = (1 - decay) / this.flingFriction
    helper.moveBy(this.flingVx * 1e9 * displacementFactor, this.flingVy * 1e9 * displacementFactor)
    this.flingVx *= decay
    this.flingVy *= decay
    return true
  }

  startEnterFly() {
    this.enterPending = false
    const helper = this.imgTransform[this.param.startAt]
    const targetScale = ImageViewerTransitionToSize.w / helper.width
    const centerX = ImageViewerTransitionToPos.w + ImageViewerTransitionToSize.w / 2
    const centerY = ImageViewerTransitionToPos.h + ImageViewerTransitionToSize.h / 2
    helper.setExitTarget(targetScale, centerX, centerY)
    this.updateImageTransformMatrix()
    this.getUIContext()
      .animateTo(SpringCurve, () => {
        helper.reset()
        this.updateImageTransformMatrix()
      })
  }

  finishScaleGesture(restore: () => void) {
    const helper = this.imgTransform[this.swiperIndex]
    if (helper.scaleRatio < EXIT_PINCH_SCALE_THRESHOLD) {
      this.beginExit()
      return
    }
    animateTo(SpringCurve, () => {
      this.bgOpacity = 1
      restore()
      this.updateImageTransformMatrix()
    })
  }

  endDismissDrag() {
    if (!this.dismissDragging) {
      return
    }
    this.dismissDragging = false
    this.finishScaleGesture(() => {
      this.imgTransform[this.swiperIndex].reset()
    })
  }

  updateButtonVisibility() {
    if (this.exiting) {
      return
    }
    if (this.imgTransform[this.targetSwiperIndex].scaleRatio == 1 && this.showButton == false) {
      this.showStatusBar()
      animateTo(SpringCurve, () => {
        this.showButton = true
      })
    }
    if (this.imgTransform[this.targetSwiperIndex].scaleRatio > 1 && this.showButton == true) {
      this.hideStatusBar()
      animateTo({
        curve: curves.springMotion(0.35)
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
  X: number = 0
  Y: number = 0
  scaleRatio: number = 1
  width: number = 0
  height: number = 0
  private fitScale: number = 1
  private pinchBaseScale: number = 1
  private pinchImgX: number = 0 // 捏合起始时，捏合中心下方的图像坐标
  private pinchImgY: number = 0
  private pinchAnchorValid: boolean = false

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
    this.X = 0
    this.Y = 0
    this.scaleRatio = 1
  }

  /** 退场终态：内容缩放到targetScale，中心平移到缩略图中心(px、窗口坐标) */
  setExitTarget(targetScale: number, targetCenterX: number, targetCenterY: number) {
    this.scaleRatio = targetScale
    this.X = (targetCenterX - imgContainerSize.w / 2) / targetScale
    this.Y = (targetCenterY - imgContainerSize.h / 2) / targetScale
  }

  private limitInScreen() {
    const centerX = imgContainerSize.w / 2 + this.X * this.scaleRatio
    const centerY = imgContainerSize.h / 2 + this.Y * this.scaleRatio
    const scaledW = this.width * this.scaleRatio
    const scaledH = this.height * this.scaleRatio
    const leftTopX = centerX - scaledW / 2
    const leftTopY = centerY - scaledH / 2
    if (scaledW > imgContainerSize.w) {
      const maxX = 0
      const minX = imgContainerSize.w - scaledW
      this.X += (Math.min(Math.max(leftTopX, minX), maxX) - leftTopX) / this.scaleRatio
    } else {
      this.X = 0
    }
    if (scaledH > imgContainerSize.h) {
      const maxY = 0
      const minY = imgContainerSize.h - scaledH
      this.Y += (Math.min(Math.max(leftTopY, minY), maxY) - leftTopY) / this.scaleRatio
    } else {
      this.Y = 0
    }
  }

  getMat(): matrix4.Matrix4Transit {
    return matrix4.identity().translate({
      x: this.X,
      y: this.Y
    }).scale({
      x: this.scaleRatio,
      y: this.scaleRatio,
      // centerX: ,
      // centerY:    // 变换原点默认位于控件中心
    })
  }

  scale(newScale: number, scaleCenterX: number, scaleCenterY: number) { // scaleCenter.XY的数值相对于容器左上角，需要转换到缩放变换中心
    const centerX = imgContainerSize.w / 2 + this.X * this.scaleRatio
    const centerY = imgContainerSize.h / 2 + this.Y * this.scaleRatio
    const dx = centerX - scaleCenterX
    const dy = centerY - scaleCenterY
    this.X = (dx * (newScale - this.scaleRatio) / this.scaleRatio + this.X * this.scaleRatio) / newScale
    this.Y = (dy * (newScale - this.scaleRatio) / this.scaleRatio + this.Y * this.scaleRatio) / newScale
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

  /** 捏合开始：锚点推迟到首个采样到达时记录，那时捏合中心一定有效 */
  beginPinch() {
    this.pinchAnchorValid = false
  }

  /**
   * relativeScale为捏合手势的累计缩放比，center为当前捏合中心（px、容器坐标）；
   * 首次调用记录锚点，此后每次都是相对锚点的闭式解，不累积误差
   */
  applyPinch(relativeScale: number, centerX: number, centerY: number) {
    if (!this.pinchAnchorValid) {
      this.pinchBaseScale = this.scaleRatio
      this.pinchImgX = (centerX - imgContainerSize.w / 2) / this.scaleRatio - this.X
      this.pinchImgY = (centerY - imgContainerSize.h / 2) / this.scaleRatio - this.Y
      this.pinchAnchorValid = true
    }
    const newScale = Math.max(this.pinchBaseScale * relativeScale, 1e-3)
    this.scaleRatio = newScale
    this.X = (centerX - imgContainerSize.w / 2) / newScale - this.pinchImgX
    this.Y = (centerY - imgContainerSize.h / 2) / newScale - this.pinchImgY
  }

  endPinch() {
    this.scaleConstraint()
    this.limitInScreen()
  }

  /** 100%缩放态的拖拽：按距离缩小缩放，位移均跟手 */
  applyDismissDrag(offsetX: number, offsetY: number) {
    const absY = Math.abs(offsetY);
    // 指数非线性：近距离scale衰减极慢，超过阈值后快速下滑
    const factor = absY / 1200;
    const scaleRaw = 1 - Math.pow(factor, 2.2); // 指数 >1，越大越晚开始衰减
    this.scaleRatio = Math.max(0.8, scaleRaw);
    this.X = offsetX / this.scaleRatio;
    this.Y = offsetY / this.scaleRatio;
  }

  /** 拖拽位移始终相对手势起点的基准值求解，限位不会累积成漂移 */
  applyPan(baseX: number, baseY: number, offsetX: number, offsetY: number) {
    this.X = baseX + offsetX / this.scaleRatio
    this.Y = baseY + offsetY / this.scaleRatio
    this.limitInScreen()
  }

  moveBy(dx: number, dy: number) {
    this.X += dx
    this.Y += dy
    this.limitInScreen()
  }

  /**
   *
   * @param directionX 手势是否沿X轴正向
   * @returns true，当图片的滑动手势需要优先响应（而不是swiper的左右切换）
   */
  selfScrollFirst(directionX: boolean) {
    const centerX = imgContainerSize.w / 2 + this.X * this.scaleRatio
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
    brightness: 0.75,
    radius: 12,
  })
  .border({
    width: 1,
    color: 'rgba(255, 255, 255, 0.2)'
  })
}