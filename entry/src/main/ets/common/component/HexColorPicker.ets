import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { AppThemeColor } from '../theme/basic/basic'
import { HSLSlider } from './HSLSlider'

export function hexToRgb(hex: string): number[] | undefined {
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
  // 支持 6 位 RRGGBB 与 8 位 AARRGGBB
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

export function rgbToHex(rgb: number[], alpha: number = 255): string {
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

export function rgbToHsl(rgb: number[]): number[] {
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

export function hslToRgb(h: number, s: number, l: number): number[] {
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

@Component
export struct HslSliderRow {
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @Prop value: number = 0
  @Prop stops: ResourceColor[] = []
  min: number = 0
  max: number = 100
  label: string = ''
  onChange: (value: number) => void = () => {
  }

  build() {
    Row({ space: 10 }) {
      Text(this.label)
        .width(4 * FontSizeEnum[this.appState.fontSize].vp16)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
        .fontColor(this.appTheme.fontPrimary)
      HSLSlider({
        value: this.value,
        min: this.min,
        max: this.max,
        stops: this.stops,
        onChange: this.onChange
      }).layoutWeight(1)
      Text(this.value.toFixed(0))
        .width(36)
        .textAlign(TextAlign.End)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
        .fontColor(this.appTheme.fontSecondary)
    }.width('100%')
  }
}