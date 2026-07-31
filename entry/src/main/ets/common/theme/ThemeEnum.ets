import { ThemeIndex } from '../../config/v1/default'
import { ThemeColorLight } from './basic/light'
import { ThemeColorTea } from './tea'
import { ThemeColorAmber } from './amber'
import { ThemeColorBlue } from './blue'
import { ThemeColorGreen } from './green'
import { ThemeColorPurple } from './purple'
import { ThemeColorCustom } from './custom'
import { AppThemeColor } from './basic/basic'

export const ThemeArray: AppThemeColor[] = []
ThemeArray[ThemeIndex.light] = new ThemeColorLight()
ThemeArray[ThemeIndex.tea] = new ThemeColorTea()
ThemeArray[ThemeIndex.amber] = new ThemeColorAmber()
ThemeArray[ThemeIndex.blue] = new ThemeColorBlue()
ThemeArray[ThemeIndex.green] = new ThemeColorGreen()
ThemeArray[ThemeIndex.purple] = new ThemeColorPurple()

export const ThemeName: string[] = []
ThemeName[ThemeIndex.light] = '浅灰'
ThemeName[ThemeIndex.tea] = '红茶'
ThemeName[ThemeIndex.amber] = '琥珀'
ThemeName[ThemeIndex.blue] = '亮蓝'
ThemeName[ThemeIndex.green] = '湖绿'
ThemeName[ThemeIndex.purple] = '深紫'
ThemeName[ThemeIndex.custom] = '自定义配色'

/**
 * 按配置构建浅色模式主题。自定义主题每次都返回新实例，
 * 便于重新赋值 @Provide appTheme 时触发全局刷新
 */
export function themeFromIndex(index: ThemeIndex, customColors: Record<string, string>): AppThemeColor {
  if (index == ThemeIndex.custom) {
    return new ThemeColorCustom(customColors)
  }
  return ThemeArray[index]
}