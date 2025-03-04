import BuildProfile from 'BuildProfile'
import { defaultApplicationConfig } from '../config/v1/default'
import { deviceInfo } from '@kit.BasicServicesKit'

export class PostSignature {
  static enable: boolean = defaultApplicationConfig.post_signature
  static device: boolean = defaultApplicationConfig.post_signature_device_info
  static appName: string = ''

  static init(enable: boolean, appName: string, device: boolean) {
    PostSignature.enable = enable
    PostSignature.appName = appName
    PostSignature.device = device
  }

  static displayText() {
    return `——来自 ` +
    PostSignature.getDeviceInfo()
      +
      `${PostSignature.appName} ${BuildProfile.VERSION_NAME}`
  }

  private static deviceInfo: string | undefined = undefined

  private static getDeviceInfo() {
    if (PostSignature.device) {
      if (PostSignature.deviceInfo === undefined) {
        PostSignature.deviceInfo = ` ${deviceInfo.marketName} ${deviceInfo.osFullName}(${deviceInfo.sdkApiVersion}) 上的 `
      }
      return PostSignature.deviceInfo
    } else {
      return ''
    }
  }

  static text() {
    if (PostSignature.enable) {
      return '\n\n' +
        `——来自 ` +
      PostSignature.getDeviceInfo()
        +
        `[url=https://bbs.saraba1st.com/2b/forum.php?mod=viewthread&tid=2244111]${PostSignature.appName}[/url] ${BuildProfile.VERSION_NAME}`
    } else {
      return ''
    }
  }
}
