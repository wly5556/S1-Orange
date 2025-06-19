/**
 * NavigationPage.ets
 * 应用的Entry组件。Navigation作为基础页面容器，其中：
 * 导航内容（Navigation的子组件）包含“论坛列表页”“主题帖列表页”，位于pages/NavProvider下
 * 非首页显示（NavDestination的子组件）的子页面位于pages/NavDest下
 * 另有侧边栏内容，位于pages/NavProvider/SideMenu.ets
 */
import { ForumInfo } from '../../api/model/forumGroup'
import { AnimationSetUp, AniSpeed, AppearDisappearAni } from '../../common/Animation'
import { ForumGroupView } from './ForumGroup'
import { ThreadListView } from './ThreadList'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { Event } from '../../common/Events'
import { SideMenu } from './SideMenu'
import { LoginDialog } from '../../common/account/LoginDialog'
import { PreferenceManager } from '../../config/UserConfig'
import { ImageKnife } from '@ohos/imageknife'
import { removeExpiredAvatar } from '../../common/component/Avatar'
import { ImageCacheSize } from '../../common/component/preference/ImageCachePref'
import { ThemeArray } from '../../common/theme/ThemeEnum'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { themeColorDark } from '../../common/theme/basic/dark'
import { ThemeColorLight } from '../../common/theme/basic/light'
import { SetStatusBarColor } from '../../common/theme/SetStatusBarColor'
import { openS1LinkLike } from '../../common/WantUitl'
import { defaultApplicationConfig, FontSizeIndex, FontSizeOverride, HiddenPostDisplay } from '../../config/v1/default'
import { PropKey, SafeArea } from '../../common/Constants'
import { openSplitModeShortcut } from '../NavDest/SplitModeShortcut'
import { PageNameEnum } from '../PageNameEnum'
import { GotoThreadDialog } from '../../common/component/GotoThreadDialog'
import { openUserGuide } from '../NavDest/UserGuide'
import { promptAction } from '@kit.ArkUI'
import { PostSignature } from '../../common/PostSignature'

enum NavigationProvider {
  ForumGroupView = 'ForumGroupView',
  ThreadList = 'ThreadList'
}

export enum SideBarLayout {
  width = 280
}

/**
 * 要挂载到NavigationPage中的@Provide appState的配置项
 * 必须在NavigationPage的aboutToAppear中将初始化为实际存储的配置项的值
 * 对其的修改也需要用PreferenceManager.modify来同步到持久化首选项
 */
export interface PreferenceState {
  textCopyable: boolean
  postAlphabetIndexer: boolean
  showCredit: boolean
  fontSize: FontSizeIndex
  fontSizeOverride: FontSizeOverride
  hiddenPostDisplay: HiddenPostDisplay
  splitMode: boolean
  threadItemGap: number
  contentLineSpace: number
}

@Entry
@Component
@Preview
struct NavigationPage {
  context = getContext(this) as common.UIAbilityContext
  @Provide(PropKey.pathStack) pathStack: NavPathStack = new NavPathStack()
  @State navProvider: NavigationProvider = NavigationProvider.ForumGroupView
  @Provide @Watch('onForumInfoUpdate') forumInfo?: ForumInfo = undefined
  @Provide sideMenuShow: number = 0
  @Provide appState: PreferenceState = {
    textCopyable: defaultApplicationConfig.post_copyable,
    postAlphabetIndexer: defaultApplicationConfig.post_alphabet_indexer,
    showCredit: defaultApplicationConfig.show_credit,
    fontSize: defaultApplicationConfig.font_size,
    fontSizeOverride: defaultApplicationConfig.font_size_override,
    hiddenPostDisplay: defaultApplicationConfig.hidden_post_display,
    splitMode: defaultApplicationConfig.split_mode,
    threadItemGap: defaultApplicationConfig.thread_item_gap,
    contentLineSpace: defaultApplicationConfig.content_line_space
  }
  appThemeWhenLightMode: AppThemeColor = new ThemeColorLight()
  @Provide @Watch('updateStatesBarColor') appTheme: AppThemeColor = new ThemeColorLight()
  @StorageProp(PropKey.currentColorMode) @Watch('onColorModeChange') currentMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  @StorageProp(SafeArea.top) topRectHeight: number = 0
  loginDialog: CustomDialogController = new CustomDialogController({
    autoCancel: false,
    alignment: DialogAlignment.Top,
    offset: {
      dx: 0,
      dy: 72
    },
    builder: LoginDialog(),
  })
  gotoThreadDialog: CustomDialogController = new CustomDialogController({
    builder: GotoThreadDialog({ getPathStack: () => this.pathStack }),
  })

  updateStatesBarColor() {
    SetStatusBarColor(this.context, this.appTheme)
  }

  onColorModeChange() {
    if (this.currentMode == ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      this.appTheme = themeColorDark
    } else {
      this.appTheme = this.appThemeWhenLightMode
    }
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.appThemeWhenLightMode = ThemeArray[conf.theme]
      this.appState.textCopyable = conf.post_copyable
      this.appState.postAlphabetIndexer = conf.post_alphabet_indexer
      this.appState.showCredit = conf.show_credit
      this.appState.fontSize = conf.font_size
      this.appState.fontSizeOverride = conf.font_size_override
      this.appState.hiddenPostDisplay = conf.hidden_post_display
      this.appState.splitMode = conf.split_mode
      this.appState.threadItemGap = conf.thread_item_gap
      this.appState.contentLineSpace = conf.content_line_space
      AnimationSetUp(conf.ani_speed_ratio)
      PostSignature.init(conf.post_signature,
        this.context.resourceManager.getStringSync($r('app.string.app_name').id),
        conf.post_signature_device_info)
      if (conf.dark_mode_follow_system) {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
      } else {
        this.context.getApplicationContext().setColorMode(conf.light_dark_mode_prefer)
      }
      if (conf.first_run) {
        PreferenceManager.modify(conf => {
          conf.first_run = false
          openUserGuide(this.pathStack)
          promptAction.showToast({
            message: '初次启动，为您打开使用手册',
            duration: 3000
          })
        })
      }
      this.onColorModeChange()
      ImageKnife.getInstance()
        .initFileCache(this.context, 65536, ImageCacheSize[conf.image_cache_size] * 1024 * 1024)
        .then((): void => removeExpiredAvatar())
    })
    this.context.eventHub.on(Event.OpenLoginDialog, () => {
      this.loginDialog.open()
    })
    this.context.eventHub.on(Event.OpenGotoThreadDialog, () => {
      this.gotoThreadDialog.open()
    })
    this.context.eventHub.on(Event.ReturnToHomePage, () => {
      this.forumInfo = undefined
      this.pathStack.clear()
    })
    this.context.eventHub.on(Event.LightModeThemeSwitched, () => {
      PreferenceManager.readonly(conf => {
        this.appThemeWhenLightMode = ThemeArray[conf.theme]
        this.onColorModeChange()
      })
    })
    this.context.eventHub.on(Event.WantWithUri, (uri: string) => {
      openS1LinkLike(uri, this.pathStack, this.context, '', '1', false)
    })
  }

  build() {
    Stack() {
      Column() {
        Navigation(this.pathStack) {
          if (this.navProvider == NavigationProvider.ForumGroupView) {
            ForumGroupView().transition(AppearDisappearAni)
          } else if (this.navProvider == NavigationProvider.ThreadList) {
            ThreadListView().transition(AppearDisappearAni)
          }
        }
        .onNavigationModeChange(mode => {
          if (mode == NavigationMode.Split) {
            openSplitModeShortcut(this.pathStack)
          } else {
            this.pathStack.removeByName(PageNameEnum.SplitModeShortcut)
          }
        })
        .backgroundColor(this.appTheme.backgroundSecondary)
        .titleMode(NavigationTitleMode.Mini)
        .hideTitleBar(true)
        .hideBackButton(true)
        .navBarWidthRange(['35%', '50%'])
        .navBarWidth(400)
        .mode(this.appState.splitMode ? NavigationMode.Auto : NavigationMode.Stack)
      }
      .offset({ top: 0 })
      .height('100%')
      .width('100%')

      Column() {

      }
      .height('100%')
      .width('100%')
      .backgroundColor(Color.Black)
      .opacity(this.sideMenuShow * 0.4)
      .animation({ duration: AniSpeed.ms120, curve: Curve.EaseIn })
      .onClick(() => this.sideMenuShow = 0)
      .enabled(this.sideMenuShow == 1)

      Column() {
        SideMenu()
      }
      .height('100%')
      .width(SideBarLayout.width)
      .backgroundColor(this.appTheme.backgroundSecondary)
      .offset({ top: 0, left: (this.sideMenuShow - 1) * SideBarLayout.width })
      .animation({ duration: AniSpeed.ms120 })
      .gesture(PanGesture({ direction: PanDirection.Left, distance: 1 })
        .onActionUpdate(e => {
          this.sideMenuShow = Math.min(1, Math.max(1 - (-e.offsetX / SideBarLayout.width), 0))
        })
        .onActionEnd(e => {
          if (this.sideMenuShow < 0.5 || e.velocity > 400) {
            this.sideMenuShow = 0
          } else {
            this.sideMenuShow = 1
          }
        })
        .onActionCancel(() => {
          this.sideMenuShow = 1
        })
      )
    }.alignContent(Alignment.TopStart)
    .margin({ top: px2vp(this.topRectHeight) })
  }

  onForumInfoUpdate() {
    if (this.forumInfo == null) {
      this.navProvider = NavigationProvider.ForumGroupView
    } else {
      this.navProvider = NavigationProvider.ThreadList
    }
  }

  onBackPress(): boolean | void {
    if (this.pathStack.size() > 0 && !(this.appState.splitMode
      && this.pathStack.size() == 1
      && this.pathStack.getAllPathName()[0] == PageNameEnum.SplitModeShortcut)) { // 分栏时有1个垫底的页面
      this.pathStack.pop()
      return true
    } else if (this.navProvider == NavigationProvider.ThreadList) {
      this.forumInfo = undefined
      return true
    }
    return false
  }
}