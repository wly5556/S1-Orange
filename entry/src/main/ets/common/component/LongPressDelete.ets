import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { SpringCurve } from '../Animation'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'

const DELETE_AREA_WIDTH = 70

@Component
export struct LongPressDelete {
  @Consume appState: PreferenceState
  @State deleteButtonShow: boolean = false
  @State doingDelete: boolean = false
  delete: () => void = () => {
  }
  click: () => void = () => {
  }
  transitionId?: string

  @Builder
  blankBuilder() {
  }

  @BuilderParam contentBuilder: (scroll?: Scroller) => void = this.blankBuilder

  build() {
    Row() {
      Row() {
        this.contentBuilder()
      }
      .flexGrow(1)
      .flexShrink(1)
      .enabled(this.deleteButtonShow ? false : true)

      Row() {
        if (this.doingDelete) {
          LoadingProgress()
            .width(FontSizeEnum[this.appState.fontSize].vp32)
            .height(FontSizeEnum[this.appState.fontSize].vp32)
            .color($r('sys.color.ohos_id_color_emphasize'))
        } else {
          Button('删除')
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .fontColor(Color.Red)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .height(FontSizeEnum[this.appState.fontSize].vp32)
        }
      }.width(DELETE_AREA_WIDTH)
      .flexShrink(0)
      .justifyContent(FlexAlign.Center)
      .onClick(e => {
        this.doingDelete = true
        this.delete()
      })
    }
    .geometryTransition(this.transitionId)
    .translate({
      x: this.deleteButtonShow ? -DELETE_AREA_WIDTH : 0
    })
    .width(`calc(100% + ${DELETE_AREA_WIDTH}vp)`)
    .animation(SpringCurve)
    .clickEffect({ level: ClickEffectLevel.HEAVY })
    .onClick(e => {
      if (this.deleteButtonShow) {
        this.deleteButtonShow = false
      } else {
        this.click()
      }
    })
    .gesture(LongPressGesture().onAction(e => {
      this.deleteButtonShow = true
    }))
  }
}