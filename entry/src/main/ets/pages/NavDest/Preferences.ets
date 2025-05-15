import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { ImageCachePref } from '../../common/component/preference/ImageCachePref'
import { ImageKnife } from '@ohos/imageknife'
import { clearAvatarCache } from '../../common/component/Avatar'
import { AvatarCachePref } from '../../common/component/preference/AvatarCachePref'
import { ThemeSelectPanel } from '../../common/component/preference/ThemeSelect'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PreferenceManager } from '../../config/UserConfig'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { FontSizePref } from '../../common/component/preference/FontSizePref'
import { FontSize, FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import {
  ContentFontSizeOverridePref,
  FontOverrideModeDesc
} from '../../common/component/preference/ContentFontSizeOverridePref'
import { openOrJumpTo } from '../SingletonPage'
import { PageNameEnum } from '../PageNameEnum'
import { defaultApplicationConfig, FontSizeIndex } from '../../config/v1/default'
import { HiddenPostDisplayModeDesc, HiddenPostPref } from '../../common/component/preference/HiddenPostPref'
import { openSplitModeShortcut } from './SplitModeShortcut'
import { PropKey } from '../../common/Constants'
import {
  ApiCacheState,
  CLEAN_UP_CACHE_THRESHOLD,
  clearApiCache,
  getApiCacheState
} from '../../common/dataStore/ApiCacheData'
import { PostSignature } from '../../common/PostSignature'
import { OpacityTransition } from '../../common/Animation'
import { FoldMenu } from '../../common/component/FoldMenu'
import BuildProfile from 'BuildProfile'
import { LengthUnit } from '@ohos.arkui.node'

export interface PreferenceParam {}

const SettingColumnSpace = 8

@Component
export struct PreferencePage {
  context = getContext(this) as common.UIAbilityContext
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @State pageParam: PreferenceParam = {}
  @State imageCacheUsage: number = 0
  @Consume @Watch('appStateChanged') appState: PreferenceState
  @State settingRow: SettingRow = new SettingRow(FontSizeEnum[this.appState.fontSize])
  @StorageProp(PropKey.currentColorMode) currentColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  @State textSecondary: TextSecondary = new TextSecondary(this.appState.fontSize)
  @State darkModeFollowSys: boolean = defaultApplicationConfig.dark_mode_follow_system
  @State showTopThread: boolean = defaultApplicationConfig.show_top_thread
  @State postSignature: boolean = defaultApplicationConfig.post_signature
  @State postSignatureDeviceInfo: boolean = defaultApplicationConfig.post_signature_device_info
  @State apiCacheUsage?: ApiCacheState = undefined
  @State postSignatureDisplayText: string = PostSignature.displayText()

  aboutToAppear(): void {
    this.imageCacheUsage = ImageKnife.getInstance().getFileCache().currentMemory
    getApiCacheState().then(v => this.apiCacheUsage = v)
    PreferenceManager.readonly(conf => {
      this.darkModeFollowSys = conf.dark_mode_follow_system
      this.showTopThread = conf.show_top_thread
      this.postSignature = conf.post_signature
      this.postSignatureDeviceInfo = conf.post_signature_device_info
    })
  }

  appStateChanged() {
    this.settingRow = new SettingRow(FontSizeEnum[this.appState.fontSize])
    this.textSecondary = new TextSecondary(this.appState.fontSize)
  }

  @LocalBuilder
  TextPrimary(text: string) {
    Text(text).fontColor($r('sys.color.font_primary'))
      .fontWeight(FontWeight.Medium)
      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
  }

  @LocalBuilder
  TestColumn() {
    Column()
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: '设置',
          useRightMenu: false,
          clickLeftButton: () => {
            this.pathStack.pop()
          }
        }).backgroundColor(this.appTheme.backgroundSecondary)
        Scroll() {
          Column() {
            SettingGroupHeader({
              text: '主题色',
              fontSizeIndex: this.appState.fontSize
            })
            Column() {
              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('深浅色模式跟随系统切换')
                }.SettingColumn()

                Toggle({ type: ToggleType.Switch, isOn: this.darkModeFollowSys }).onChange(isOn => {
                  PreferenceManager.modify(conf => {
                    this.darkModeFollowSys = isOn
                    conf.dark_mode_follow_system = isOn
                    if (isOn) {
                      this.context.getApplicationContext()
                        .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
                    } else {
                      this.context.getApplicationContext().setColorMode(conf.light_dark_mode_prefer)
                    }
                  })
                })
              }.attributeModifier(this.settingRow)

              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('深色模式')
                }.SettingColumn()

                Toggle({
                  type: ToggleType.Switch,
                  isOn: this.currentColorMode == ConfigurationConstant.ColorMode.COLOR_MODE_DARK
                })
                  .onClick(() => {
                    PreferenceManager.modify(conf => {
                      if (this.currentColorMode == ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
                        conf.light_dark_mode_prefer = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
                      } else {
                        conf.light_dark_mode_prefer = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
                      }
                      this.context.getApplicationContext().setColorMode(conf.light_dark_mode_prefer)
                    })
                  })
              }.attributeModifier(this.settingRow)
              .enabled(!this.darkModeFollowSys)
              .opacity(this.darkModeFollowSys ? 0.6 : 1)
              .animation({ duration: 100 })

              SettingDivider()
              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('浅色模式下的主题配色')
                }.SettingColumn()
              }.attributeModifier(this.settingRow)

              Row() {
                ThemeSelectPanel()
              }.attributeModifier(this.settingRow)
            }.attributeModifier(new RoundPanel(this.appTheme.backgroundPrimary))

            SettingGroupHeader({
              text: '浏览体验',
              fontSizeIndex: this.appState.fontSize
            })
            Column() {
              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('字体大小')
                  FontSizePref()
                }.SettingColumn()
              }.attributeModifier(this.settingRow)

              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('当帖文指定了字体大小')
                  ContentFontSizeOverridePref()
                  Text(FontOverrideModeDesc[this.appState.fontSizeOverride]).attributeModifier(this.textSecondary)
                }.SettingColumn()

              }.attributeModifier(this.settingRow)

              SettingDivider()

              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('宽屏时使用双栏界面')
                  Text('开启后，在宽屏设备上浏览时，将使用左右两侧分栏显示的界面。中心分界线可拖动，以调整界面宽度。')
                    .attributeModifier(this.textSecondary)
                }.SettingColumn()

                Toggle({ type: ToggleType.Switch, isOn: this.appState.splitMode }).onChange(isOn => {
                  PreferenceManager.modify(conf => {
                    conf.split_mode = isOn
                    this.appState.splitMode = isOn
                    if (isOn) {
                      openSplitModeShortcut(this.pathStack)
                    }
                  })
                })
              }.attributeModifier(this.settingRow)

              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('帖子可复制')
                }.SettingColumn()

                Toggle({ type: ToggleType.Switch, isOn: this.appState.textCopyable }).onChange(isOn => {
                  PreferenceManager.modify(conf => {
                    conf.post_copyable = isOn
                    this.appState.textCopyable = isOn
                  })
                })
              }.attributeModifier(this.settingRow)

              FoldMenu({
                title: '调整间距'
              }) {
                Row() {
                  Column({ space: SettingColumnSpace }) {
                    this.TextPrimary('主题帖间距')
                    Text(`调整每条主题帖之间的空白大小。默认: ${defaultApplicationConfig.thread_item_gap}单位`)
                      .attributeModifier(this.textSecondary)
                  }.SettingColumn()
                }.attributeModifier(this.settingRow)
                Slider({
                  value: this.appState.threadItemGap,
                  min: 0,
                  max: defaultApplicationConfig.thread_item_gap * 2
                }).onChange(v => {
                  PreferenceManager.modify(conf => {
                    conf.thread_item_gap = v
                    this.appState.threadItemGap = v
                  })
                }).showTips(true, this.appState.threadItemGap.toString())
                Divider()
                Row() {
                  Column({ space: SettingColumnSpace }) {
                    this.TextPrimary('内容文字间距')
                    Text(`调整主题帖标题、内容的两行之间空白大小。默认: ${defaultApplicationConfig.content_line_space}单位`)
                      .attributeModifier(this.textSecondary)
                  }.SettingColumn()
                }.attributeModifier(this.settingRow)
                Slider({
                  value: this.appState.contentLineSpace,
                  min: 0,
                  max: defaultApplicationConfig.content_line_space * 3
                }).onChange(v => {
                  PreferenceManager.modify(conf => {
                    conf.content_line_space = v
                    this.appState.contentLineSpace = v
                  })
                }).showTips(true, this.appState.contentLineSpace.toString())
                Text(`示例文本：欢迎使用${this.context.resourceManager.getStringSync($r('app.string.app_name'))} ${BuildProfile.VERSION_NAME}\n调整内容文本间距\n来获得更符合个人习惯的浏览体验`)
                  .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                  .lineSpacing({
                    value: this.appState.contentLineSpace,
                    unit: LengthUnit.VP
                  })
                  .width('100%')
                  .margin({
                    bottom: 12
                  })
              }
            }.attributeModifier(new RoundPanel(this.appTheme.backgroundPrimary))

            SettingGroupHeader({
              text: '论坛相关',
              fontSizeIndex: this.appState.fontSize
            })
            Column() {
              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('尝试查看不可见内容')
                  HiddenPostPref()
                  Text(HiddenPostDisplayModeDesc[this.appState.hiddenPostDisplay]).attributeModifier(this.textSecondary)
                }.SettingColumn()

              }.attributeModifier(this.settingRow)

              SettingDivider()
              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('显示坛友战斗力')
                }.SettingColumn()

                Toggle({ type: ToggleType.Switch, isOn: this.appState.showCredit }).onChange(isOn => {
                  PreferenceManager.modify(conf => {
                    conf.show_credit = isOn
                    this.appState.showCredit = isOn
                  })
                })
              }.attributeModifier(this.settingRow)

              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('楼层快速导航')
                  Text('浏览回帖时，点击屏幕右侧的楼层号，进行快速跳转').attributeModifier(this.textSecondary)
                }.SettingColumn()

                Toggle({ type: ToggleType.Switch, isOn: this.appState.postAlphabetIndexer }).onChange(isOn => {
                  PreferenceManager.modify(conf => {
                    conf.post_alphabet_indexer = isOn
                    this.appState.postAlphabetIndexer = isOn
                  })
                })
              }.attributeModifier(this.settingRow)

              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('显示论坛置顶帖')
                }.SettingColumn()

                Toggle({ type: ToggleType.Switch, isOn: this.showTopThread }).onChange(isOn => {
                  PreferenceManager.modify(conf => {
                    conf.show_top_thread = isOn
                    this.showTopThread = isOn
                  })
                })
              }.attributeModifier(this.settingRow)

              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('回帖尾巴')
                  Text(this.postSignatureDisplayText).attributeModifier(this.textSecondary).wordBreak(WordBreak.BREAK_ALL)
                }.SettingColumn()

                Toggle({ type: ToggleType.Switch, isOn: this.postSignature }).onChange(isOn => {
                  PreferenceManager.modify(conf => {
                    conf.post_signature = isOn
                    this.postSignature = isOn
                    PostSignature.enable = isOn
                  })
                })
              }.attributeModifier(this.settingRow)

              if (this.postSignature) {
                Row() {
                  Column({ space: SettingColumnSpace }) {
                    this.TextPrimary('尾巴机型显示')
                  }.SettingColumn()

                  Toggle({ type: ToggleType.Switch, isOn: this.postSignatureDeviceInfo }).onChange(isOn => {
                    PreferenceManager.modify(conf => {
                      conf.post_signature_device_info = isOn
                      this.postSignatureDeviceInfo = isOn
                      PostSignature.device = isOn
                      this.postSignatureDisplayText = PostSignature.displayText()
                    })
                  })
                }.attributeModifier(this.settingRow).transition(OpacityTransition)
              }
            }.attributeModifier(new RoundPanel(this.appTheme.backgroundPrimary))

            SettingGroupHeader({
              text: '缓存',
              fontSizeIndex: this.appState.fontSize
            })
            Column() {
              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('图片缓存已使用')
                  Text(`${(this.imageCacheUsage / (1000 * 1000)).toFixed(2)}MB`).attributeModifier(this.textSecondary)
                }.SettingColumn()

                Button('清空')
                  .buttonStyle(ButtonStyleMode.NORMAL)
                  .enabled(this.imageCacheUsage > 0)
                  .opacity(this.imageCacheUsage > 0 ? 1 : 0.7)
                  .onClick(() => {
                    clearAvatarCache()
                    ImageKnife.getInstance()
                      .removeAllFileCache()
                      .then(() => {
                        this.imageCacheUsage =
                          ImageKnife.getInstance().getFileCache().currentMemory
                        this.getUIContext().getPromptAction().showToast({
                          message: '图片缓存已清空'
                        })
                      })
                  })
              }.attributeModifier(this.settingRow)

              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('允许图片缓存占用的存储空间')
                  ImageCachePref()
                }.SettingColumn()
              }.attributeModifier(this.settingRow)

              SettingDivider()
              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('头像缓存有效期')
                  Text('初次加载头像后，在缓存有效期间，不会再次通过网络更新头像').attributeModifier(this.textSecondary)
                  AvatarCachePref()
                }.SettingColumn()
              }.attributeModifier(this.settingRow)

              SettingDivider()
              Row() {
                Column({ space: SettingColumnSpace }) {
                  this.TextPrimary('网络数据缓存已使用')
                  if (this.apiCacheUsage) {
                    Text(`${this.apiCacheUsage.count}/${CLEAN_UP_CACHE_THRESHOLD}项`)
                      .attributeModifier(this.textSecondary)
                  }
                }.SettingColumn()

                if (this.apiCacheUsage) {
                  Button('清空')
                    .buttonStyle(ButtonStyleMode.NORMAL)
                    .enabled(this.apiCacheUsage.count > 0)
                    .opacity(this.apiCacheUsage.count > 0 ? 1 : 0.7)
                    .onClick(() => {
                      clearApiCache()
                        .then(async () => {
                          this.apiCacheUsage = await getApiCacheState()
                          this.getUIContext().getPromptAction().showToast({
                            message: '网络数据缓存已清空'
                          })
                        })
                    })
                }
              }.attributeModifier(this.settingRow)
            }.attributeModifier(new RoundPanel(this.appTheme.backgroundPrimary))

          }
          .padding({
            top: 0,
            bottom: 56,
            left: 16,
            right: 16
          })
          .constraintSize({
            minHeight: '100%'
          })
        }.width('100%')
        .scrollBar(BarState.Off)
        .height('100%')
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
      }
    }.hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.pageParam = context.pathInfo.param as PreferenceParam
    })
  }
}

@Builder
function SettingDivider() {
  Divider().margin({ top: 6, bottom: 6 })
}

@Extend(Column)
function SettingColumn() {
  .flexGrow(1)
  .flexShrink(1)
  .alignItems(HorizontalAlign.Start)
}

@Builder
export function RegisterBuilder() {
  PreferencePage()
}

export class SettingRow implements AttributeModifier<CommonAttribute> {
  fontSize: FontSize

  constructor(fontSize: FontSize) {
    this.fontSize = fontSize
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    instance.constraintSize({
      minHeight: this.fontSize.vp48
    })
      .padding({ top: this.fontSize.vp12, bottom: this.fontSize.vp12 })
      .width('100%')
  }
}

export class RoundPanel implements AttributeModifier<CommonAttribute> {
  color?: ResourceColor

  constructor(color?: ResourceColor) {
    this.color = color
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    instance.width('100%')
      .borderRadius(20)
      .backgroundColor(this.color)
      .padding({
        left: 12,
        right: 12,
        top: 6,
        bottom: 6
      })
  }
}

export interface SettingGroupHeaderParam {
  text: string,
  fontSizeIndex: FontSizeIndex
}

@Builder
export function SettingGroupHeader(param: SettingGroupHeaderParam) {
  Column() {
    Text(param.text)
      .fontSize(FontSizeEnum[param.fontSizeIndex].vp14)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .fontWeight(FontWeight.Medium)
  }.height(56)
  .padding({ right: 12, bottom: 8, left: 12 })
  .justifyContent(FlexAlign.End)
}

export function openPreferences(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.Preferences)
}

class TextSecondary implements AttributeModifier<TextAttribute> {
  private fontSize: FontSizeIndex

  constructor(fontSize: FontSizeIndex) {
    this.fontSize = fontSize
  }

  applyNormalAttribute(instance: TextAttribute): void {
    instance.fontColor($r('sys.color.font_secondary'))
      .fontSize(FontSizeEnum[this.fontSize].vp14)
  }
}