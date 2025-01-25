import { intl } from '@kit.LocalizationKit'
const  systemLocale = new intl.Locale().toString()
const yearBeforeFormat: intl.DateTimeFormat = new intl.DateTimeFormat(systemLocale, {
  year: 'numeric', month: 'numeric', day: 'numeric'
})
const hourFormat : intl.DateTimeFormat = new intl.DateTimeFormat(systemLocale, {
  hour: 'numeric',
  minute: 'numeric',
  hourCycle: 'h12'
})
const monthdayFormat : intl.DateTimeFormat = new intl.DateTimeFormat(systemLocale, {
  month: 'long',
  day: 'numeric'
})
const relativeTimeFormat: intl.RelativeTimeFormat = new intl.RelativeTimeFormat(systemLocale, {
  numeric: 'auto'
})

export function formatRelativeTime(now: Date, then: Date): string {
  const oneDay = 24 * 60 * 60 * 1000
  const diffInMs = now.getTime() - then.getTime()

  if (now.getFullYear() > then.getFullYear()) {
    return `${yearBeforeFormat.format(then)} ${hourFormat.format(then)}`
  } else {
    const nowStartOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    const thenTime = then.getTime()
    if (thenTime < nowStartOfDay.getTime() - oneDay || diffInMs < 0) {
      return `${monthdayFormat.format(then)} ${hourFormat.format(then)}`
    } else if (thenTime < nowStartOfDay.getTime()) {
      return `${relativeTimeFormat.format(-1, 'day')} ${hourFormat.format(then)}`
    } else {
      const hours = Math.floor(diffInMs / (60 * 60 * 1000));
      const mins = Math.floor((diffInMs % (60 * 60 * 1000)) / (60 * 1000));

      if (hours > 0) {
        return `${relativeTimeFormat.format(-hours, 'hour')} ${hourFormat.format(then)}`;
      } else {
        return `${relativeTimeFormat.format(-mins, 'minute')} ${hourFormat.format(then)}`;
      }
    }
  }
}