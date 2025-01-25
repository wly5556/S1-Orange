import { ThemeIndex } from '../../config/v1/default'
import { ThemeColorLight } from './basic/light'
import { ThemeColorTea } from './tea'
import { ThemeColorAmber } from './amber'
import { ThemeColorBlue } from './blue'
import { ThemeColorGreen } from './green'
import { ThemeColorPurple } from './purple'
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