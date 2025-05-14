import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { AppThemeColor } from '../theme/basic/basic'

@Component
export struct TabBarSelector {
  @Prop index: number = 0
  @Require @Prop names: string[]
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @Prop bgColor:  ResourceColor = "#00000000"
  showIndicator: boolean = false
  onAnimationStart: (index: number, target: number) => void = () => {
  }

  build() {
    Tabs({ barPosition: BarPosition.Start, index: this.index }) {
      ForEach(this.names, (name: string, index: number) => {
        TabContent() {
        }.tabBar(SubTabBarStyle.of(name)
          .labelStyle({
            selectedColor: this.appTheme.fontEmphasize,
            font: {
              size: FontSizeEnum[this.appState.fontSize].vp16
            }
          })
          .indicator({ color: this.showIndicator ? this.appTheme.fontEmphasize : "#00000000" })
        )
      })
    }
    .backgroundColor(this.bgColor)
    .onAnimationStart(this.onAnimationStart)
    .barMode(BarMode.Scrollable)
    .scrollable(false)
    .barHeight(FontSizeEnum[this.appState.fontSize].vp56)
    .height('auto')
  }
}