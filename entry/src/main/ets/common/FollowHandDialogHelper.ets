import { FollowHandDialogMode } from '../config/v1/default'
import { PreferenceState } from '../pages/NavProvider/NavigationPage'
import { splitDisplayActive } from './SplitModeHelper'

/**
 * 跟手弹窗在当前状态下是否生效。
 * 仅双栏模式下启用时，按窗口宽度与当前朝向实时判定是否处于双栏显示。
 */
export function followHandDialogActive(appState: PreferenceState): boolean {
  if (appState.followHandDialog == FollowHandDialogMode.never) {
    return false
  }
  if (appState.followHandDialog == FollowHandDialogMode.always) {
    return true
  }
  return splitDisplayActive(appState.splitModePortrait, appState.splitModeLandscape, appState.splitModeTempOff)
}