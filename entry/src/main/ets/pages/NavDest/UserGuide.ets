import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { PropKey } from '../../common/Constants'
import { TitleBar } from '../../common/component/TitleBar'
import { openPreferences } from './Preferences'

@Component
export struct UserGuide {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState

  @LocalBuilder
  guidance(image: ResourceStr, title: string, description: string) {
    Column({ space: 6 }) {
      Text(title).fontSize(FontSizeEnum[this.appState.fontSize].vp22)
      Text(description).fontSize(FontSizeEnum[this.appState.fontSize].vp16).opacity(.8)
      Image(image).width('80%').borderRadius(12).alignSelf(ItemAlign.Center)
    }
    .padding(12)
    .borderRadius(12)
    .backgroundColor(this.appTheme.backgroundPrimary)
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 32, left:12, right: 12 })
    .alignSelf(ItemAlign.Stretch)
  }

  build() {
    NavDestination() {
      Column() {
        TitleBar({
          titleContent: '使用手册',
          useRightMenu: false,
          clickLeftButton: () => {
            this.pathStack.pop()
          }
        })
        Scroll() {
          Column() {
            Text('可在“关于”页面内重新进入本页面').opacity(.8).margin(12).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            Row() {
              Text('也可前往').opacity(.8).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              Button({ buttonStyle: ButtonStyleMode.NORMAL }) {
                Text('设置').fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              }.padding(8).onClick(() => {
                openPreferences(this.pathStack)
              })
              Text('了解可以调整的功能选项').opacity(.8).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            }.margin(12)
            this.guidance($rawfile('userGuide/sidemenu.webp'), '抽屉菜单', '抽屉菜单提供了账号管理功能，及收藏、历史记录等页面的入口。\n可以通过在标题栏上“向右滑动”来随时打开它。')
            this.guidance($rawfile('userGuide/multi_account.webp'), '多账户', '在抽屉菜单中，点击顶部空白区域可显示多账户相关操作，再次点击空白区域则返回原始菜单。\n未登录时，点击头像可进行登录操作；已登录后，可在多账户菜单中通过“添加账户”按钮登录其它账户，或重新登录现有账户。')
            this.guidance($rawfile('userGuide/post_menu.webp'), '回帖操作', '点击楼层号，可显示回帖操作菜单。长按用户头像，可屏蔽该用户。')
            this.guidance($rawfile('userGuide/longpress.webp'), '长按', '在论坛页面，长按主题帖标题（而不是点击）将直接跳转到帖子的最新一页。\n在多账户菜单中，长按未使用的账户可以删除账户。\n在收藏页面中，长按主题帖标题可以将其从收藏中移除。')
            BottomSafeArea()
          }.constraintSize({
            minHeight: '100%'
          })
        }.flexGrow(1)
        .flexShrink(1)
      }
      .width('100%')
      .height('100%')
    }.hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}

@Builder
export function RegisterBuilder() {
  UserGuide()
}

export function openUserGuide(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.UserGuide)
}
