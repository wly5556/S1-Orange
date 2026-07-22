import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import BuildProfile from 'BuildProfile'
import request from '../api/request'
import { APP_RELEASE_INFO, GITHUB_RELEASE_PAGE } from '../api/base'
import { PreferenceManager } from '../config/UserConfig'
import { UpdateCheckInterval } from '../config/v1/default'
import { Event } from './Events'
import { openInBrowser } from './WantUitl'

export interface LatestVersionInfo {
  raw: string
  version: string
  releaseDate: string
}

const DAY_MS = 24 * 60 * 60 * 1000

function intervalMs(interval: UpdateCheckInterval): number {
  switch (interval) {
    case UpdateCheckInterval.weekly:
      return 7 * DAY_MS
    case UpdateCheckInterval.monthly:
      return 30 * DAY_MS
    case UpdateCheckInterval.never:
      return -1
    default:
      return 30 * DAY_MS
  }
}

export function parseLatestVersionInfo(body: string): LatestVersionInfo | null {
  const versionHeader = 'Latest version:'
  const lines = body
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .split('\n')
    .map((line: string): string => line.trim())
    .filter((line: string): boolean => line.length > 0)
  if (lines.length !== 3 || lines[0] !== versionHeader) {
    return null
  }
  return {
    raw: `${lines[0]}\n${lines[1]}\n${lines[2]}`,
    version: lines[1],
    releaseDate: lines[2]
  }
}

export async function fetchLatestVersionInfo(): Promise<LatestVersionInfo | null> {
  try {
    const body = await new request<string>(APP_RELEASE_INFO, '')
      .withoutCookie()
      .timeout(5000)
      .toText()
      .get()
    return parseLatestVersionInfo(body)
  } catch (e) {
    console.error('VersionCheck fetchLatestVersionInfo error:', JSON.stringify(e))
    return null
  }
}

export function compareVersions(a: string, b: string): number {
  const partsA = a.split('.')
  const partsB = b.split('.')
  const length = Math.max(partsA.length, partsB.length)
  for (let i = 0; i < length; i++) {
    const numA = i < partsA.length ? parseInt(partsA[i]) : 0
    const numB = i < partsB.length ? parseInt(partsB[i]) : 0
    const diff = (isNaN(numA) ? 0 : numA) - (isNaN(numB) ? 0 : numB)
    if (diff !== 0) {
      return diff
    }
  }
  return 0
}

export function isNewerVersion(latest: string, current: string): boolean {
  return compareVersions(latest, current) > 0
}

function showUpdateDialog(context: common.UIAbilityContext) {
  promptAction.showDialog({
    title: '发现新版本',
    message: '是否前往 Release 页面查看？',
    buttons: [
      { text: '下次再提醒', color: $r('sys.color.font_secondary') },
      { text: '查看', color: $r('sys.color.ohos_id_color_primary') }
    ]
  }).then(res => {
    if (res.index === 0) {
      PreferenceManager.modify(conf => {
        conf.update_show_new_version = false
      })
      context.eventHub.emit(Event.NewVersionDismissed)
    } else if (res.index === 1) {
      openInBrowser(context, GITHUB_RELEASE_PAGE)
    }
  }).catch(() => {
  })
}

export async function checkVersionOnStartup(context: common.UIAbilityContext): Promise<void> {
  if (!await shouldCheckVersion()) {
    return
  }
  const latestInfo = await fetchLatestVersionInfo()
  if (latestInfo === null) {
    return
  }
  let hasNewVersion = false
  await PreferenceManager.modify(conf => {
    conf.update_last_check = Date.now()
    const lastKnownVersion = parseLatestVersionInfo(conf.update_latest_version_info)?.version
    conf.update_latest_version_info = latestInfo.raw
    if (!isNewerVersion(latestInfo.version, BuildProfile.VERSION_NAME)) {
      conf.update_show_new_version = false
      return
    }
    if (lastKnownVersion !== latestInfo.version) {
      conf.update_show_new_version = true
      hasNewVersion = true
    }
  })

  if (hasNewVersion) {
    showUpdateDialog(context)
  }
}

async function shouldCheckVersion(): Promise<boolean> {
  let shouldCheck = false
  const now = Date.now()
  await PreferenceManager.readonly(conf => {
    if (conf.update_check_interval === UpdateCheckInterval.never) {
      return
    }
    shouldCheck = now - conf.update_last_check >= intervalMs(conf.update_check_interval)
  })
  return shouldCheck
}
