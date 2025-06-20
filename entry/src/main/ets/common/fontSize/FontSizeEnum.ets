import { FontSizeIndex } from '../../config/v1/default'

export interface FontSize {
  vp12: number
  vp13: number
  vp14: number
  vp15: number
  vp16: number
  vp18: number
  vp20: number
  vp22: number
  vp24: number
  vp28: number
  vp32: number
  vp36: number
  vp40: number
  vp48: number
  vp56: number
  ratio: number
}

export const FontSizeEnum: FontSize[] = []

export function FontSizeSetup(base: number) {
  const ratio: number = base / 16
  FontSizeEnum[base] = {
    ratio: ratio,
    vp12: 12 * ratio,
    vp13: 13 * ratio,
    vp14: 14 * ratio,
    vp15: 15 * ratio,
    vp16: 16 * ratio,
    vp18: 18 * ratio,
    vp20: 20 * ratio,
    vp22: 22 * ratio,
    vp24: 24 * ratio,
    vp28: 28 * ratio,
    vp32: 32 * ratio,
    vp36: 36 * ratio,
    vp40: 40 * ratio,
    vp48: 48 * ratio,
    vp56: 56 * ratio
  }
}

FontSizeSetup(16)