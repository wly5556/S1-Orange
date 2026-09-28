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
  subtitle: string = ''

  build() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text(this.title)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Medium)
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
          }
        }.alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.chevron_down'))
          .fillColor($r('sys.color.font_primary'))
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
      .constraintSize({
        minHeight: FontSizeEnum[this.appState.fontSize].vp48
      })
      .padding({
        top: this.subtitle.length > 0 ? 6 : 0,
        bottom: this.subtitle.length > 0 ? 6 : 0
      })
      .onClick(() => {
        animateTo({ duration: AniSpeed.ms120 }, () => {
          this.expand = !this.expand
        })
      })

      if (this.expand) {
        this.contentBuilder()
      }
    }.width('100%')
  }
}