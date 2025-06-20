import { PreferenceState } from "../../pages/NavProvider/NavigationPage"
import { FontSizeEnum } from "../fontSize/FontSizeEnum"

@Component
export struct SliderReset {
  @Prop value: number
  @Consume appState: PreferenceState
  resetValue: number = 0
  onChange: (v: number) => void = (v) => {
  }
  min: number = 0
  step: number = 1
  max: number = 2

  build() {
    Row() {
      Slider({
        value: this.value,
        min: this.min,
        step: this.step,
        max: this.max
      }).onChange(v => this.onChange(v)).flexShrink(1)
      Button('重置').buttonStyle(ButtonStyleMode.NORMAL)
        .onClick(() => this.onChange(this.resetValue)).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
    }.width('100%')
  }
}