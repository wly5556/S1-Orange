import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AppThemeColor } from './basic/basic'
import { PropKey } from '../Constants'

export function SetStatusBarColor(context: common.UIAbilityContext, theme: AppThemeColor) {
  window.getLastWindow(context).then((windowClass): void => {
    windowClass.setWindowBackgroundColor(theme.titleBar?.toString())
    windowClass.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: theme.titleBarFont?.toString()
    })
  })
}

function setSystemBarsEnabled(context: common.UIAbilityContext, visible: boolean) {
  window.getLastWindow(context).then((windowClass): void => {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      windowClass.setSpecificSystemBarEnabled('status', visible, true)
      windowClass.setSpecificSystemBarEnabled('navigation', visible, true)
      windowClass.setSpecificSystemBarEnabled('navigationIndicator', visible, true)
    }
  })
}

export function ShowSystemBars(context: common.UIAbilityContext) {
  AppStorage.setOrCreate(PropKey.statusBarHiddenByApp, false)
  setSystemBarsEnabled(context, true)
}

export function HideSystemBars(context: common.UIAbilityContext) {
  AppStorage.setOrCreate(PropKey.statusBarHiddenByApp, true)
  setSystemBarsEnabled(context, false)
}