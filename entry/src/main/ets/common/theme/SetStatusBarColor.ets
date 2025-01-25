import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AppThemeColor } from './basic/basic'

export function SetStatusBarColor(context: common.UIAbilityContext, theme: AppThemeColor) {
  window.getLastWindow(context).then((windowClass): void => {
    windowClass.setWindowBackgroundColor(theme.titleBar?.toString())
    windowClass.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: theme.titleBarFont?.toString()
    })
  })
}