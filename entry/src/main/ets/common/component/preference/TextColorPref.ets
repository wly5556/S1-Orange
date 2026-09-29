import { PreferenceManager } from '../../../config/UserConfig'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { AppThemeColor } from '../../theme/basic/basic'
import { themeColorDark } from '../../theme/basic/dark'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'
import { AniSpeed } from '../../Animation'
import { DEFAULT_TEXT_COLOR_DARK, DEFAULT_TEXT_COLOR_LIGHT, PostColorMode } from '../../../config/v1/default'
import { hexToRgb, hslToRgb, HslSliderRow, rgbToHex, rgbToHsl } from '../HexColorPicker'
import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'

/**
 * 主要阅读区当前应使用的文字颜色
 */
export function contentTextColor(appState: PreferenceState, isDark: boolean): string {
  return isDark ? appState.textColorDark : appState.textColorLight
}

const ModeLabel: string[] = ['浅色模式', '深色模式']

const PostColorModeText: string[] = []
PostColorModeText[PostColorMode.showPostColor] = '展示颜色'
PostColorModeText[PostColorMode.ignorePostColor] = '不变色'

export const PostColorModeDesc: string[] = []
PostColorModeDesc[PostColorMode.showPostColor] = ''
PostColorModeDesc[PostColorMode.ignorePostColor] = '总是展示为上方指定的文本颜色'

@Component
export struct TextColorPanel {
  @Consume @Watch('stateChanged') appState: PreferenceState
  @Consume appTheme: AppThemeColor
  @Consume appThemeWhenLightMode: AppThemeColor
  @State selectedMode: number = -1
  @State hexText: string = '#00000000'
  @State hue: number = 0
  @State sat: number = 0
  @State light: number = 0
  @State alpha: number = 100
  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: PostColorModeText.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('postColorModeChanged') postColorModeSelected: PostColorMode[] = []

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.postColorModeSelected.push(conf.post_color_mode)
    })
  }

  stateChanged() {
    this.segmentOption.fontSize = this.segmentOption.selectedFontSize = FontSizeEnum[this.appState.fontSize].vp16
  }

  postColorModeChanged() {
    PreferenceManager.modify(conf => {
      this.postColorModeSelected.forEach(v => {
        conf.post_color_mode = v
        this.appState.postColorMode = v
      })
    })
  }

  private modeColor(mode: number): string {
    return mode == 0 ? this.appState.textColorLight : this.appState.textColorDark
  }

  private modeBackground(mode: number): ResourceColor {
    const background = mode == 1 ? themeColorDark.backgroundSecondary : this.appThemeWhenLightMode.backgroundSecondary
    return background ?? Color.Transparent
  }

  private selectMode(mode: number) {
    const hex = this.modeColor(mode)
    const rgba = hexToRgb(hex)
    const hsl = rgba ? rgbToHsl(rgba) : [this.hue, this.sat, this.light]
    this.getUIContext().animateTo({ duration: AniSpeed.ms120, curve: Curve.EaseOut }, () => {
      this.selectedMode = mode
      this.hexText = hex
      this.hue = hsl[0]
      this.sat = hsl[1]
      this.light = hsl[2]
      this.alpha = rgba ? Math.round(rgba[3] / 255 * 100) : 100
    })
  }

  private applyHex(hex: string) {
    if (this.selectedMode < 0) {
      return
    }
    PreferenceManager.modify(conf => {
      if (this.selectedMode == 0) {
        conf.text_color_light = hex
        this.appState.textColorLight = hex
      } else {
        conf.text_color_dark = hex
        this.appState.textColorDark = hex
      }
    })
  }

  private onHSLChanged() {
    if (this.selectedMode < 0) {
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
      // 值未变化（如进入面板时同步到输入框触发的回调）时不写回
      if (this.selectedMode >= 0 && hex == this.modeColor(this.selectedMode)) {
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

  private resetToDefault() {
    if (this.selectedMode < 0) {
      return
    }
    const hex = this.selectedMode == 0 ? DEFAULT_TEXT_COLOR_LIGHT : DEFAULT_TEXT_COLOR_DARK
    const rgba = hexToRgb(hex)
    this.hexText = hex
    if (rgba) {
      const hsl = rgbToHsl(rgba)
      this.hue = hsl[0]
      this.sat = hsl[1]
      this.light = hsl[2]
      this.alpha = Math.round(rgba[3] / 255 * 100)
    }
    this.applyHex(hex)
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

  @Builder
  modeOption(mode: number) {
    Row() {
      Text(`${ModeLabel[mode]}下\n${this.modeColor(mode)}`)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
        .fontColor(this.appTheme.fontPrimary)
        .textAlign(TextAlign.Start)
        .width('100%')
    }
    .layoutWeight(1)
    .padding(10)
    .borderRadius(12)
    .backgroundColor(this.appTheme.backgroundPrimary)
    .border({
      width: 1.5,
      color: this.selectedMode == mode ? contentTextColor(this.appState, this.appTheme.isDark) : this.appTheme.backgroundTertiary
    })
    .animation({ duration: AniSpeed.ms120 })
    .onClick(() => this.selectMode(mode))
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        this.modeOption(0)
        this.modeOption(1)
      }.width('100%')

      if (this.selectedMode >= 0) {
        Column() {
          Text('文字颜色预览：调整后，主要阅读区域的文字会以该颜色显示，获得更舒服的阅读体验。')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .fontColor(this.modeColor(this.selectedMode))
            .width('100%')
            .animation({ duration: AniSpeed.ms200 })
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor(this.modeBackground(this.selectedMode))

        Row({ space: 10 }) {
          Text('HEX')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .fontColor(this.appTheme.fontSecondary)
          TextInput({ text: this.hexText, placeholder: '#RRGGBB' })
            .type(InputType.Normal)
            .maxLength(9)
            .layoutWeight(1)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .onChange(v => this.onHexInput(v))
          Button('恢复默认')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
            .fontColor($r('sys.color.font_secondary'))
            .onClick(() => this.resetToDefault())
        }.width('100%')

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
        }.width('100%')
      }

      Column({ space: 8 }) {
        Text('当帖文指定了文本颜色')
          .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.appTheme.fontPrimary)
          .width('100%')
        SegmentButton({
          options: this.segmentOption,
          selectedIndexes: $postColorModeSelected
        })
        if (PostColorModeDesc[this.appState.postColorMode].length > 0) {
          Text(PostColorModeDesc[this.appState.postColorMode])
            .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
        }
      }.width('100%')
    }
    .width('100%')
    .padding({ bottom: 12 })
  }
}