const HSL_THUMB_SIZE: number = 28

/**
 * 带内部渐变滑轨的取值滑条，用于直观的颜色输入
 * 滑轨为按 stops 均匀分布的线性渐变，拇指指示当前值；支持点按与拖动
 */
@Component
export struct HSLSlider {
  @Prop value: number = 0
  @Prop stops: ResourceColor[] = []
  min: number = 0
  max: number = 100
  onChange: (value: number) => void = (v: number) => {
  }
  @State trackWidth: number = 0

  private gradientStops(): Array<[ResourceColor, number]> {
    const result: Array<[ResourceColor, number]> = []
    for (let i = 0; i < this.stops.length; i++) {
      const offset: number = this.stops.length > 1 ? i / (this.stops.length - 1) : 0
      result.push([this.stops[i], offset])
    }
    return result
  }

  private thumbX(): number {
    const usable = this.trackWidth - HSL_THUMB_SIZE
    if (usable <= 0) {
      return 0
    }
    const ratio = Math.min(1, Math.max(0, (this.value - this.min) / (this.max - this.min)))
    return ratio * usable
  }

  private updateFromX(x: number) {
    const usable = this.trackWidth - HSL_THUMB_SIZE
    if (usable <= 0) {
      return
    }
    const ratio = Math.min(1, Math.max(0, (x - HSL_THUMB_SIZE / 2) / usable))
    this.onChange(this.min + ratio * (this.max - this.min))
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Column() {
        Row()
          .width('100%')
          .height(8)
          .borderRadius(4)
          .linearGradient({
            angle: 90,
            colors: this.gradientStops()
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)

      Row()
        .width(HSL_THUMB_SIZE)
        .height(HSL_THUMB_SIZE)
        .borderRadius(HSL_THUMB_SIZE / 2)
        .backgroundColor(Color.White)
        .border({ width: 2, color: Color.Gray })
        .shadow({ radius: 6, color: '#33000000', offsetX: 0, offsetY: 1 })
        .position({ x: this.thumbX(), y: 4 })
    }
    .width('100%')
    .height(36)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.trackWidth = newValue.width as number
    })
    .onTouch((event: TouchEvent) => {
      if (event.touches.length > 0) {
        this.updateFromX(event.touches[0].x)
      }
    })
  }
}
