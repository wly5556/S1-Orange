import { DomainRegex, URL } from '../../api/base'
import request from '../../api/request'
import { common } from '@kit.AbilityKit'
import { openOrJumpTo } from '../SingletonPage'
import { PageNameEnum } from '../PageNameEnum'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { openThreadPost, ThreadPostParam } from './ThreadPostList'
import { openInBrowser } from '../../common/WantUitl'
import { queryPostLocation } from '../../common/dataStore/PostLocationData'

const REDIRECT_LOCATION_REGEX = /tid=(\d+)&page=(\d+)#pid(\d+)/

export interface ThreadRedirectParam {
  href: string
  subject?: string
  replies?: string
  sourceTid?: string
  fallbackToBrowser?: boolean
  failedMessage?: string
}

export function isS1RedirectPostLink(href: string): boolean {
  return DomainRegex.test(href) && href.includes(URL.REDIRECT_TO_POST)
}

export function parseS1RedirectPostPid(href: string): string | undefined {
  if (!isS1RedirectPostLink(href)) {
    return undefined
  }
  const match = href.match(/[?&]pid=(\d+)/)
  return match ? match[1] : undefined
}

@Component
export struct ThreadRedirectPage {
  pathStack: NavPathStack = new NavPathStack()
  context = getContext(this) as common.UIAbilityContext
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @State pageParam: ThreadRedirectParam = { href: '' }
  pageDestroyed: boolean = false

  aboutToDisappear(): void {
    this.pageDestroyed = true
  }

  openTarget(tid: string, page: number, pid: string) {
    if (this.pageDestroyed) {
      return
    }
    const sameThread = this.pageParam.sourceTid == undefined || this.pageParam.sourceTid == tid
    const param: ThreadPostParam = {
      tid: tid,
      jumpToPid: pid,
      jumpToPage: page,
      subject: sameThread ? this.pageParam.subject : undefined,
      replies: sameThread ? this.pageParam.replies : undefined,
      jumpToPidWithHighlight: true
    }
    // 无动画打开实际帖子页，同时把自身移出页面栈，使返回键直接回到来源页
    openThreadPost(param, this.pathStack, false, false)
    this.pathStack.removeByName(PageNameEnum.ThreadRedirect)
  }

  onResolveFailed() {
    if (this.pageDestroyed) {
      return
    }
    if (this.pageParam.fallbackToBrowser) {
      openInBrowser(this.context, this.pageParam.href)
    } else if (this.pageParam.failedMessage) {
      this.getUIContext().getPromptAction().showToast({
        message: this.pageParam.failedMessage
      })
    }
    this.pathStack.pop()
  }

  resolveRedirect() {
    let href = this.pageParam.href
    if (href.includes(URL.DOMAIN_APP)) {
      href = href.replace(URL.DOMAIN_APP, URL.DOMAIN_WEB)
    }
    new request<string>(href, '')
      .redirectLocation()
      .get()
      .then(location => {
        const match = location.match(REDIRECT_LOCATION_REGEX)
        if (match && match.length === 4) {
          this.openTarget(match[1], parseInt(match[2]), match[3])
          return
        }
        this.onResolveFailed()
      })
      .catch(() => {
        this.onResolveFailed()
      })
  }

  build() {
    NavDestination() {
      Column() {
        TitleBar({
          titleContent: '正在重定向...',
          clickLeftButton: () => {
            this.pathStack.pop()
          },
          useRightMenu: false
        })
        Column({ space: 16 }) {
          LoadingProgress()
            .width(64)
            .height(64)
            .color($r('sys.color.ohos_id_color_emphasize'))
          Text('正在获取目标楼层位置，请稍候')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
            .fontColor(this.appTheme.fontSecondary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.appTheme.backgroundTertiary)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.pageParam = context.pathInfo.param as ThreadRedirectParam
      this.resolveRedirect()
    })
    .onBackPressed(() => {
      // 返回键取消跳转，页面销毁后回调不再处理重定向结果
      this.pathStack.pop()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  ThreadRedirectPage()
}

export function openThreadRedirect(pathStack: NavPathStack, param: ThreadRedirectParam) {
  // 已知落点的重定向链接查表直开，省去网络解析；未命中再走重定向页在线解析
  const pid = parseS1RedirectPostPid(param.href)
  const location = pid != undefined ? queryPostLocation(pid) : undefined
  if (location) {
    const sameThread = param.sourceTid == undefined || param.sourceTid == location.tid
    const postParam: ThreadPostParam = {
      tid: location.tid,
      jumpToPid: pid,
      jumpToPage: location.page,
      subject: sameThread ? param.subject : undefined,
      replies: sameThread ? param.replies : undefined,
      jumpToPidWithHighlight: true
    }
    openThreadPost(postParam, pathStack)
    return
  }
  openOrJumpTo(pathStack, PageNameEnum.ThreadRedirect, param)
}
