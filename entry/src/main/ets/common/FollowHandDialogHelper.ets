import { PropKey } from './Constants'
import { FollowHandDialogMode } from '../config/v1/default'
import { PreferenceState } from '../pages/NavProvider/NavigationPage'

/**
 * NavigationMode.Auto 的分栏阈值：窗口宽度达到 600vp 时 Navigation 才会双栏显示
 */
const SplitDisplayMinVp = 600

/**
 * 跟手弹窗在当前状态下是否生效。
 * 仅双栏模式下启用时，按窗口宽度实时判定是否处于双栏显示。
 */
export function followHandDialogActive(appState: PreferenceState): boolean {
  if (appState.followHandDialog == FollowHandDialogMode.never) {
    return false
  }
  if (appState.followHandDialog == FollowHandDialogMode.always) {
    return true
  }
  return appState.splitMode && px2vp(AppStorage.get<number>(PropKey.windowWidth) ?? 0) >= SplitDisplayMinVp
}
