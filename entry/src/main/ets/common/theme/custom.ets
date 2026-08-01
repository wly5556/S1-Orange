import { ThemeColorTea } from './tea'

/**
 * 浅色模式下的自定义配色：以浅灰主题为默认值，按用户配置覆盖各颜色字段
 * 未写入的字段保持浅灰主题默认值，保证低版本配置缺失时也能静默补齐
 */
export class ThemeColorCustom extends ThemeColorTea {
  constructor(colors: Record<string, string>) {
    super()
    const pick = (key: string, base: string): string => {
      const value = colors[key]
      return value != undefined && value.length > 0 ? value : base
    }
    this.titleBar = pick('titleBar', this.titleBar as string)
    this.titleBarFont = pick('titleBarFont', this.titleBarFont as string)
    this.themeColorDarken = pick('themeColorDarken', this.themeColorDarken as string)
    this.backgroundPrimary = pick('backgroundPrimary', this.backgroundPrimary as string)
    this.backgroundSecondary = pick('backgroundSecondary', this.backgroundSecondary as string)
    this.backgroundTertiary = pick('backgroundTertiary', this.backgroundTertiary as string)
    this.fontPrimary = pick('fontPrimary', this.fontPrimary as string)
    this.fontSecondary = pick('fontSecondary', this.fontSecondary as string)
    this.fontEmphasize = pick('fontEmphasize', this.fontEmphasize as string)
  }
}
