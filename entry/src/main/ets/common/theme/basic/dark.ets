import { AppThemeColor } from './basic';

export class ThemColorDark implements AppThemeColor {
  isDark = true
  titleBar = "#ff000000"
  themeColorDarken = "#ffa5a5a5"
  titleBarFont = '#e5ffffff'

  backgroundPrimary = "#ff191a1c"
  backgroundSecondary = "#ff000000"
  backgroundTertiary = '#ff202224'
  fontPrimary = '#e5ffffff'
  fontSecondary = '#99ffffff'
  fontEmphasize = '#5A8E89'
}

export const themeColorDark = new ThemColorDark()