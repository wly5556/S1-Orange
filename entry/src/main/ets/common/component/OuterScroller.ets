/**
 * OuterScroller
 *
 * minHeight:'100%'的Scroll容器，并提供滚动到边缘时的回调
 *
 * 一般与TitleBar配合使用，同时内层嵌套另一个minHeight:'100%'且NestedScrollMode.PARENT_FIRST的Scroll
 */

@Component
export struct OuterScroller {
  @Builder
  blankBuilder() {
  }

  @BuilderParam contentBuilder: () => void = this.blankBuilder
  scroller: Scroller = new Scroller()
  atTop: boolean = true
  onEnterAndLeaveTop: (atTop: boolean) => void = () => {
  }
  onEnterAndLeaveBottom: (atBottom: boolean) => void = () => {
  }

  reportPos() {
    if (this.scroller.currentOffset().yOffset > 0.001) {
      if (this.atTop) {
        this.atTop = false
        this.onEnterAndLeaveTop(this.atTop)
      }
    } else {
      if (!this.atTop) {
        this.atTop = true
        this.onEnterAndLeaveTop(this.atTop)
      }
    }
    this.onEnterAndLeaveBottom(this.scroller.isAtEnd())
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        this.contentBuilder()
      }.constraintSize({
        minHeight: '100%'
      })
    }
    .onScrollStop(() => this.reportPos())
    .onScrollEdge(() => this.reportPos())
    .edgeEffect(EdgeEffect.None)
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}