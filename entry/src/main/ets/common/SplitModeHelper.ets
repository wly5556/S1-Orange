import { display } from '@kit.ArkUI'
import { PropKey } from './Constants'

/**
 * NavigationMode.Auto 的分栏阈值：窗口宽度达到 600vp 时 Navigation 才会双栏显示
 */
export const SplitDisplayMinVp = 600

/**
 * 设备（屏幕）当前是否为横屏朝向
 */
export function isLandscapeOrientation(): boolean {
  const orientation = display.getDefaultDisplaySync().orientation
  return orientation == display.Orientation.LANDSCAPE || orientation == display.Orientation.LANDSCAPE_INVERTED
}

/**
 * 当前是否应进入双栏显示：
 * 需窗口宽度达到阈值、未被临时关闭，且当前朝向对应的开关已开启
 */
export function splitLayoutActive(portraitEnabled: boolean, landscapeEnabled: boolean,
  isLandscape: boolean, windowWidthPx: number, tempOff: boolean): boolean {
  if (tempOff || px2vp(windowWidthPx) < SplitDisplayMinVp) {
    return false
  }
  return isLandscape ? landscapeEnabled : portraitEnabled
}

/**
 * 以运行时状态（AppStorage 中的窗口宽度与朝向）判定当前是否应进入双栏显示，供事件处理中按需调用
 */
export function splitDisplayActive(portraitEnabled: boolean, landscapeEnabled: boolean, tempOff: boolean): boolean {
  return splitLayoutActive(portraitEnabled, landscapeEnabled,
    AppStorage.get<boolean>(PropKey.windowIsLandscape) ?? false,
    AppStorage.get<number>(PropKey.windowWidth) ?? 0,
    tempOff)
}