import { TitleBar } from '../../common/component/TitleBar'
import { promptAction } from '@kit.ArkUI'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import { PropKey } from '../../common/Constants'
import { AniSpeed } from '../../common/Animation'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PreferenceManager } from '../../config/UserConfig'
import { ThemeColorCustom } from '../../common/theme/custom'
import { Event } from '../../common/Events'
import { hexToRgb, hslToRgb, HslSliderRow, rgbToHex, rgbToHsl } from '../../common/component/HexColorPicker'

class ColorField {
  key: string
  name: string
  desc: string

  constructor(key: string, name: string, desc: string) {
    this.key = key
    this.name = name
    this.desc = desc
  }
}

const COLOR_FIELDS: ColorField[] = [
  new ColorField('backgroundSecondary', '阅读背景色', '看帖时视觉占比最大的背景色'),
  new ColorField('fontEmphasize', '强调色', '回帖按钮、帖子的回复数量的颜色'),
  new ColorField('backgroundPrimary', '卡片背景色', '浮在上层的卡片类界面的颜色'),
  new ColorField('titleBar', '标题栏背景色', '页面顶部的标题栏底色'),
  new ColorField('backgroundTertiary', '页面底色', '各楼层之间的分隔色、回帖工具栏底色'),
  new ColorField('titleBarFont', '标题栏文字色', '标题栏以及状态栏的文本颜色'),
  // new ColorField('themeColorDarken', '主题色加深', '投票标题、评分、边框'),
  // new ColorField('fontPrimary', '主要文字', '标题与正文文字'),
  // new ColorField('fontSecondary', '次要文字', '辅助说明、时间信息')
]

function customThemeHex(theme: AppThemeColor, key: string): string {
  switch (key) {
    case 'titleBar':
      return theme.titleBar as string
    case 'titleBarFont':
      return theme.titleBarFont as string
    case 'themeColorDarken':
      return theme.themeColorDarken as string
    case 'backgroundPrimary':
      return theme.backgroundPrimary as string
    case 'backgroundSecondary':
      return theme.backgroundSecondary as string
    case 'backgroundTertiary':
      return theme.backgroundTertiary as string
    case 'fontPrimary':
      return theme.fontPrimary as string
    case 'fontSecondary':
      return theme.fontSecondary as string
    case 'fontEmphasize':
      return theme.fontEmphasize as string
    default:
      return '#000000'
  }
}

@Component
export struct CustomThemePage {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  context = getContext(this) as common.UIAbilityContext
  @State colorValues: string[] = []
  @State selectedIndex: number = -1
  @State hexText: string = '#ffffff'
  @State hue: number = 0
  @State sat: number = 100
  @State light: number = 50
  @State alpha: number = 100

  aboutToAppear(): void {
    this.reloadValues()
  }

  private reloadValues() {
    PreferenceManager.readonly(conf => {
      const theme = new ThemeColorCustom(conf.custom_theme_colours)
      const values: string[] = []
      COLOR_FIELDS.forEach(f => values.push(customThemeHex(theme, f.key)))
      this.colorValues = values
      if (this.selectedIndex >= 0) {
        this.selectItem(this.selectedIndex)
      }
    })
  }

  private resetToDefault() {
    promptAction.showDialog({
      title: '恢复默认配色',
      message: (this.selectedIndex >= 0
        ? '请选择要恢复的范围'
        : '将恢复全部配色') + '\n\n(如果不希望恢复，点击对话框外，可关闭弹窗)',
      buttons: this.selectedIndex >= 0 ? [
        {
          text: '恢复此项',
          color: $r('sys.color.font_secondary')
        },
        {
          text: '恢复全部',
          color: $r('sys.color.alert')
        }
      ] : [
        {
          text: '恢复全部',
          color: $r('sys.color.alert')
        }
      ]
    }).then(result => {
      if (result.index == 0) {
        if (this.selectedIndex >= 0) {
          this.restoreItem()
        } else {
          this.restoreAll()
        }
      } else if (result.index == 1) {
        this.restoreAll()
      }
    })
  }

  private restoreItem() {
    const idx = this.selectedIndex
    if (idx < 0) {
      return
    }
    const key = COLOR_FIELDS[idx].key
    const defaultHex = customThemeHex(new ThemeColorCustom({} as Record<string, string>), key)
    const next = this.colorValues.slice()
    next[idx] = defaultHex
    this.colorValues = next
    PreferenceManager.modify(conf => {
      conf.custom_theme_colours[key] = defaultHex
    })
    this.selectItem(idx)
    this.context.eventHub.emit(Event.LightModeThemeSwitched)
  }

  private restoreAll() {
    PreferenceManager.modify(conf => {
      conf.custom_theme_colours = {}
    })
    this.reloadValues()
    this.context.eventHub.emit(Event.LightModeThemeSwitched)
  }

  private satStops(): ResourceColor[] {
    return [
      rgbToHex(hslToRgb(this.hue, 0, this.light)),
      rgbToHex(hslToRgb(this.hue, 50, this.light)),
      rgbToHex(hslToRgb(this.hue, 100, this.light))
    ]
  }

  private lightStops(): ResourceColor[] {
    return [
      rgbToHex(hslToRgb(this.hue, this.sat, 0)),
      rgbToHex(hslToRgb(this.hue, this.sat, 50)),
      rgbToHex(hslToRgb(this.hue, this.sat, 100))
    ]
  }

  private alphaStops(): ResourceColor[] {
    const rgb = hslToRgb(this.hue, this.sat, this.light)
    return [
      rgbToHex(rgb, 0),
      rgbToHex(rgb, 255)
    ]
  }

  private selectItem(index: number) {
    const rgba = hexToRgb(this.colorValues[index])
    const hsl = rgba ? rgbToHsl(rgba) : [this.hue, this.sat, this.light]
    const alpha = rgba ? Math.round(rgba[3] / 255 * 100) : this.alpha
    this.getUIContext().animateTo({ duration: AniSpeed.ms120, curve: Curve.EaseOut }, () => {
      this.selectedIndex = index
      this.hexText = this.colorValues[index]
      this.hue = hsl[0]
      this.sat = hsl[1]
      this.light = hsl[2]
      this.alpha = alpha
    })
  }

  private applyHex(hex: string) {
    if (this.selectedIndex < 0) {
      return
    }
    const key = COLOR_FIELDS[this.selectedIndex].key
    const next = this.colorValues.slice()
    next[this.selectedIndex] = hex
    this.colorValues = next
    PreferenceManager.modify(conf => {
      conf.custom_theme_colours[key] = hex
    })
    this.context.eventHub.emit(Event.LightModeThemeSwitched)
  }

  private onHSLChanged() {
    if (this.selectedIndex < 0) {
      return
    }
    const hex = rgbToHex(hslToRgb(this.hue, this.sat, this.light), Math.round(this.alpha / 100 * 255))
    this.hexText = hex
    this.applyHex(hex)
  }

  private onHexInput(text: string) {
    this.hexText = text
    const rgba = hexToRgb(text)
    if (rgba) {
      const hex = rgbToHex(rgba, rgba[3])
      // 值未变化（如点选项目同步到输入框触发的回调）时不写回，避免选中项被改写
      if (this.selectedIndex >= 0 && hex == this.colorValues[this.selectedIndex]) {
        return
      }
      const hsl = rgbToHsl(rgba)
      this.hue = hsl[0]
      this.sat = hsl[1]
      this.light = hsl[2]
      this.alpha = Math.round(rgba[3] / 255 * 100)
      this.applyHex(hex)
    }
  }

  build() {
    NavDestination() {
      Column() {
        TitleBar({
          titleContent: '自定义配色',
          useRightMenu: false,
          clickLeftButton: () => {
            this.pathStack.pop()
          }
        })

        Column({ space: 14 }) {
          Row()
            .width('100%')
            .height(44)
            .borderRadius(12)
            .border({ width: 1, color: this.appTheme.backgroundTertiary })
            .backgroundColor(hexToRgb(this.hexText) ? this.hexText : Color.Transparent)
            .opacity(this.selectedIndex >= 0 ? 1 : 0.4)
            .animation({ duration: AniSpeed.ms200 })

          Row({ space: 10 }) {
            Text('HEX')
              .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              .fontColor(this.appTheme.fontSecondary)
              .opacity(this.selectedIndex >= 0 ? 1 : 0.4)
            TextInput({ text: this.hexText, placeholder: '#RRGGBB' })
              .type(InputType.Normal)
              .maxLength(9)
              .layoutWeight(1)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              .enabled(this.selectedIndex >= 0)
              .opacity(this.selectedIndex >= 0 ? 1 : 0.4)
              .onChange(v => this.onHexInput(v))
            Button('恢复默认')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
              .fontColor($r('sys.color.font_secondary'))
              .onClick(() => this.resetToDefault())
          }.width('100%')
          .animation({ duration: AniSpeed.ms200 })

          Column({ space: 14 }) {
            HslSliderRow({
              label: '色相',
              value: this.hue,
              min: 0,
              max: 360,
              stops: ['#ff0000', '#ffff00', '#00ff00', '#00ffff', '#0000ff', '#ff00ff', '#ff0000'],
              onChange: (v: number) => {
                this.hue = v
                this.onHSLChanged()
              }
            })

            HslSliderRow({
              label: '饱和度',
              value: this.sat,
              min: 0,
              max: 100,
              stops: this.satStops(),
              onChange: (v: number) => {
                this.sat = v
                this.onHSLChanged()
              }
            })

            HslSliderRow({
              label: '亮度',
              value: this.light,
              min: 0,
              max: 100,
              stops: this.lightStops(),
              onChange: (v: number) => {
                this.light = v
                this.onHSLChanged()
              }
            })

            HslSliderRow({
              label: '不透明度',
              value: this.alpha,
              min: 0,
              max: 100,
              stops: this.alphaStops(),
              onChange: (v: number) => {
                this.alpha = v
                this.onHSLChanged()
              }
            })

            if (this.selectedIndex < 0) {
              Text('请选择下方的颜色项目进行修改')
                .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                .fontColor(this.appTheme.fontSecondary)
                .width('100%')
            }
          }
          .enabled(this.selectedIndex >= 0)
          .opacity(this.selectedIndex >= 0 ? 1 : 0.4)
          .animation({ duration: AniSpeed.ms200 })
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: 8,
          bottom: 16
        })

        Scroll() {
          Column({ space: 6 }) {
            ForEach(COLOR_FIELDS, (field: ColorField, index: number) => {
              Row() {
                Column({ space: 2 }) {
                  Text(field.name)
                    .fontSize(this.selectedIndex == index ?
                      FontSizeEnum[this.appState.fontSize].vp20 : FontSizeEnum[this.appState.fontSize].vp16)
                    .fontWeight(this.selectedIndex == index ? FontWeight.Bold : FontWeight.Regular)
                    .fontColor(this.appTheme.fontPrimary)
                    .maxLines(1)
                  Text(field.desc)
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    .fontColor(this.appTheme.fontSecondary)
                    .opacity(0.55)
                    .maxLines(1)
                }
                .flexShrink(1)
                .alignItems(HorizontalAlign.Start)

                Blank()
                Row()
                  .width(56)
                  .height(36)
                  .borderRadius(10)
                  .border({ width: 1, color: this.appTheme.backgroundTertiary })
                  .backgroundColor(this.colorValues[index])
              }
              .width('100%')
              .height(72)
              .borderRadius(14)
              .padding({ left: 14, right: 14 })
              .border({
                width: this.selectedIndex == index ? 1.5 : 0,
                color: this.appTheme.fontSecondary
              })
              .backgroundColor(this.appTheme.backgroundPrimary)
              .shadow(index == this.selectedIndex ? ShadowStyle.OUTER_DEFAULT_SM :
                undefined)
              .animation({ duration: AniSpeed.ms120 })
              .onClick(() => this.selectItem(index))
            }, (field: ColorField) => field.key)
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: 4,
            bottom: 24
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .onBackPressed(() => {
      this.pathStack.pop()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  CustomThemePage()
}

export function openCustomTheme(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.CustomTheme)
}
