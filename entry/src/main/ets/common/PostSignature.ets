import BuildProfile from 'BuildProfile'
import { defaultApplicationConfig } from '../config/v1/default'

export class PostSignature {
  static enable: boolean = defaultApplicationConfig.post_signature
  static appName: string = ''

  static init(enable: boolean, appName: string) {
    PostSignature.enable = enable
    PostSignature.appName = appName
  }

  static displayText() {
    return `——来自 ${PostSignature.appName} ${BuildProfile.VERSION_NAME}`
  }

  static text() {
    if (PostSignature.enable) {
      return '\n\n' +
        `——来自 [url=https://bbs.saraba1st.com/2b/forum.php?mod=viewthread&tid=2244111]${PostSignature.appName}[/url] ${BuildProfile.VERSION_NAME}`
    } else {
      return ''
    }
  }
}
