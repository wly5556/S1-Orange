import { CustomColors } from '@kit.ArkUI'

export interface AppThemeColor extends CustomColors {
  titleBar: ResourceColor | undefined
  titleBarFont: ResourceColor | undefined
  themeColorDarken: ResourceColor | undefined
  isDark: boolean
}
