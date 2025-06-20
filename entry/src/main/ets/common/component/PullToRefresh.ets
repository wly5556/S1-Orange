import { AniSpeed } from "../Animation"

export enum PullToRefreshStage {
  unactivated,
  pullDownBegin,
  doLoading
}

const panGestureDownThreshold_Y = 20
const panGestureDownThreshold_X = 10
const initialLoadingIconOffsetY = -64
const thresholdDoLoadingOffsetY = 20
const maxPullDownOffsetY = 150

@Component
export struct PullToRefresh {
  @Link stage: PullToRefreshStage
  @Prop @Require enable: boolean
  panGestureBeginX: number = 0
  panGestureBeginY: number = 0
  panGestureMaxOffsetX: number = 0
  panGestureMaxOffsetY: number = 0
  @State loadingIconOffsetY: number = initialLoadingIconOffsetY
  scroller: Scroller = new Scroller()
  useList: boolean = false
  scrollBar: BarState = BarState.Auto

  @Builder
  blankBuilder() {
  }

  @BuilderParam contentBuilder: (scroll?: Scroller) => void = this.blankBuilder

  panGestureFulfilled() {
    return this.loadingIconOffsetY > thresholdDoLoadingOffsetY
  }

  build() {
    Stack() {
      if (this.useList) {
        this.contentBuilder(this.scroller)
      } else {
        Scroll(this.scroller) {
          this.contentBuilder(this.scroller)
        }
        .scrollBar(this.scrollBar)
        .enableScrollInteraction(this.stage != PullToRefreshStage.pullDownBegin)
        .edgeEffect(EdgeEffect.None)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
        .height('100%')
        .width('100%')
      }
      Stack() {
        // CirCle() 的阴影会渲染成矩形，bug还是特性?
        Column()
          .backgroundColor($r('sys.color.comp_background_primary_contrary'))
          .width(48)
          .height(48)
          .borderRadius(24)
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        Image($r('app.media.arrow_clockwise'))
          .width(28)
          .height(28)
          .rotate({ angle: this.loadingIconOffsetY * 5 })
          .scale({
            x: Math.min(1, (this.loadingIconOffsetY - initialLoadingIconOffsetY) /
              (thresholdDoLoadingOffsetY - initialLoadingIconOffsetY)),
            y: Math.min(1, (this.loadingIconOffsetY - initialLoadingIconOffsetY) /
              (thresholdDoLoadingOffsetY - initialLoadingIconOffsetY))
          })
          .opacity(this.stage == PullToRefreshStage.doLoading ? 0 : 1)
          .animation({ duration: AniSpeed.ms120 })
          .fillColor(this.panGestureFulfilled() ? $r('sys.color.ohos_id_color_emphasize') :
            '#99000000')
        LoadingProgress()
          .width(48)
          .height(48)
          .color($r('sys.color.ohos_id_color_emphasize'))
          .opacity(this.stage == PullToRefreshStage.doLoading ? 1 : 0)
          .animation({ duration: AniSpeed.ms120 })
      }
      .translate({
        y: this.stage == PullToRefreshStage.unactivated ?
        initialLoadingIconOffsetY :
        this.loadingIconOffsetY
      })
      .opacity(this.stage == PullToRefreshStage.unactivated ? 0 : 1)
      .animation({ duration: AniSpeed.ms120 })
    }.alignContent(Alignment.Top)
    .onTouch(event => {
      if (!this.enable || event.touches.length == 0) {
        return
      }
      if (this.scroller.currentOffset().yOffset > 0.001) {
        return
      }
      const firstEle = this.scroller.getItemRect(0)
      if (firstEle.x === 0 && firstEle.y === 0 && firstEle.width === 0 && firstEle.height === 0) { // 首元素不在视口中
        // 避免嵌套可滚动表格时后this.scroller.currentOffset()实际获取到表格的滚动位置，导致意外激活下拉刷新
        return
      }
      let windowX = event.touches[0].windowX
      let windowY = event.touches[0].windowY
      if (event.type == TouchType.Down) {
        this.panGestureBeginX = windowX
        this.panGestureBeginY = windowY
      } else if (event.type == TouchType.Move) {
        if (!(this.stage == PullToRefreshStage.pullDownBegin)
          && windowY - this.panGestureBeginY > 0) {
          this.panGestureMaxOffsetX = Math.max(Math.abs(windowX - this.panGestureBeginX), this.panGestureMaxOffsetX)
          this.panGestureMaxOffsetY = Math.max(Math.abs(windowY - this.panGestureBeginY), this.panGestureMaxOffsetY)
          if (this.panGestureMaxOffsetX < panGestureDownThreshold_X
            && this.panGestureMaxOffsetY > panGestureDownThreshold_Y) {
            this.stage = PullToRefreshStage.pullDownBegin
          }
        }
        if (this.stage == PullToRefreshStage.pullDownBegin) {
          this.loadingIconOffsetY =
            initialLoadingIconOffsetY + Math.min(
              windowY - panGestureDownThreshold_Y - this.panGestureBeginY,
              maxPullDownOffsetY)
        }
      } else if (event.type == TouchType.Cancel || event.type == TouchType.Up) {
        this.panGestureMaxOffsetX = this.panGestureMaxOffsetY = 0
        if (this.stage == PullToRefreshStage.pullDownBegin) {
          if (this.panGestureFulfilled()) {
            this.stage = PullToRefreshStage.doLoading
            this.loadingIconOffsetY = thresholdDoLoadingOffsetY
            return
          }
        }
        this.stage = PullToRefreshStage.unactivated
      }
    })
  }
}