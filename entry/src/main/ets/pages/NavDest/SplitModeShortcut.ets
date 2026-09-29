import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { promptAction } from '@kit.ArkUI'
import { openHistoryPage } from './ViewHistory'
import { openFavoriteList } from './FavoriteList'
import { PropKey } from '../../common/Constants'

@Component
export struct SplitModeShortcut {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState

  @LocalBuilder
  shortcut(img: ResourceStr, text: string, onClick: VoidCallback) {
    Button({ buttonStyle: ButtonStyleMode.NORMAL }) {
      Row({space: 12}) {
        Image(img).width(FontSizeEnum[this.appState.fontSize].vp20).height(FontSizeEnum[this.appState.fontSize].vp20).fillColor(this.appTheme.fontSecondary)
        Text(text).fontSize(FontSizeEnum[this.appState.fontSize].vp16).fontColor(this.appTheme.fontSecondary)
      }
    }.onClick(onClick).padding(8)
  }

  build() {
    NavDestination() {
      Column({ space: 8 }) {
        this.shortcut($r('app.media.share'), '暂时关闭分栏模式', () => {
          this.appState.splitModeTempOff = true
          promptAction.showToast({
            message: '已关闭分栏模式，如需永久关闭，请调整设置页内的选项'
          })
        })
        Blank().height(12)
        this.shortcut($r('app.media.arrow_counterclockwise_clock'), '历史记录', () => {
          openHistoryPage(this.pathStack)
        })
        this.shortcut($r('app.media.star_fill'), '我的收藏', () => {
          openFavoriteList(this.pathStack)
        })
        BottomSafeArea()
      }.width('100%')
      .height('100%')
      .padding(8)
      .alignItems(HorizontalAlign.End)
      .justifyContent(FlexAlign.End)
    }.hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}

@Builder
export function RegisterBuilder() {
  SplitModeShortcut()
}

export function openSplitModeShortcut(pathStack: NavPathStack) {
  if (pathStack.size() == 0) {
    openOrJumpTo(pathStack, PageNameEnum.SplitModeShortcut, undefined, false)
  }
}
