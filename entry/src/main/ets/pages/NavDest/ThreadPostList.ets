import { DomainRegex, URL } from '../../api/base'
import request, { RequestError } from '../../api/request'
import { Attachment, PostListV4, SpecialPollAllowVote, SpecialPollResultVisible } from '../../api/model/postList'
import wrapper, { wrapperApp } from '../../api/wrapper'
import { OuterScroller } from '../../common/component/OuterScroller'
import { PullToRefreshStage } from '../../common/component/PullToRefresh'
import { TitleBar } from '../../common/component/TitleBar'
import { unescapeAll } from '../../common/XmlParser'
import { RectSize } from '../../common/component/ImageContainer'
import { Avatar } from '../../common/component/Avatar'
import { common } from '@kit.AbilityKit'
import { openUserSpace, UserSpaceParam } from './UserSpace'
import { HeavyClickEffect, Spring035s } from '../../common/Animation'
import { formatRelativeTime } from '../../common/TimeFormat'
import { PageNameEnum } from '../PageNameEnum'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { JSON } from '@kit.ArkTS'
import { ImageViewer, ImageViewerParam } from '../../common/component/ImageViewer'
import { openOrJumpTo } from '../SingletonPage'
import { SwipePageLoadingIcon, SwipePageViewer } from '../../common/component/SwipePageViewer'
import { Event } from '../../common/Events'
import { PageSlider } from '../../common/component/PageSlider'
import {
  FlushThreadViewHistory,
  QuerySingleViewHistory,
  RecordThreadViewHistory
} from '../../common/dataStore/HistoryData'
import { ArrayDataSource, ReloadController } from '../../common/BasicDataSource'
import { openInBrowser, openS1LinkLike } from '../../common/WantUitl'
import { PreferenceState } from '../NavProvider/NavigationPage'
import Account from '../../api/model/account'
import { CopyHyperLink, ShareText } from '../../common/ShareKit'
import { ErrorTips } from '../../common/component/ErrorTips'
import { PostRating, ThreadRatingInfo } from '../../common/component/PostRating'
import { openPostRatingDetail, PostRatingDetailParam } from './PostRatingDetail'
import { PollInfoVM, PollOptionVM, PollPanel } from '../../common/component/PollPanel'
import { getPollInfo, getPollList } from './PollDetail'
import { resolveS1WebLink } from '../../common/component/GotoThreadDialog'
import {
  openWriteReply,
  TOOL_BAR_HEIGHT,
  WriteReplyMode,
  WriteReplyPageTitle,
  WriteReplyParam,
  WriteReplyPopData
} from './WriteReply'
import {
  parseXML,
  PostContentParser,
  ThreadPostUINodeRender,
  UIRootNode
} from '../../common/component/ThreadPostContent'
import { BLOCK_USER_LIST_STATE, BlockUser, UnblockUser } from '../../common/dataStore/BlockUser'
import { ThreadDataApp } from '../../api/model/app/thread'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { HiddenPostDisplay } from '../../config/v1/default'
import { LengthUnit } from '@kit.ArkUI'
import { PropKey, SafeArea } from '../../common/Constants'
import { DownloadFile } from '../../api/download'

interface PostViewModel {
  node: UIRootNode[]
  uid: string,
  username: string,
  pid: string,
  timestamp: Date,
  userCredit: string
}

export interface ThreadPostParam {
  tid: string // 仅tid是打开本页面的必须参数
  fid?: string
  jumpToPage?: number
  authorid?: string
  subject?: string // 若传入，则将用作初始值，直到从api获取到真实值
  replies?: string
  jumpToPid?: string
  jumpToPidWithHighlight?: boolean
}

const PostContentVerticalPadding = 12
const PostContentHorizontalPadding = 16
const POST_PER_PAGE = 40

function genThreadPostViewKey(pageParam: ThreadPostParam) {
  return `${pageParam.tid},${pageParam.jumpToPid},${pageParam.authorid}`
}

function openImgViewerEventName(pageParam: ThreadPostParam) {
  return Event.OpenImageViewer + genThreadPostViewKey(pageParam)
}

@Component
export struct ThreadPostList {
  context = getContext(this) as common.UIAbilityContext
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @Provide @Watch('onPageParamUpdate') pageParam: ThreadPostParam = {
    tid: ''
  }
  @State imgViewer: ImageViewerParam = { urls: [], startAt: 0 }
  @State imgViewerShow: boolean = false
  @Provide('visiblePage') currentPage: number = 1
  @Provide totalPage: number = 1
  @State jumpToPage: number = -1
  jumpToPageDone: boolean = false
  @Provide jumpToPost?: string = undefined
  jumpToPostDone: boolean = false
  @Provide allowPullDownRefresh: boolean = true
  @Provide allowPullUpRefresh: boolean = false
  @Provide pageScrollOffset: Map<number, number> = new Map
  @State replyButtonExpand: boolean = false
  @StorageProp(SafeArea.bottom) bottomRectHeight: number = 0
  reloadCtrl: ReloadController = new ReloadController()

  onPageParamUpdate() {
    if (this.pageParam.replies == undefined) {
      return // 页面参数只有tid时的初始化情形，等待子页面回传正确的回帖数量
    }
    // 此时认为真正打开了帖子
    this.totalPage = parseInt(this.pageParam?.replies || '0') > 1 ?
    Math.ceil(parseInt(this.pageParam?.replies || '0') / POST_PER_PAGE) : 1
    if (this.pageParam.jumpToPage && !this.jumpToPageDone && this.pageParam.jumpToPage <= this.totalPage) {
      let jumpToPage = this.pageParam.jumpToPage!
      if (jumpToPage < 0) {
        this.jumpToPage = Math.max(1, this.totalPage + 1 + jumpToPage)
      } else if (jumpToPage > 1) {
        this.jumpToPage = Math.min(this.totalPage, jumpToPage)
      }
      this.jumpToPageDone = true
    }
    if (this.pageParam.jumpToPid && this.pageParam.jumpToPid != '0' && !this.jumpToPostDone) {
      this.jumpToPost = this.pageParam.jumpToPid
      this.jumpToPostDone = true
    }
    if (this.pageParam.subject && this.pageParam.replies && this.pageParam.authorid === undefined) {
      RecordThreadViewHistory(this.pageParam.tid, this.pageParam.subject, this.pageParam.jumpToPid || '0', Date.now(),
        this.pageParam.replies, this.currentPage)
      FlushThreadViewHistory(this.pageParam.tid)
    }
  }

  getUrlForPage() {
    return `${URL.WEB_BASE}thread-${this.pageParam.tid}-${this.currentPage}-1.html`
  }

  @Builder
  threadPostPageBuilder(page: number, index: number, loadingIcon: SwipePageLoadingIcon, scroller?: Scroller) {
    SinglePostPage({
      pageToLoad: page,
      loadingIcon,
      scroller
    })
  }

  build() {
    NavDestination() {
      Stack() {
        OuterScroller({
          onEnterAndLeaveTop: atTop => this.allowPullDownRefresh = atTop,
          onEnterAndLeaveBottom: atBottom => this.allowPullUpRefresh = atBottom
        }) {
          TitleBar({
            titleContent: `${this.pageParam.subject || ""}`,
            titleCopyable: true,
            clickLeftButton: () => {
              this.pathStack.pop()
            },
            menu: [{
              value: '刷新',
              action: () => {
                this.reloadCtrl.reload()
              }
            }, {
              value: '收藏',
              action: () => {
                new request<wrapper<Account>>(URL.FAV_ADD)
                  .formHash()
                  .post({
                    'id': this.pageParam.tid
                  }).then(v => {
                  if (v.Message.messageval.includes('success')) {
                    this.getUIContext().getPromptAction().showToast({
                      message: '收藏成功'
                    })
                  } else if (v.Message.messageval.includes('repeat')) {
                    this.getUIContext().getPromptAction().showToast({
                      message: '已收藏过本贴，收藏操作重复'
                    })
                  }
                }).catch((e: RequestError) => {
                  this.getUIContext().getPromptAction().showToast({
                    message: '收藏出错',
                  })
                })
              }
            }, {
              value: '分享',
              action: () => {
                ShareText(this.pageParam.subject + ' ' + generateS1WebPostLink(this.pageParam.tid, this.currentPage),
                  this.context)
              }
            }, {
              value: '复制链接',
              action: () => {
                CopyHyperLink(generateS1WebPostLink(this.pageParam.tid, this.currentPage), this.pageParam.subject)
              }
            }, {
              value: '从浏览器打开',
              action: () => {
                openInBrowser(this.context, this.getUrlForPage())
              }
            }]
          }) {
            PageSlider({
              pageIndex: this.currentPage,
              totalPage: this.totalPage,
              doJump: page => this.jumpToPage = page
            })
          }

          if (this.pageParam && this.pageParam.tid) {
            SwipePageViewer({
              enablePullToRefresh: this.allowPullDownRefresh,
              currentPage: this.currentPage,
              contentBuilder: this.threadPostPageBuilder,
              jumpToPage: this.jumpToPage,
              reloadCtrl: this.reloadCtrl,
              useList: true,
              maxPage: this.totalPage
            }).backgroundColor(this.appTheme.backgroundTertiary)
          }
        }

        if (this.allowPullDownRefresh || this.replyButtonExpand) {
          Stack() {
            Image($r('app.media.ellipsis_message_fill')).width(30).height(30)
              .fillColor(Color.White)
            if (this.replyButtonExpand) {
              Row() {
                TitleBar({
                  titleContent: WriteReplyPageTitle[WriteReplyMode.NEW_POST],
                  useRightMenu: false,
                })
              }.width('100%')
              .position({ top: 0 })
              .clip(true)
            }
            Row() {

            }.width('100%')
            .height(this.replyButtonExpand ? TOOL_BAR_HEIGHT + px2vp(this.bottomRectHeight) : 0)
            .position({ bottom: 0 })
            .backgroundColor(this.appTheme.backgroundTertiary)
          }
          .clip(true)
          .width(this.replyButtonExpand ? '100%' : 60)
          .height(this.replyButtonExpand ? '100%' : 60)
          .borderRadius(this.replyButtonExpand ? 0 : 30)
          .backgroundColor(this.replyButtonExpand ? this.appTheme.backgroundSecondary : this.appTheme.fontEmphasize)
          .position(this.replyButtonExpand ? { bottom: 0 } : { bottom: 40, right: 30 })
          .clickEffect(HeavyClickEffect)
          .shadow(ShadowStyle.OUTER_DEFAULT_MD)
          .transition(TransitionEffect.scale({
            x: 0, y: 0
          }).combine(TransitionEffect.OPACITY).animation(Spring035s))
          .onClick(() => {
            animateTo({
              duration: 300,
              curve: Curve.Friction,
              onFinish: () => {
                if (this.replyButtonExpand) {
                  const param: WriteReplyParam = {
                    defaultTransition: false,
                    tid: this.pageParam.tid,
                    mode: WriteReplyMode.NEW_POST,
                    subjectToReply: this.pageParam.subject
                  }
                  openWriteReply(this.pathStack, param, (data): void => this.onBackFromReply(data))
                }
              }
            }, () => {
              this.replyButtonExpand = true
            })
          })
        }
      }
    }
    .hideTitleBar(true)
    .onReady(async (context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const pageParam = context.pathInfo.param as ThreadPostParam
      if (pageParam.jumpToPage == undefined && pageParam.jumpToPid == undefined && pageParam.authorid == undefined) {
        const history = await QuerySingleViewHistory(pageParam.tid)
        if (history) {
          pageParam.jumpToPage = history.page
          pageParam.jumpToPid = String(history.pid)
          pageParam.replies = String(history.reply)
        }
      }
      this.pageParam = pageParam
      this.context.eventHub.on(openImgViewerEventName(this.pageParam),
        (imgUrl: string[], index: number) => {
          this.imgViewer = {
            urls: imgUrl,
            startAt: index
          }
          this.getUIContext().animateTo(Spring035s, () => {
            this.imgViewerShow = true
          })
        },)
    })
    .onShown(() => {
      if (this.replyButtonExpand) {
        this.getUIContext().animateTo(Spring035s, () => {
          this.replyButtonExpand = false
        })
      }
    })
    .onWillHide(() => {
      FlushThreadViewHistory(this.pageParam.tid)
    })
    .onBackPressed(() => {
      if (this.replyButtonExpand) {
        this.getUIContext().animateTo(Spring035s, () => {
          this.replyButtonExpand = false
        })
        return true
      }
      return false
    })
    .onWillDisappear(() => {
      FlushThreadViewHistory(this.pageParam.tid)
      this.context.eventHub.off(openImgViewerEventName(this.pageParam))
    })
    .bindContentCover($$this.imgViewerShow, this.ImageViewerBuilder, {
      modalTransition: ModalTransition.NONE,
      onWillDismiss: (() => {
        this.getUIContext().animateTo({ duration: 300 }, () => {
          this.imgViewerShow = false
        })
      }),
    })
  }

  onBackFromReply(data: PopInfo): void {
    if ((data.result as WriteReplyPopData)?.replied) {
      this.reloadCtrl.reload()
    }
  }

  @Builder
  ImageViewerBuilder() {
    Stack() {
      ImageViewer({
        param: this.imgViewer,
        showUp: this.imgViewerShow
      })
    }.transition(TransitionEffect.opacity(.999).animation({ duration: 300 })) // 避免退出时没有转场动画就直接消失
  }
}

const BOTTOM_LOADING_AREA = 80
const PULL_UP_LOADING_INTERVAL = 500 // ms

interface floorParam {
  menu: MenuElement[]
  floorNumber: string
}

@Component
struct SinglePostPage {
  @Consume totalPage: number
  @Consume('visiblePage') visiblePage: number
  @State threadNotExist: boolean = false
  @Consume @Watch('requestPostData') dataControlCounter: number
  context = getContext(this) as common.UIAbilityContext
  @Consume pageParam: ThreadPostParam
  @StorageProp(SafeArea.bottom) bottomRectHeight: number = 0
  @StorageProp(BLOCK_USER_LIST_STATE) blockList: Set<string> = new Set
  pageToLoad: number = 1
  imgUrl: string[] = []

  openImageViewer(imgUrl: string[], index: number) {
    this.context.eventHub.emit(openImgViewerEventName(this.pageParam), imgUrl, index)
  }

  loadingIcon?: SwipePageLoadingIcon
  @State threadAuthorUid: string = ''
  @StorageProp(PropKey.userId) currentUserUid?: string = undefined
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @Consume jumpToPost: string
  @Consume allowPullUpRefresh: boolean
  @Consume allowPullDownRefresh: boolean
  @Consume pageScrollOffset: Map<number, number>
  @State isLoading: boolean = true
  postDataSource: ArrayDataSource<PostViewModel> = new ArrayDataSource()
  postStringify: Map<string, string> = new Map
  @State postHidden: Map<string, UIRootNode[]> = new Map
  @State postHiddenExpand: boolean[] = []
  @State postFloorNumber: string[] = []
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  scroller: Scroller = new Scroller()
  @Consume refreshStage: PullToRefreshStage
  @State indexerFloorNum: string[] = []
  pidMap: string[] = [] // 列表组件索引 -> pid，用于记录浏览历史
  indexerFloorCompIndex: number[] = [] // indexer的索引 -> 列表组件索引， 用于快速跳转
  @State indexerFontSize: number = 10
  @State indexerCompSize: RectSize = {
    w: 0,
    h: 0
  }
  @State nowDate: Date = new Date()
  @State showBottomLoading: number = 0
  @State pollList: PollOptionVM[] = []
  @State pollInfo: PollInfoVM = {
    expirations: 0,
    maxchoices: 1,
    voterscount: '',
    visiblepoll: SpecialPollResultVisible.VISIBLE,
    allowvote: SpecialPollAllowVote.ALLOW
  }
  @Provide postRatingInfo: Map<string, ThreadRatingInfo | undefined> = new Map
  @State postAttachment: Map<string, Attachment[]> = new Map
  pullUpStartOffset: number = 0
  pullUpLoadingTs: number = 0

  generateSinglePageKey() {
    return `${this.pageToLoad},${this.dataControlCounter}`
  }

  pageLoadedKey: string = ''

  loadingBegin() {
    if (this.showBottomLoading == 0) {
      this.loadingIcon?.show(this.pageToLoad)
    }
    this.isLoading = true
  }

  loadingFinish() {
    this.isLoading = false
    this.loadingIcon?.hide(this.pageToLoad)
    const savedScrollOffset = this.pageScrollOffset.get(this.pageToLoad)
    if (savedScrollOffset) {
      this.scroller.scrollTo({
        yOffset: savedScrollOffset,
        xOffset: 0
      })
      this.pageScrollOffset.delete(this.pageToLoad)
    }
  }

  processPostListV4(v: wrapper<PostListV4>) {
    let rawPostList = v.Variables.postlist
    if (rawPostList.length == 0) {
      this.getUIContext().getPromptAction().showToast({
        message: v.Message.messagestr || '未获取到帖文内容'
      })
      this.threadNotExist = true
      this.loadingFinish()
    } else {
      this.indexerFloorNum = []

      this.postHidden.clear()
      this.postHiddenExpand = []
      const pageFloorStart = POST_PER_PAGE * (this.pageToLoad - 1)
      if (pageFloorStart >= 10000) {
        this.indexerFontSize = 8
      } else if (pageFloorStart >= 1000) {
        this.indexerFontSize = 9
      }
      const newPostFloorNumber: string[] = []
      rawPostList.forEach((p, i) => {
        if (p.attachments) {
          Object.values(p.attachments).forEach(attach => {
            if (attach.isimage === '0') {
              if (!this.postAttachment.has(p.pid)) {
                this.postAttachment.set(p.pid, [])
              }
              const attachList = this.postAttachment.get(p.pid)
              attachList!.push(attach)
            }
          })
        }
        if (p.groupid === '4') {
          parseXML([p]).forEach((root) => {
            const post = PostContentParser(root, [])
            this.postHidden.set(p.pid, post.node)
          })
        }
        newPostFloorNumber[i] = p.number || ''
        const floorNum = parseInt(p.number || '')
        if (!isNaN(floorNum)) {
          if (floorNum < pageFloorStart + 10 || floorNum % 2 == 0) {
            this.indexerFloorCompIndex[this.indexerFloorNum.length] = i
            this.indexerFloorNum.push(floorNum.toString())
          }
        }
      })
      this.postFloorNumber = newPostFloorNumber
    }
    const latestTitle = unescapeAll(v.Variables.thread.subject)
    if (this.pageParam.subject != latestTitle) {
      this.pageParam.subject = latestTitle
    }
    if (parseInt(this.pageParam.replies ?? '0') < parseInt(v.Variables.thread.replies)) {
      this.pageParam.replies = v.Variables.thread.replies
    }
    if (this.pageParam.fid === undefined) {
      this.pageParam.fid = v.Variables.thread.fid
    }
    this.threadAuthorUid = v.Variables.thread.authorid
    const postRating = new Map<string, ThreadRatingInfo | undefined>()
    Object.keys(v.Variables.comments).forEach(pid => postRating.set(pid, undefined))
    this.postRatingInfo = postRating
    if (this.pageToLoad == 1 && v.Variables.special_poll) {
      const pollData = v.Variables.special_poll
      this.pollInfo = getPollInfo(pollData)
      this.pollList = getPollList(pollData)
    }
  }

  processThreadDataApp(v: wrapperApp<ThreadDataApp>) {
    if (parseInt(this.pageParam.replies ?? '0') < v.data.totalCount) {
      this.pageParam.replies = String(v.data.totalCount)
    }
    let postArray: PostViewModel[] = []
    let rawPostList = v.data.list
    this.imgUrl = []
    this.postStringify.clear()
    parseXML(rawPostList).forEach((root, index) => {
      const post = PostContentParser(root, this.imgUrl)
      const vm: PostViewModel = {
        node: post.node,
        uid: rawPostList[index].authorid.toString(),
        username: rawPostList[index].author,
        pid: rawPostList[index].pid.toString(),
        timestamp: new Date(rawPostList[index].dateline * 1000),
        userCredit: rawPostList[index].e ?
          '(' + (rawPostList[index].e >= 0 ? '+' : '') + rawPostList[index].e.toString() + ')' : '(+0)'
      }
      this.postStringify.set(vm.pid, JSON.stringify(post.node))
      postArray.push(vm)
    })

    this.updatePostDatetime()
    rawPostList.forEach((p, i) => {
      this.pidMap[i] = p.pid.toString()
      if (this.jumpToPost == p.pid.toString()) {
        if (this.pageParam.jumpToPidWithHighlight) {
          setTimeout(() => {
            this.pageParam.jumpToPidWithHighlight = false
          }, 100)
        }
        setTimeout(() => {
          this.scroller.scrollToIndex(i, false, ScrollAlign.START)
          setTimeout((): void => this.scroller.scrollToIndex(i, false, ScrollAlign.START), 50)
          this.jumpToPost = ''
        }, 0)
      }
    })

    const lastUpdatePostCount = this.postDataSource.totalCount()
    if (this.postDataSource.totalCount() == 0) {
      animateTo({ duration: 150, curve: Curve.ExtremeDeceleration }, () => this.postDataSource.reload(postArray))
    } else {
      this.postDataSource.reload(postArray)
    }
    this.loadingFinish()
    this.pageLoadedKey = this.generateSinglePageKey()
    if (lastUpdatePostCount > 0 && postArray.length > lastUpdatePostCount) {
      setTimeout(() => {
        this.scroller.scrollBy(0, this.showBottomLoading * BOTTOM_LOADING_AREA)
        this.showBottomLoading = 0
      }, 20)
    } else {
      setTimeout(() => {
        animateTo(Spring035s, () => {
          this.showBottomLoading = 0
        })
      }, Math.max(0, PULL_UP_LOADING_INTERVAL - Date.now() + this.pullUpLoadingTs))
    }
  }

  requestPostData() {
    if (this.generateSinglePageKey() == this.pageLoadedKey) {
      return
    }
    this.loadingBegin()

    new request<wrapper<PostListV4>>(URL.THREAD_POST_LIST_V4)
      .param('tid', this.pageParam.tid)
      .param('page', this.pageToLoad.toString())
      .param('authorid', this.pageParam.authorid || '')
      .cache((v): void => this.processPostListV4(v), this.postDataSource.totalCount() > 0)
      .get()
      .then((v): void => this.processPostListV4(v))
      .catch((res: RequestError) => {
        if (res.type == 'Response') {
          if (res.data.statusCode == 404) {
            this.threadNotExist = true
          }
        }
      })
    new request<wrapperApp<ThreadDataApp>>(URL.THREAD_POST_APP, URL.APP_BASE)
      .appToken()
      .cache((v): void => this.processThreadDataApp(v), this.postDataSource.totalCount() > 0)
      .post({
        tid: this.pageParam.tid,
        pageNo: this.pageToLoad,
        uid: this.pageParam.authorid || ''
      })
      .then((v): void => this.processThreadDataApp(v))
  }

  postDatetimeUpdateTimer?: number

  updatePostDatetime() {
    this.nowDate = new Date()
  }

  aboutToAppear(): void {
    this.requestPostData()
    this.postDatetimeUpdateTimer = setInterval((): void => this.updatePostDatetime(), 60 * 1000)
  }

  aboutToDisappear(): void {
    clearInterval(this.postDatetimeUpdateTimer)
    const offset = this.scroller.currentOffset()
    if (offset) {
      this.pageScrollOffset.set(this.pageToLoad, offset.yOffset)
    }
  }

  onBackFromReply(data: PopInfo) {
    if ((data.result as WriteReplyPopData)?.replied) {
      this.dataControlCounter += 1
      this.updatePostDatetime()
    }
  }

  @Builder
  blockUserButton(uid: string, username: string) {
    Button(this.blockList.has(uid) ? '取消屏蔽' : '屏蔽', {
      buttonStyle: ButtonStyleMode.TEXTUAL
    }).onClick(() => {
      if (this.blockList.has(uid)) {
        UnblockUser(uid)
      } else {
        BlockUser(uid, username)
      }
    })
  }

  @Builder
  floorNumber(param: floorParam) {
    Text() {
      Span('#')
      Span(param.floorNumber).fontSize(FontSizeEnum[this.appState.fontSize].vp18).fontWeight(FontWeight.Medium)
    }
    .fontColor(this.appTheme.fontEmphasize)
    .fontFeature('"ss01" on')
    .padding({ right: 8 })
    .opacity(0.7)
    .fontWeight(FontWeight.Normal)
    .constraintSize({
      minWidth: 35
    })
    .textAlign(TextAlign.End)
    .clickEffect(HeavyClickEffect)
    .bindMenu(param.menu)
  }

  @LocalBuilder
  buildPostContent(nodes: UIRootNode[]) {
    ForEach(nodes, (uiRoot: UIRootNode) => {
      ThreadPostUINodeRender({
        uiRoot: uiRoot,
        appTheme: this.appTheme,
        fontSize: this.appState.fontSize,
        fontSizeOverride: this.appState.fontSizeOverride,
        copyOption: this.appState ? CopyOptions.LocalDevice : CopyOptions.None,
        onLinkClick: (href: string): void => {
          openS1LinkLike(href, this.pathStack, this.context, this.pageParam.subject,
            this.pageParam.replies)
        },
        onImgClick: (url: string, index: number): void => {
          this.openImageViewer(this.imgUrl, index)
        }
      })
    },
      (uiRoot: UIRootNode, index: number) => index.toString() + this.appState.fontSize + this.appState.fontSizeOverride)
  }

  build() {
    Stack() {
      List({ scroller: this.scroller }) {
        LazyForEach(this.postDataSource, (post: PostViewModel, postIndex: number) => {
          ListItem() {
            Column() {
              if (this.blockList.has(post.uid)) {
                Row({ space: 12 }) {
                  Row({ space: 12 }) {
                    Avatar({
                      uid: post.uid,
                      transitionIndex: postIndex.toString() + ',' + this.pageToLoad +
                      genThreadPostViewKey(this.pageParam),
                      avatarSize: 20
                    })
                    Text(post.username)
                      .opacity(.7)
                  }.onClick(() => {
                    const userSpaceParam: UserSpaceParam = {
                      uid: post.uid,
                      username: post.username,
                      avatarTransitionIndex: postIndex.toString() + ',' + this.pageToLoad +
                      genThreadPostViewKey(this.pageParam)
                    }
                    openUserSpace(userSpaceParam, this.pathStack)
                  })

                  Text('[已被屏蔽]').opacity(.7)
                  Blank()
                  this.floorNumber({
                    floorNumber: this.postFloorNumber[postIndex], menu: [{
                      value: '解除屏蔽',
                      action: () => {
                        UnblockUser(post.uid)
                      }
                    }]
                  })
                }.width('100%')
              } else {
                Row() {
                  Avatar({
                    uid: post.uid,
                    avatarSize: FontSizeEnum[this.appState.fontSize].vp40,
                    transitionIndex: postIndex.toString() + ',' + this.pageToLoad + genThreadPostViewKey(this.pageParam)
                  }).onClick(() => {
                    const userSpaceParam: UserSpaceParam = {
                      uid: post.uid,
                      username: post.username,
                      avatarTransitionIndex: postIndex.toString() + ',' + this.pageToLoad +
                      genThreadPostViewKey(this.pageParam)
                    }
                    openUserSpace(userSpaceParam, this.pathStack)
                  }).bindContextMenu(this.blockUserButton(post.uid, post.username), ResponseType.LongPress)
                    .draggable(false)
                    .clickEffect(HeavyClickEffect)
                  Column() {
                    Row({ space: 12 }) {
                      Text(post.username)
                        .fontWeight(FontWeight.Medium)
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                        .copyOption(this.appState.textCopyable ? CopyOptions.LocalDevice : CopyOptions.None)
                      if (this.appState.showCredit) {
                        Text(post.userCredit)
                          .fontSize(FontSizeEnum[this.appState.fontSize].vp13)
                          .opacity(0.7)
                      }
                      if (post.uid == this.threadAuthorUid) {
                        Text('楼')
                          .fontSize(FontSizeEnum[this.appState.fontSize].vp13)
                          .opacity(0.7)
                          .fontColor(this.appTheme.fontEmphasize)
                      }
                      Text('只看他').fontSize(FontSizeEnum[this.appState.fontSize].vp13).opacity(0.7)
                        .onClick(() => {
                          const param: ThreadPostParam = {
                            tid: this.pageParam.tid,
                            fid: this.pageParam.fid,
                            subject: this.pageParam.subject,
                            authorid: post.uid
                          }
                          openThreadPost(param, this.pathStack)
                        })
                    }.layoutWeight(1)
                    .alignSelf(ItemAlign.Stretch)
                    .alignItems(VerticalAlign.Center)

                    Text(formatRelativeTime(this.nowDate, post.timestamp))
                      .layoutWeight(1)
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      .alignSelf(ItemAlign.Stretch)
                      .fontColor($r('sys.color.font_tertiary'))
                  }.flexGrow(1)
                  .flexShrink(1)
                  .padding({ left: 12 })

                  Column() {
                    this.floorNumber({
                      floorNumber: this.postFloorNumber[postIndex], menu: [{
                        value: '回复',
                        action: () => {
                          if (!this.pageParam.subject) {
                            return
                          }
                          const param: WriteReplyParam = {
                            defaultTransition: true,
                            tid: this.pageParam.tid,
                            quotePid: post.pid,
                            mode: WriteReplyMode.NEW_POST_QUOTE,
                            subjectToReply: this.pageParam.subject
                          }
                          openWriteReply(this.pathStack, param, (data): void => this.onBackFromReply(data))
                        }
                      }, post.uid == this.currentUserUid ? {
                        value: '编辑',
                        action: () => {
                          if (!this.pageParam.subject) {
                            return
                          }
                          const param: WriteReplyParam = {
                            defaultTransition: true,
                            tid: this.pageParam.tid,
                            fid: this.pageParam.fid,
                            editPid: post.pid,
                            mode: WriteReplyMode.EDIT,
                            subjectToReply: this.pageParam.subject
                          }
                          openWriteReply(this.pathStack, param, (data): void => this.onBackFromReply(data))
                        }
                      } : {
                        value: '评分',
                        action: () => {
                          const param: PostRatingDetailParam = {
                            rating: [],
                            pid: post.pid,
                            tid: this.pageParam.tid,
                            userCount: 0,
                            totalRating: 0,
                            showPanel: true,
                            transitionId: generatePostRatingTransitionId(post.pid, this.pageToLoad,
                              this.generateSinglePageKey()),
                            reload: true
                          }
                          openPostRatingDetail(this.pathStack, param, () => {
                          })
                        }
                      }]
                    })
                  }.alignItems(HorizontalAlign.Start)
                  .height('100%')
                }.width('100%')
                .height(50)
                .margin({ bottom: 10 })

                if (!this.postHidden.has(post.pid) ||
                  this.appState.hiddenPostDisplay == HiddenPostDisplay.visibleWithoutHiddenReason) {
                  if (post.node.length > 0) {
                    this.buildPostContent(post.node)
                  } else if (this.postHidden.has(post.pid)) {
                    this.buildPostContent(this.postHidden.get(post.pid) || [])
                  }
                } else {
                  this.buildPostContent(this.postHidden.get(post.pid) || [])
                  if (this.appState.hiddenPostDisplay == HiddenPostDisplay.visible ||
                  this.postHiddenExpand[postIndex]) {
                    Column() {
                      if (post.node.length > 0) {
                        this.buildPostContent(post.node)
                      } else {
                        Text() {
                          ImageSpan($r('app.media.face_253_akarin'))
                            .width(FontSizeEnum[this.appState.fontSize].vp32)
                            .height(FontSizeEnum[this.appState.fontSize].vp32)
                          Span('(黑魔法的回应是空白)')
                        }.fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      }
                    }.border({
                      width: 2,
                      dashGap: {
                        value: 6,
                        unit: LengthUnit.VP
                      },
                      color: this.appTheme.fontEmphasize,
                      style: BorderStyle.Dashed,
                      radius: 12
                    }).padding(12)
                    .margin({ top: 8 })
                  } else {
                    Button('查看不可见内容')
                      .onClick(() => this.postHiddenExpand[postIndex] = true)
                      .buttonStyle(ButtonStyleMode.NORMAL)
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      .margin({ top: 8 })
                  }
                }

                if (this.pageToLoad == 1 && postIndex == 0 && this.pollList.length > 0 &&
                  this.pageParam.authorid === undefined) {
                  PollPanel({
                    pollList: this.pollList,
                    pollInfo: this.pollInfo,
                    tid: this.pageParam.tid,
                    compTransitionId: 'Vote' + this.generateSinglePageKey() + this.pageParam.tid
                  })
                }

                if (this.postAttachment.has(post.pid)) {
                  ForEach(this.postAttachment.get(post.pid), (attach: Attachment) => {
                    Row({ space: 12 }) {
                      Image($r('app.media.arrow_right_folder_circle')).width(26).height(26)
                        .fillColor(this.appTheme.fontEmphasize)
                      Column({ space: 6 }) {
                        Text(attach.filename)
                          .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                          .wordBreak(WordBreak.BREAK_ALL)
                        Text(`${attach.attachsize}   ${attach.downloads}次下载`)
                          .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
                          .opacity(.7)
                      }.flexGrow(100)
                      .flexShrink(1)
                      .alignItems(HorizontalAlign.Start)

                      Button('下载')
                        .buttonStyle(ButtonStyleMode.NORMAL)
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                        .onClick(() => {
                          DownloadFile(this.context, attach.filename,
                            URL.WEB_BASE + URL.ATTACHMENT_DOWNLOAD + attach.aidencode)
                        })
                    }
                    .backgroundColor(this.appTheme.backgroundTertiary)
                    .padding(12)
                    .borderRadius(12)
                    .alignItems(VerticalAlign.Center)
                    .width('100%')
                    .margin({ top: 8 })
                  }, (attach: Attachment) => attach.aid)
                }

                if (this.postRatingInfo.has(post.pid)) {
                  Divider().margin({ top: 20 })
                  PostRating({
                    pid: post.pid,
                    tid: this.pageParam.tid,
                    compTransitionId: generatePostRatingTransitionId(post.pid, this.pageToLoad,
                      this.generateSinglePageKey())
                  })
                }
              }
            }
            .backgroundColor(this.appTheme.backgroundSecondary)
            .padding({
              left: PostContentHorizontalPadding,
              top: PostContentVerticalPadding,
              bottom: PostContentVerticalPadding,
              right: PostContentHorizontalPadding + (this.appState.postAlphabetIndexer ? 6 : 0)
            })
            .brightness(this.pageParam.jumpToPid == post.pid && this.pageParam.jumpToPidWithHighlight ?
              (this.appTheme.isDark ? 1.1 : 0.9) : 1)
            .animation({ duration: 300, iterations: 2 })
            .margin({ bottom: 8 })
          }

        }, (post: PostViewModel, index: number) => this.postStringify.get(post.pid))
        ListItem() {
          BottomSafeArea()
        }
      }
      .enableScrollInteraction(this.refreshStage != PullToRefreshStage.pullDownBegin)
      .cachedCount(2)
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .backgroundColor(this.appTheme.backgroundTertiary)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.PARENT_FIRST
      })
      .opacity(this.isLoading ? 0.8 : 1)
      .edgeEffect(EdgeEffect.None)
      .onScrollVisibleContentChange((start: VisibleListContentInfo, end: VisibleListContentInfo) => {
        if (this.visiblePage == this.pageToLoad && this.isLoading == false && this.pageParam.authorid === undefined &&
        this.pageParam.subject && this.pageParam.replies) {
          RecordThreadViewHistory(this.pageParam.tid, this.pageParam.subject, this.pidMap[start.index], Date.now(),
            this.pageParam.replies, this.pageToLoad)
        }
      })
      .onTouch(this.pageToLoad == this.totalPage ? (event => {
        let newLoadingState = 0
        if (!this.scroller.isAtEnd() || !this.allowPullUpRefresh) {
          newLoadingState = 0
        } else {
          switch (event.type) {
            case TouchType.Down:
              this.pullUpStartOffset = event.touches[0].y
              break
            case TouchType.Move:
              newLoadingState =
                Math.min(1, Math.max(0, (event.touches[0].y - this.pullUpStartOffset) / -BOTTOM_LOADING_AREA))
              break
            case TouchType.Cancel:
              newLoadingState = 0
              break
            case TouchType.Up:
              if (this.showBottomLoading > 0.5) {
                newLoadingState = 1
                if (!this.isLoading && (Date.now() - this.pullUpLoadingTs) > PULL_UP_LOADING_INTERVAL) {
                  this.pullUpLoadingTs = Date.now()
                  this.dataControlCounter += 1
                }
              } else {
                newLoadingState = 0
              }
              break
            default:
              break
          }
        }
        animateTo(Spring035s, () => this.showBottomLoading = newLoadingState)
      }) : () => {
      })
      .translate({ y: this.showBottomLoading * -BOTTOM_LOADING_AREA })

      if (this.threadNotExist) {
        ErrorTips('404：帖子不存在')
      }
      if (this.appState.postAlphabetIndexer) {
        AlphabetIndexer({
          arrayValue: this.indexerFloorNum,
          selected: 0
        })
          .padding(6)
          .selectedBackgroundColor('#00000000')
          .color(this.appTheme.fontSecondary)
          .font({
            size: this.indexerFontSize
          })
          .selectedFont({
            size: this.indexerFontSize
          })
          .selectedColor(this.appTheme.fontSecondary)
          .offset({
            x: '50%'
          })
          .markAnchor({
            x: this.indexerCompSize.w
          })
          .itemSize(24)
          .onSizeChange((old, newSize) => {
            this.indexerCompSize.w = px2vp(parseInt(newSize.width as string))
          })
          .onSelect(index => {
            this.scroller.scrollToIndex(this.indexerFloorCompIndex[index])
          })
          .onTouch(e => {
            e.stopPropagation()
          })
      }
      if (this.showBottomLoading != 0) {
        Row() {
          LoadingProgress()
            .width(64)
            .height(64)
            .color($r('sys.color.ohos_id_color_emphasize'))
        }
        .alignItems(VerticalAlign.Top)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .position({ top: '100%' })
        .transition(TransitionEffect.OPACITY.animation({ duration: 100 }))
        .translate({ y: this.showBottomLoading * -BOTTOM_LOADING_AREA })
      }
    }.width('100%')
    .height('100%')
    .visibility(this.jumpToPost ? Visibility.Hidden : Visibility.Visible)
  }
}

@Builder
export function RegisterBuilder() {
  ThreadPostList()
}

export function openThreadPost(param: ThreadPostParam, pathStack: NavPathStack,
  tidAsKey: boolean = false, animated: boolean = true) {
  openOrJumpTo(pathStack, PageNameEnum.ThreadPostList, param, animated, (u: object) => {
    if (tidAsKey) {
      return (u as ThreadPostParam).tid == param.tid
    } else {
      return genThreadPostViewKey(u as ThreadPostParam) == genThreadPostViewKey(param)
    }
  })
}

async function resolveS1ThreadRedirectLink(href: string | undefined,
  succeed: (tid: string, page: number, pid?: string, authorId?: string) => void, failed: () => void) {
  if (href && DomainRegex.test(href)) {
    if (href.includes(URL.REDIRECT_TO_POST)) {
      if (href.includes(URL.DOMAIN_APP)) {
        href = href.replace(URL.DOMAIN_APP, URL.DOMAIN_WEB)
      }
      new request<string>(href, '')
        .redirectLocation()
        .get()
        .then(location => {
          const regex = /tid=(\d+)&page=(\d+)#pid(\d+)/
          const match = location.match(regex)
          if (match && match.length === 4) {
            succeed(match[1], parseInt(match[2]), match[3])
            return
          }
        })
        .catch(() => {
          failed()
        })
    } else {
      const weblink = resolveS1WebLink(href)
      if (weblink) {
        succeed(weblink.tid, weblink.page, undefined, weblink.authorId)
      } else {
        failed()
      }
    }
  } else {
    failed()
  }
}

export function openThreadPostByLink(href: string,
  pathStack: NavPathStack, onFailed: () => void, subject = '', replies = '1') {
  resolveS1ThreadRedirectLink(href, (tid: string, page: number, pid?: string, authorId?: string) => {
    const param: ThreadPostParam = {
      tid: tid,
      jumpToPid: pid,
      jumpToPage: page,
      subject: subject,
      replies: replies,
      jumpToPidWithHighlight: true,
      authorid: authorId
    }
    openThreadPost(param, pathStack)
  }, onFailed)
}

function generateS1WebPostLink(tid: string, page: number) {
  return `${URL.WEB_BASE}thread-${tid}-${page}-1.html`
}

function generatePostRatingTransitionId(pid: string, page: number, pageId: string) {
  return 'PostRating' + pid + pageId + page
}
