import { rcp } from '@kit.RemoteCommunicationKit'
import { util } from '@kit.ArkTS'
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { PreferenceManager } from '../config/UserConfig'
import { UpdateCheckInterval } from '../config/v1/default'
import { GITHUB_RELEASE_BADGE, GITHUB_RELEASE_PAGE } from '../api/base'
import { Event } from './Events'
import { openInBrowser } from './WantUitl'

/**
 * 应用版本检查
 *
 * 通过对比 GitHub shields.io 提供的版本 badge 图像哈希，判断远端是否发布了新版本：
 * - update_badge_hash：作为基准的 badge 图像哈希（上次记录的）
 * - update_new_version：是否存在未处理的新版本（驱动设置/侧边栏的 "new" 标签）
 *
 * 首次检查会记录当前哈希作为基准（不弹窗）；后续若拉取到的哈希与基准不同，
 * 则更新基准并标记 update_new_version=true，弹出提醒。用户查看或忽略后清除该标记。
 */

const DAY_MS = 24 * 60 * 60 * 1000

/**
 * FNV-1a 32位哈希。对字节数组生成稳定的 32 位值，再转 36 进制字符串。
 * 纯 TS 实现，避免依赖 crypto 模块的异步调用与权限。
 */
function fnv1aHash(bytes: Uint8Array): string {
  let hash = 0x811c9dc5
  for (let i = 0; i < bytes.length; i++) {
    hash ^= bytes[i]
    hash = Math.imul(hash, 0x01000193) // hash *= 16777619，用 Math.imul 避免 32 位溢出
  }
  return (hash >>> 0).toString(36)
}

/**
 * 将字符串按 UTF-8 编码为字节数组。仅在响应体为字符串时用于哈希。
 */
function stringToUtf8Bytes(str: string): Uint8Array {
  const encoder = new util.TextEncoder()
  return encoder.encodeInto(str)
}

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

/**
 * 拉取 badge 图像并计算其哈希。失败时返回 null。
 */
async function fetchBadgeHash(): Promise<string | null> {
  let session: rcp.Session | undefined = undefined
  try {
    session = rcp.createSession({
      baseAddress: '',
      requestConfiguration: {
        transfer: {
          autoRedirect: true,
          timeout: { connectMs: 5000 }
        }
      }
    })
    const resp = await session.get(GITHUB_RELEASE_BADGE)
    if (resp === undefined || resp.statusCode !== 200 || resp.body === undefined) {
      return null
    }
    // rcp.Response.body 为 string | ArrayBuffer；图像响应为 ArrayBuffer
    const body = resp.body
    if (typeof body === 'string') {
      return fnv1aHash(stringToUtf8Bytes(body))
    }
    return fnv1aHash(new Uint8Array(body))
  } catch (e) {
    console.error('VersionCheck fetchBadgeHash error:', JSON.stringify(e))
    return null
  } finally {
    session?.close()
  }
}

function notifyDismissed(context: common.UIAbilityContext) {
  context.eventHub.emit(Event.NewVersionDismissed)
}

function showUpdateDialog(context: common.UIAbilityContext) {
  promptAction.showDialog({
    title: '发现新版本',
    message: '是否前往Release页面查看？',
    buttons: [
      { text: '此版本不提醒', color: $r('sys.color.font_secondary') },
      { text: '查看', color: $r('sys.color.ohos_id_color_primary') }
    ]
  }).then(res => {
    PreferenceManager.modify(conf => {
      conf.update_new_version = false
    })
    notifyDismissed(context)
    if (res.index === 1) {
      openInBrowser(context, GITHUB_RELEASE_PAGE)
    }
  }).catch(() => {
  })
}

export async function checkVersionOnStartup(context: common.UIAbilityContext): Promise<void> {

  const knownHash = await readConfigAndDecideToCheck()
  if (knownHash === null) {
    return
  }
  let freshHash = await fetchBadgeHash()
  if (freshHash === null) {
    return
  }
  let hasNewVersion = false
  PreferenceManager.modify(conf => {
    if (freshHash === null) {
      return
    }
    if (conf.update_badge_hash === '') {
      conf.update_badge_hash = freshHash
    } else if (conf.update_badge_hash !== freshHash) {
      conf.update_badge_hash = freshHash
      conf.update_new_version = true
      hasNewVersion = true
    }
  })

  if (hasNewVersion) {
    showUpdateDialog(context)
  }
}

function readConfigAndDecideToCheck(): Promise<string | null> {
  return new Promise<string | null>(resolve => {
    PreferenceManager.readonly(conf => {
      if (conf.update_check_interval === UpdateCheckInterval.never) {
        resolve(null)
        return
      }
      const now = Date.now()
      if (now - conf.update_last_check < intervalMs(conf.update_check_interval)) {
        resolve(null)
        return
      }
      const knownHash = conf.update_badge_hash
      PreferenceManager.modify(conf2 => {
        conf2.update_last_check = now
      })
      resolve(knownHash)
    })
  })
}
