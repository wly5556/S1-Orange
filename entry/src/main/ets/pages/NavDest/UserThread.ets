import { OuterScroller } from '../../common/component/OuterScroller'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import { TitleBar } from '../../common/component/TitleBar'
import { ArrayDataSource, ReloadController } from '../../common/BasicDataSource'
import { PageSlider } from '../../common/component/PageSlider'
import { SwipePageLoadingIcon, SwipePageViewer } from '../../common/component/SwipePageViewer'
import request from '../../api/request'
import { URL } from '../../api/base'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { openThreadPost, openThreadPostByLink, ThreadPostParam } from './ThreadPostList'
import { unescapeXml } from '../../common/XmlParser'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PropKey } from '../../common/Constants'

export interface UserThreadParam {
  uid: string
  username: string
  threadNum: number
  replyNum: number
  typeReply: boolean
}


@Component
export struct UserThread {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  context = getContext(this) as common.UIAbilityContext
  @State currentPage: number = 1
  @Provide totalPage: number = 1
  @State jumpToPage: number = -1
  @Provide pageParam: UserThreadParam = {
    uid: '',
    username: '',
    threadNum: 0,
    replyNum: 0,
    typeReply: false
  }
  reloadCtrl: ReloadController = new ReloadController()

  popBack() {
    this.pathStack.pop()
  }

  @Builder
  ThreadList(page: number, index: number, loadingIcon: SwipePageLoadingIcon) {
    UserThreadPage({
      pageToLoad: page,
      loadingIcon
    })
  }

  build() {
    NavDestination() {

      OuterScroller() {
        TitleBar({
          titleContent: this.pageParam.username + (this.pageParam.typeReply ? '的回复' : '的主题帖'),
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        }) {
          Blank()
          PageSlider({
            pageIndex: this.currentPage,
            totalPage: this.totalPage,
            doJump: page => {
              this.jumpToPage = page
            },
          })
        }

        Scroll() {
          Column() {
            SwipePageViewer({
              enablePullToRefresh: false,
              currentPage: this.currentPage,
              contentBuilder: this.ThreadList,
              jumpToPage: this.jumpToPage,
              maxPage: this.totalPage,
              useList: true,
              reloadCtrl: this.reloadCtrl
            })
          }.width('100%')
          .constraintSize({
            minHeight: '100%'
          })
        }
        .scrollBar(BarState.Off)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
        .width('100%')
        .height('100%')
        .backgroundColor(this.appTheme.backgroundSecondary)
      }
    }.hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.pageParam = context.pathInfo.param as UserThreadParam
      if (this.pageParam.typeReply) {
        this.totalPage = Math.ceil(this.pageParam.replyNum / 20)
      } else {
        this.totalPage = Math.ceil(this.pageParam.threadNum / 20)
      }
      this.reloadCtrl.reload()
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

interface UserThreadReply {
  replyContent?: string
  replyUrl?: string
}

interface UserThreadItem {
  subject: string;
  tid: string
  forumName: string
  repliesCount: string
  views: string
  lastReplyUsername: string
  lastReplyDate: string
  replies: UserThreadReply[]
}

@Component
struct UserThreadPage {
  threadDataSource: ArrayDataSource<UserThreadItem> = new ArrayDataSource<UserThreadItem>()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @Consume pathStack: NavPathStack
  @Consume pageParam: UserThreadParam
  @Prop pageToLoad: number
  @Consume @Watch('requestPageData') dataControlCounter: number
  context = getContext(this) as common.UIAbilityContext
  loadingIcon?: SwipePageLoadingIcon

  aboutToAppear(): void {
    this.requestPageData()
  }

  requestPageData() {
    if (this.pageParam && this.pageParam.uid != '') {
      this.loadingIcon?.show(this.pageToLoad)
      if (this.pageParam.typeReply) {
        new request<string>(URL.USER_FORUM_WEB, URL.WEB_BASE)
          .param('uid', this.pageParam.uid)
          .param('type', 'reply')
          .param('page', this.pageToLoad.toString())
          .toText()
          .get()
          .then(htmlStr => {
            this.threadDataSource.reload(extractUserThreads(htmlStr, true))
            this.loadingIcon?.hide(this.pageToLoad)
          })
      } else {
        new request<string>(URL.USER_FORUM_WEB, URL.WEB_BASE)
          .param('uid', this.pageParam.uid)
          .param('type', 'thread')
          .param('page', this.pageToLoad.toString())
          .toText()
          .get()
          .then(htmlStr => {
            this.threadDataSource.reload(extractUserThreads(htmlStr, false))
            this.loadingIcon?.hide(this.pageToLoad)
          })
      }
    }
  }

  build() {
    Stack() {
      List() {
        LazyForEach(this.threadDataSource, (item: UserThreadItem) => {
          ListItem() {
            Column() {
              Column({ space: 8 }) {
                Text(item.subject)
                  .fontSize(FontSizeEnum[this.appState.fontSize].vp18)
                  .fontColor(this.appTheme.fontEmphasize)

                Row({ space: 12 }) {
                  Text(item.forumName).fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                  Text(`回复 ${item.repliesCount}`).fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                  Text(`查看 ${item.views}`).fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                }.opacity(.8)

                Text(`最后回复 ${item.lastReplyUsername} 于 ${item.lastReplyDate}`)
                  .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                  .opacity(.8)

                if (item.replies) {
                  ForEach(item.replies, (reply: UserThreadReply, index: number) => {
                    Divider()
                    Text(reply.replyContent).margin({ top: 4 }).width('100%')
                      .onClick(() => {
                        openThreadPostByLink(URL.WEB_BASE + reply.replyUrl,
                          this.pathStack, () => {
                            this.getUIContext().getPromptAction().showToast({
                              message: '解析帖子链接出错'
                            })
                          }, item.subject, item.repliesCount)
                      })
                  })
                }
              }
              .backgroundColor(this.appTheme.backgroundSecondary)
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(12)
              .onClick(e => {
                const param: ThreadPostParam = {
                  tid: item.tid,
                  subject: item.subject,
                }
                openThreadPost(param, this.pathStack)
              })
            }.padding({ bottom: 8 })
          }
        }, (item: UserThreadItem) => item.tid)

        ListItem() {
          BottomSafeArea()
        }
      }
      .cachedCount(5)
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(this.appTheme.backgroundTertiary)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.PARENT_FIRST
      })
      .edgeEffect(EdgeEffect.None)
    }
  }
}

function extractUserThreads(html: string, matchReply: boolean) {
  let regex: RegExp
  let titlePattern: RegExp
  if (matchReply) {
    regex = /<tr class="bw0_all">([\s\S]*?)(?=<tr class="bw0_all">|<\/table>)/g
    titlePattern = /<th>\s<a href="forum\.php[\S]*?ptid=(\d+)[\s\S]*?>([\s\S]*?)<\/a>/
  } else {
    regex = /<tr>\s<td class="icn">[\s\S]*?<\/tr>/g
    titlePattern = /<th>\s<a href="thread-(\d+)-[\s\S]*?>([\s\S]*?)<\/a>/
  }
  const forumNamePattern = /<a href="forum-[\s\S]*?>([\s\S]*?)<\/a>/
  const repliesAndViews =
    /<td class="num">\s<a href="thread-[\s\S]*? class="xi2"[\s\S]*?>([\s\S]*?)<\/a>\s<em>(\d+)<\/em>/
  const usernamePattern = /<cite><a[^>]*>([^<]+)<\/a><\/cite>/
  const lastReplyDatePattern = /<\/cite>\s*<em><a[^>]*>([^<]+)<\/a><\/em>/
  let match: RegExpExecArray | null = null
  const results: UserThreadItem[] = []

  while ((match = regex.exec(html)) !== null) {
    const htmlResult = match[0]

    const titleMatch = titlePattern.exec(htmlResult)
    const forumNameMatch = forumNamePattern.exec(htmlResult)
    const repliesAndViewsMatch = repliesAndViews.exec(htmlResult)
    const usernameMatch = usernamePattern.exec(htmlResult)
    const lastReplyDateMatch = lastReplyDatePattern.exec(htmlResult)
    if (!forumNameMatch || !titleMatch || !repliesAndViewsMatch || !usernameMatch || !lastReplyDateMatch) {
      continue
    }
    const replyContentPattern = /<a href="(forum\.php[\S]*?pid=\d+)"[\s\S]*?>([\s\S]*?)<\/a>/g
    const replies: UserThreadReply[] = []
    if (matchReply) {
      while (true) {
        const replyContent = replyContentPattern.exec(htmlResult)
        if (!replyContent) {
          break
        }
        replies.push({
          replyUrl: replyContent ? unescapeXml(replyContent[1]) : undefined,
          replyContent: replyContent ? replyContent[2] : undefined
        })
      }
    }
    const result: UserThreadItem = {
      subject: titleMatch[2].trim(),
      tid: titleMatch[1].trim(),
      forumName: forumNameMatch[1].trim(),
      repliesCount: repliesAndViewsMatch[1],
      views: repliesAndViewsMatch[2],
      lastReplyUsername: usernameMatch[1],
      lastReplyDate: lastReplyDateMatch[1],
      replies
    }
    results.push(result)
  }

  return results
}

@Builder
export function RegisterBuilder() {
  UserThread()
}

export function openUserThread(pathStack: NavPathStack, param: UserThreadParam) {
  openOrJumpTo(pathStack, PageNameEnum.UserThread, param)
}
