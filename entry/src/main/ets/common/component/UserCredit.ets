import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { AppThemeColor } from '../theme/basic/basic'

const NegativeUserCreditColorLight = '#d7848c'
const NegativeUserCreditColorDark = '#d8a0a6'

function creditColor(userCredit: number, appTheme: AppThemeColor): ResourceColor {
  if (userCredit < 0) {
    return appTheme.isDark ? NegativeUserCreditColorDark : NegativeUserCreditColorLight
  }
  return appTheme.fontSecondary || $r('sys.color.font_secondary')
}

export function formatUserCredit(userCredit: number): string {
  return `${userCredit}鹅`
}

@Builder
export function UserCreditText(userCredit: number, appTheme: AppThemeColor, fontSize: number) {
  Text(formatUserCredit(userCredit))
    .fontSize(FontSizeEnum[fontSize].vp13)
    .fontColor(creditColor(userCredit, appTheme))
}
