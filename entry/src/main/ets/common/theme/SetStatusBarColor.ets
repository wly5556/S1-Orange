import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AppThemeColor } from './basic/basic'

export function SetStatusBarColor(context: common.UIAbilityContext, theme: AppThemeColor) {
  window.getLastWindow(context).then((windowClass): void => {
    windowClass.setWindowBackgroundColor(theme.backgroundSecondary?.toString())
    windowClass.setWindowSystemBarProperties({
      statusBarColor: theme.titleBar?.toString(),
      statusBarContentColor: theme.titleBarFont?.toString()
    })
  })
}