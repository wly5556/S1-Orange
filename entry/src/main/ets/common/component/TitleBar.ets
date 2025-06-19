import { PreferenceState, SideBarLayout } from '../../pages/NavProvider/NavigationPage'
import { AppThemeColor } from '../theme/basic/basic'
import { CopyText } from '../ShareKit'
import { HeavyClickEffect } from '../Animation'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'

export enum TitleBarLeftButtonType {
  BACK,
  SIDEBAR
}

export const TITLE_BAR_MIN_HEIGHT = 56

@Component
export struct TitleBar {
  @Consume sideMenuShow: number
  @State titleTextMaxLine: number = 2
  clickLeftButton: () => void = () => {
  }
  textController: TextController = new TextController()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @Prop titleContent?: string = undefined
  leftButtonType: TitleBarLeftButtonType = TitleBarLeftButtonType.BACK
  useRightMenu: boolean = true
  titleCopyable: boolean = false
  @State private showRightMenu: boolean = false
  menu?: MenuElement[]
  @State transparent: boolean = false

  @Builder
  blankBuilder() {
  }

  @Builder
  titleBarButton(r: Resource, action: () => void = () => {
  }, iconSize: number = 26) {
    Stack() {
      Image(r).width(iconSize).height(iconSize)
        .fillColor(this.appTheme.titleBarFont)
    }.width(50)
    .height(50)
    .clickEffect(HeavyClickEffect)
    .onClick(action)
    .draggable(false)
  }

  @BuilderParam contentBuilder: () => void = this.blankBuilder

  build() {
    Row() {
      if (this.leftButtonType == TitleBarLeftButtonType.SIDEBAR) {
        this.titleBarButton($r('app.media.open_sidebar'), () => this.clickLeftButton())
      } else {
        this.titleBarButton($r('app.media.arrow_left'), () => this.clickLeftButton())
      }
      if (this.titleContent) {
        Text(this.titleContent, { controller: this.textController })
          .constraintSize({
            minHeight: 50
          })
          .maxLines(this.titleTextMaxLine)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .minFontSize(FontSizeEnum[this.appState.fontSize].vp18)
          .maxFontSize(FontSizeEnum[this.appState.fontSize].vp22)
          .fontWeight(FontWeight.Medium)
          .heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
          .flexShrink(1)
          .flexGrow(1)
          .padding({ top: 8, bottom: 8 })
          .fontColor(this.appTheme.titleBarFont)
          .onClick(e => {
            if (this.titleTextMaxLine > 2) {
              this.titleTextMaxLine = 2
            } else {
              this.titleTextMaxLine = 4
            }
          })
          .gesture(LongPressGesture().onAction(e => {
            if (!this.titleCopyable) {
              return
            }
            CopyText(this.titleContent || '', '标题已复制')
          }))
      }
      this.contentBuilder()
      if (this.useRightMenu) {
        Stack() {
          this.titleBarButton($r('app.media.dot_grid'), () => {
            this.showRightMenu = true
          }, 30)
        }.bindMenu(this.showRightMenu, this.menu, {
          onDisappear: () => this.showRightMenu = false
        })
      }
    }
    .alignItems(VerticalAlign.Top)
    .backgroundColor(this.transparent ? undefined : this.appTheme.titleBar)
    .width('100%')
    .constraintSize({
      minHeight: TITLE_BAR_MIN_HEIGHT
    })
    .zIndex(100)
    .gesture(PanGesture({ direction: PanDirection.Right, distance: 1 })
      .onActionUpdate(e => {
        this.sideMenuShow = Math.max(0, Math.min(e.offsetX / SideBarLayout.width, 1))
      })
      .onActionEnd(e => {
        if (this.sideMenuShow > 0.5 || e.velocity > 400) {
          this.sideMenuShow = 1
        } else {
          this.sideMenuShow = 0
        }
      })
      .onActionCancel(() => {
        this.sideMenuShow = 0
      })
    )
  }
}