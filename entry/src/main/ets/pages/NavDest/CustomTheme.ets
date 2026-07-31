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
import { HSLSlider } from '../../common/component/HSLSlider'

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
  new ColorField('titleBar', '标题栏背景', '页面顶部的标题栏底色'),
  new ColorField('titleBarFont', '标题栏文字', '标题栏以及状态栏的文本颜色'),
  new ColorField('fontEmphasize', '主题色', '帖子的回复数量、回帖按钮'),
  new ColorField('themeColorDarken', '主题色加深', '投票标题、评分、边框'),
  new ColorField('backgroundPrimary', '卡片背景色', '浮在上层的卡片类界面的颜色'),
  new ColorField('backgroundSecondary', '阅读背景色', '看帖时视觉占比最大的背景色'),
  new ColorField('backgroundTertiary', '背景色加深', '各楼层之间的分隔色、回帖工具栏底色'),
  // new ColorField('fontPrimary', '主要文字', '标题与正文文字'),
  // new ColorField('fontSecondary', '次要文字', '辅助说明、时间信息')
]

const HUE_STOPS: ResourceColor[] = ['#ff0000', '#ffff00', '#00ff00', '#00ffff', '#0000ff', '#ff00ff', '#ff0000']

interface HSLSliderRowParam {
  label: string
  value: number
  min: number
  max: number
  stops: ResourceColor[]
  onChange: (value: number) => void
}

function hexToRgb(hex: string): number[] | undefined {
  let h = hex.trim()
  if (h.startsWith('#')) {
    h = h.substring(1)
  }
  if (h.length == 3 || h.length == 4) {
    let expanded = ''
    for (let i = 0; i < h.length; i++) {
      expanded += h.charAt(i) + h.charAt(i)
    }
    h = expanded
  }
  // 支持 6 位 RRGGBB 与 8 位 AARRGGBB（主题色为 8 位 ARGB）
  if (h.length != 6 && h.length != 8) {
    return undefined
  }
  // 返回 [r, g, b, a]，a 取值 0-255
  const rgb: number[] = []
  const start = h.length == 8 ? 2 : 0
  for (let i = start; i < start + 6; i += 2) {
    const part = h.substring(i, i + 2)
    for (let j = 0; j < 2; j++) {
      if ('0123456789abcdefABCDEF'.indexOf(part.charAt(j)) < 0) {
        return undefined
      }
    }
    rgb.push(parseInt(part, 16))
  }
  rgb.push(h.length == 8 ? parseInt(h.substring(0, 2), 16) : 255)
  return rgb
}

function rgbToHex(rgb: number[], alpha: number = 255): string {
  // 与项目内置主题色保持一致：8 位 #AARRGGBB
  let result = '#'
  const a = Math.min(255, Math.max(0, alpha))
  result += (a < 16 ? '0' : '') + a.toString(16)
  for (let i = 0; i < 3; i++) {
    const v = rgb[i]
    result += (v < 16 ? '0' : '') + v.toString(16)
  }
  return result
}

function rgbToHsl(rgb: number[]): number[] {
  const r = rgb[0] / 255
  const g = rgb[1] / 255
  const b = rgb[2] / 255
  const max = Math.max(r, g, b)
  const min = Math.min(r, g, b)
  const l = (max + min) / 2
  if (max == min) {
    return [0, 0, l * 100]
  }
  const d = max - min
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
  let h = 0
  if (max == r) {
    h = (g - b) / d + (g < b ? 6 : 0)
  } else if (max == g) {
    h = (b - r) / d + 2
  } else {
    h = (r - g) / d + 4
  }
  return [h * 60, s * 100, l * 100]
}

function hslToRgb(h: number, s: number, l: number): number[] {
  const hn = ((h % 360) + 360) % 360
  const sn = Math.min(1, Math.max(0, s / 100))
  const ln = Math.min(1, Math.max(0, l / 100))
  if (sn == 0) {
    const v = Math.round(ln * 255)
    return [v, v, v]
  }
  const q = ln < 0.5 ? ln * (1 + sn) : ln + sn - ln * sn
  const p = 2 * ln - q
  const hue2rgb = (t0: number): number => {
    let t = t0
    if (t < 0) {
      t += 1
    }
    if (t > 1) {
      t -= 1
    }
    if (t < 1 / 6) {
      return p + (q - p) * 6 * t
    }
    if (t < 1 / 2) {
      return q
    }
    if (t < 2 / 3) {
      return p + (q - p) * (2 / 3 - t) * 6
    }
    return p
  }
  return [
    Math.round(hue2rgb(hn / 360 + 1 / 3) * 255),
    Math.round(hue2rgb(hn / 360) * 255),
    Math.round(hue2rgb(hn / 360 - 1 / 3) * 255)
  ]
}

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
    this.getUIContext().animateTo({ duration: AniSpeed.ms200, curve: Curve.EaseInOut }, () => {
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

  @LocalBuilder
  hslRow($$: HSLSliderRowParam) {
    Row({ space: 10 }) {
      Text($$.label)
        .width(56)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
        .fontColor(this.appTheme.fontPrimary)
      HSLSlider({
        value: $$.value,
        min: $$.min,
        max: $$.max,
        stops: $$.stops,
        onChange: $$.onChange
      }).layoutWeight(1)
      Text($$.value.toFixed(0))
        .width(36)
        .textAlign(TextAlign.End)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
        .fontColor(this.appTheme.fontSecondary)
    }.width('100%')
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
            this.hslRow({
              label: '色相',
              value: this.hue,
              min: 0,
              max: 360,
              stops: HUE_STOPS,
              onChange: (v: number) => {
                this.hue = v
                this.onHSLChanged()
              }
            })

            this.hslRow({
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

            this.hslRow({
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

            this.hslRow({
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
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })

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
                color: this.appTheme.fontPrimary
              })
              .backgroundColor(index == this.selectedIndex ? this.appTheme.backgroundSecondary :
                this.appTheme.backgroundPrimary)
              .animation({ duration: AniSpeed.ms120 })
              .onClick(() => this.selectItem(index))
            }, (field: ColorField) => field.key)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 4, bottom: 24 })
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
