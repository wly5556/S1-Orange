import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { AniSpeed, HeavyClickEffect } from '../Animation'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { AppThemeColor } from '../theme/basic/basic'

@Component
export struct FoldMenu {
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState

  @Builder
  blankBuilder() {
  }

  @BuilderParam contentBuilder: () => void = this.blankBuilder
  @State expand: boolean = false
  title: string = ''

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Medium)
        Image($r('app.media.chevron_down'))
          .rotate({
            angle: this.expand ? 180 : 0
          })
          .size({
            width: FontSizeEnum[this.appState.fontSize].vp20,
            height: FontSizeEnum[this.appState.fontSize].vp20
          })
      }.justifyContent(FlexAlign.SpaceBetween)
      .clickEffect(HeavyClickEffect)
      .width('100%')
      .height(FontSizeEnum[this.appState.fontSize].vp48)
      .onClick(() => {
        animateTo({ duration: AniSpeed.ms100 }, () => {
          this.expand = !this.expand
        })
      })

      if (this.expand) {
        this.contentBuilder()
      }
    }.width('100%')
  }
}