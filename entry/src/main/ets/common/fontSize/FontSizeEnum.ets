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

FontSizeEnum[FontSizeIndex.xs] = {
  ratio: 12 / 16,
  vp12: 8,
  vp13: 9,
  vp14: 10,
  vp15: 11,
  vp16: 12,
  vp18: 14,
  vp20: 16,
  vp22: 18,
  vp24: 20,
  vp28: 24,
  vp32: 28,
  vp36: 31,
  vp40: 34,
  vp48: 40,
  vp56: 44,
}

FontSizeEnum[FontSizeIndex.small] = {
  ratio: 14 / 16,
  vp12: 10,
  vp13: 11,
  vp14: 12,
  vp15: 13,
  vp16: 14,
  vp18: 16,
  vp20: 18,
  vp22: 20,
  vp24: 22,
  vp28: 26,
  vp32: 30,
  vp36: 33,
  vp40: 36,
  vp48: 44,
  vp56: 52
}

FontSizeEnum[FontSizeIndex.medium] = {
  ratio: 16 / 16,
  vp12: 12,
  vp13: 13,
  vp14: 14,
  vp15: 15,
  vp16: 16,
  vp18: 18,
  vp20: 20,
  vp22: 22,
  vp24: 24,
  vp28: 28,
  vp32: 32,
  vp36: 36,
  vp40: 40,
  vp48: 48,
  vp56: 56
}

FontSizeEnum[FontSizeIndex.large] = {
  ratio: 20 / 16,
  vp12: 15,
  vp13: 16,
  vp14: 17,
  vp15: 18,
  vp16: 20,
  vp18: 22,
  vp20: 24,
  vp22: 26,
  vp24: 28,
  vp28: 32,
  vp32: 36,
  vp36: 40,
  vp40: 44,
  vp48: 52,
  vp56: 60
}

FontSizeEnum[FontSizeIndex.xl] = {
  ratio: 24 / 16,
  vp12: 18,
  vp13: 19,
  vp14: 20,
  vp15: 21,
  vp16: 24,
  vp18: 26,
  vp20: 28,
  vp22: 30,
  vp24: 32,
  vp28: 36,
  vp32: 40,
  vp36: 44,
  vp40: 48,
  vp48: 56,
  vp56: 64
}