import { mapColors } from './HTMLColorMap'

const LIGHT_REFERENCE_COLOR = '#ebebeb'
const DARK_REFERENCE_COLOR = '#000000'
const LOW_LIGHTNESS_BIAS = 1.35
const HIGH_LIGHTNESS_BIAS = 1.65
const LOW_BIAS_MAX_HSL_LIGHTNESS = 0.329
const HIGH_BIAS_MIN_HSL_LIGHTNESS = 0.451
const AVOID_HUE_START = 25
const AVOID_HUE_END = 200
const AVOID_CURVE_STRENGTH = 6
const AVOID_CURVE_FLOOR = 0
const AVOID_FULL_PALETTE_VALUE = 1
const AVOID_ZERO_PALETTE_VALUE = 0.4

interface RgbaColor {
  r: number
  g: number
  b: number
  a: number
}

interface OklabColor {
  l: number
  a: number
  b: number
}

interface RgbUnitColor {
  r: number
  g: number
  b: number
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value))
}

function clampByte(value: number): number {
  return Math.min(255, Math.max(0, Math.round(value)))
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value))
}

function toRgbUnit(color: RgbaColor): RgbUnitColor {
  return {
    r: color.r / 255,
    g: color.g / 255,
    b: color.b / 255
  }
}

function normalizeHue(hue: number): number {
  return ((hue % 360) + 360) % 360
}

function hue(color: RgbaColor): number {
  const rgb = toRgbUnit(color)
  const max = Math.max(rgb.r, rgb.g, rgb.b)
  const min = Math.min(rgb.r, rgb.g, rgb.b)
  const delta = max - min
  if (delta == 0) {
    return 0
  }
  let h: number
  if (max == rgb.r) {
    h = 60 * (((rgb.g - rgb.b) / delta) % 6)
  } else if (max == rgb.g) {
    h = 60 * (((rgb.b - rgb.r) / delta) + 2)
  } else {
    h = 60 * (((rgb.r - rgb.g) / delta) + 4)
  }
  return normalizeHue(h)
}

function hslLightness(color: RgbaColor): number {
  const rgb = toRgbUnit(color)
  const max = Math.max(rgb.r, rgb.g, rgb.b)
  const min = Math.min(rgb.r, rgb.g, rgb.b)
  return (max + min) / 2
}

function hsvValue(color: RgbaColor): number {
  const rgb = toRgbUnit(color)
  return Math.max(rgb.r, rgb.g, rgb.b)
}

function darkModeReadabilityBias(color: RgbaColor): number {
  const lightness = hslLightness(color)
  if (lightness <= LOW_BIAS_MAX_HSL_LIGHTNESS) {
    return LOW_LIGHTNESS_BIAS
  }
  if (lightness >= HIGH_BIAS_MIN_HSL_LIGHTNESS) {
    return HIGH_LIGHTNESS_BIAS
  }
  const progress = (lightness - LOW_BIAS_MAX_HSL_LIGHTNESS) /
    (HIGH_BIAS_MIN_HSL_LIGHTNESS - LOW_BIAS_MAX_HSL_LIGHTNESS)
  return LOW_LIGHTNESS_BIAS + (HIGH_LIGHTNESS_BIAS - LOW_LIGHTNESS_BIAS) * progress
}

function arcProgress(colorHue: number, startHue: number, endHue: number): number | undefined {
  const normalizedStartHue = normalizeHue(startHue)
  const normalizedEndHue = normalizeHue(endHue)
  const span = (normalizedEndHue - normalizedStartHue + 360) % 360 || 360
  const offset = (normalizeHue(colorHue) - normalizedStartHue + 360) % 360
  if (offset > span) {
    return undefined
  }
  return offset / span
}

function bathtubHueFactor(colorHue: number): number {
  const progress = arcProgress(colorHue, AVOID_HUE_START, AVOID_HUE_END)
  if (progress == undefined) {
    return 1
  }
  const centerDistance = Math.abs(progress - 0.5) / 0.5
  const curved = Math.pow(clamp(centerDistance, 0, 1), AVOID_CURVE_STRENGTH)
  return AVOID_CURVE_FLOOR + (1 - AVOID_CURVE_FLOOR) * curved
}

function avoidEffectStrengthByPaletteValue(paletteValue: number): number {
  const high = Math.max(AVOID_FULL_PALETTE_VALUE, AVOID_ZERO_PALETTE_VALUE)
  const low = Math.min(AVOID_FULL_PALETTE_VALUE, AVOID_ZERO_PALETTE_VALUE)
  if (paletteValue >= high) {
    return 1
  }
  if (paletteValue <= low) {
    return 0
  }
  return (paletteValue - low) / (high - low)
}

function parseColor(input: string): RgbaColor | undefined {
  const normalized = mapColors(input).trim()
  if (!normalized.startsWith('#')) {
    return undefined
  }
  if (normalized.length == 7) {
    return {
      r: parseInt(normalized.slice(1, 3), 16),
      g: parseInt(normalized.slice(3, 5), 16),
      b: parseInt(normalized.slice(5, 7), 16),
      a: 255
    }
  }
  if (normalized.length == 9) {
    return {
      a: parseInt(normalized.slice(1, 3), 16),
      r: parseInt(normalized.slice(3, 5), 16),
      g: parseInt(normalized.slice(5, 7), 16),
      b: parseInt(normalized.slice(7, 9), 16)
    }
  }
  return undefined
}

function serializeColor(color: RgbaColor): string {
  const r = clampByte(color.r).toString(16).padStart(2, '0')
  const g = clampByte(color.g).toString(16).padStart(2, '0')
  const b = clampByte(color.b).toString(16).padStart(2, '0')
  if (clampByte(color.a) == 255) {
    return `#${r}${g}${b}`
  }
  const a = clampByte(color.a).toString(16).padStart(2, '0')
  return `#${a}${r}${g}${b}`
}

function srgbChannelToLinear(value: number): number {
  const channel = value / 255
  if (channel <= 0.04045) {
    return channel / 12.92
  }
  return ((channel + 0.055) / 1.055) ** 2.4
}

function linearChannelToSrgb(value: number): number {
  if (value <= 0.0031308) {
    return value * 12.92 * 255
  }
  return (1.055 * value ** (1 / 2.4) - 0.055) * 255
}

function rgbaToOklab(color: RgbaColor): OklabColor {
  const r = srgbChannelToLinear(color.r)
  const g = srgbChannelToLinear(color.g)
  const b = srgbChannelToLinear(color.b)
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
  return {
    l: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
  }
}

function oklabToLinearRgb(color: OklabColor): RgbaColor {
  const l = color.l + 0.3963377774 * color.a + 0.2158037573 * color.b
  const m = color.l - 0.1055613458 * color.a - 0.0638541728 * color.b
  const s = color.l - 0.0894841775 * color.a - 1.2914855480 * color.b
  const l3 = l * l * l
  const m3 = m * m * m
  const s3 = s * s * s
  return {
    r: 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
    g: -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
    b: -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3,
    a: 255
  }
}

function isLinearRgbInGamut(color: RgbaColor): boolean {
  return color.r >= 0 && color.r <= 1 && color.g >= 0 && color.g <= 1 && color.b >= 0 && color.b <= 1
}

function linearRgbToRgba(color: RgbaColor, alpha: number): RgbaColor {
  return {
    r: clampByte(linearChannelToSrgb(color.r)),
    g: clampByte(linearChannelToSrgb(color.g)),
    b: clampByte(linearChannelToSrgb(color.b)),
    a: alpha
  }
}

function fitOklabToSrgb(lab: OklabColor): RgbaColor {
  const direct = oklabToLinearRgb(lab)
  if (isLinearRgbInGamut(direct)) {
    return linearRgbToRgba(direct, 255)
  }
  let low = 0
  let high = 1
  let best = linearRgbToRgba(oklabToLinearRgb({ l: lab.l, a: 0, b: 0 }), 255)
  for (let i = 0; i < 22; i++) {
    const mid = (low + high) / 2
    const next = oklabToLinearRgb({
      l: lab.l,
      a: lab.a * mid,
      b: lab.b * mid
    })
    if (isLinearRgbInGamut(next)) {
      best = linearRgbToRgba(next, 255)
      low = mid
    } else {
      high = mid
    }
  }
  return best
}

function getReferenceLab(color: string): OklabColor {
  const parsed = parseColor(color)
  if (!parsed) {
    return {
      l: 0,
      a: 0,
      b: 0
    }
  }
  return rgbaToOklab(parsed)
}

export function adjustTextColorForDarkMode(color: string): string {
  const parsed = parseColor(color)
  if (!parsed) {
    return color
  }
  const sourceLab = rgbaToOklab(parsed)
  const lightRefLab = getReferenceLab(LIGHT_REFERENCE_COLOR)
  const darkRefLab = getReferenceLab(DARK_REFERENCE_COLOR)
  const baseBiasTargetLab: OklabColor = {
    l: clamp01(darkRefLab.l + Math.abs(sourceLab.l - lightRefLab.l) * darkModeReadabilityBias(parsed)),
    a: sourceLab.a,
    b: sourceLab.b
  }
  const bathtubMix = bathtubHueFactor(hue(parsed))
  const paletteValueStrength = avoidEffectStrengthByPaletteValue(hsvValue(parsed))
  const effectiveAdjustMix = 1 - (1 - bathtubMix) * paletteValueStrength
  const mixedLab: OklabColor = {
    l: sourceLab.l + (baseBiasTargetLab.l - sourceLab.l) * effectiveAdjustMix,
    a: sourceLab.a + (baseBiasTargetLab.a - sourceLab.a) * effectiveAdjustMix,
    b: sourceLab.b + (baseBiasTargetLab.b - sourceLab.b) * effectiveAdjustMix
  }
  const adjusted = fitOklabToSrgb(mixedLab)
  adjusted.a = parsed.a
  return serializeColor(adjusted)
}
