import request from '../../api/request'
import { URL } from '../../api/base'
import { ThreadList, ThreadtypeRecord } from '../../api/model/threadList'
import wrapper from '../../api/wrapper'
import { ForumInfo } from '../../api/model/forumGroup'
import { SwipePageLoadingIcon, SwipePageViewer } from '../../common/component/SwipePageViewer'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { common } from '@kit.AbilityKit'
import { AppearDisappearAni, ClickDarkenEffect, HeavyClickEffect, OpacityTransition } from '../../common/Animation'
import { openThreadPost, ThreadPostParam } from '../NavDest/ThreadPostList'
import { Event } from '../../common/Events'
import { unescapeAll } from '../../common/XmlParser'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageSlider } from '../../common/component/PageSlider'
import { PreferenceManager } from '../../config/UserConfig'
import { ForumThreadDisplayOrder } from '../../api/model/thread'
import { QueryThreadReplyCount } from '../../common/dataStore/HistoryData'
import { openWriteReply, WriteReplyMode, WriteReplyParam } from '../NavDest/WriteReply'
import { BLOCK_USER_LIST_STATE } from '../../common/dataStore/BlockUser'
import { PreferenceState } from './NavigationPage'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { openInBrowser } from '../../common/WantUitl'
import { ReloadController } from '../../common/BasicDataSource'
import { PropKey } from '../../common/Constants'

export const THREAD_PER_PAGE = 50

interface ThreadTypeItemViewData {
  typeid: string,
  name: string
}

interface ThreadListItemViewData {
  subject: string,
  replies: string,
  typeName: string,
  tid: string,
  uid: string,
  readperm: number
}

@Component
export struct ThreadListView {
  context = getContext(this) as common.UIAbilityContext
  @Consume @Watch('onForumInfoUpdate') forumInfo?: ForumInfo
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @State threadTypes: ThreadTypeItemViewData[] = [{
    typeid: "",
    name: "全部"
  }]
  @Provide threadTypeFilter: string = ""
  @Provide threadReadAccess: number = 0
  @Provide forumId: string = ""
  @Provide sublist: ForumInfo[] = []
  @State currentPage: number = 1
  @State displayPage: number = 1
  @State totalPage: number = 1
  @State jumpToPage: number = -1
  @State pullToRefreshEnabled: boolean = true
  @StorageProp(PropKey.userId) @Watch('onAccountUpdate') uid?: string = undefined
  loadingIcon?: SwipePageLoadingIcon
  reloadCtrl: ReloadController = new ReloadController()

  onForumInfoUpdate() {
    this.forumId = this.forumInfo?.fid || ""
    let threadCount: number
    if (this.forumInfo?.threadcount) {
      threadCount = parseInt(this.forumInfo?.threadcount || '0')
    } else {
      threadCount = parseInt(this.forumInfo?.threads || '0')
    }
    this.totalPage = Math.ceil(threadCount / THREAD_PER_PAGE)
  }

  processThreadTypes(threadTypesData: ThreadtypeRecord) {
    let types = Object.keys(threadTypesData)
    if (types.length + 1 == this.threadTypes.length) {
      return
    }
    types.forEach(tid => {
      this.threadTypes.push({
        typeid: tid,
        name: threadTypesData[tid]
      })
    })
  }

  onAccountUpdate() {
    this.reloadCtrl.reload()
    this.loadReadAccess()
  }

  loadReadAccess() {
    PreferenceManager.readonly(conf => {
      this.threadReadAccess = conf.readaccess
    })
  }

  aboutToAppear(): void {
    this.onForumInfoUpdate()
    this.context.eventHub.on(Event.ThreadTypesInit, (v: ThreadtypeRecord): void => this.processThreadTypes(v))
    this.loadReadAccess()
  }

  @Builder
  threadPageContent(page: number, index: number, loadingIcon: SwipePageLoadingIcon) {
    ThreadListPage({
      pageToLoad: page,
      loadingIcon
    })
  }

  @Builder
  sublistMenu() {
    Menu() {
      MenuItemGroup({ header: '前往子板块' }) {
        ForEach(this.sublist, (item: ForumInfo) => {
          MenuItem({
            content: item.name
          }).onClick(e => {
            this.forumInfo = item
            setTimeout(() => this.reloadCtrl.reload())
          })
        })
      }
    }
  }

  build() {
    OuterScroller({
      onEnterAndLeaveTop: atTop => this.pullToRefreshEnabled = atTop
    }) {
      TitleBar({
        titleContent: `${this.forumInfo?.name || ""}`,
        clickLeftButton: () => {
          this.forumInfo = undefined
        },
        menu: [{
          value: '从浏览器中打开',
          action: () => {
            openInBrowser(this.context, URL.WEB_BASE + `forum-${this.forumId}-${this.currentPage}.html`)
          }
        }, {
          value: '前往指定帖子',
          action: () => {
            this.context.eventHub.emit(Event.OpenGotoThreadDialog)
          }
        }]
      }) {
        if (this.sublist.length > 0) {
          Stack() {
            Image($r('app.media.satellite_map')).width(28).height(28)
              .fillColor(this.appTheme.titleBarFont)
          }
          .width(50)
          .height(50)
          .clickEffect(HeavyClickEffect)
          .bindMenu(this.sublistMenu)
          .transition(TransitionEffect.OPACITY.animation({ duration: 100 }))
        }
        Stack() {
          Image($r('app.media.square_and_pencil')).width(24).height(24)
            .fillColor(this.appTheme.titleBarFont)
        }
        .width(50)
        .height(50)
        .clickEffect(HeavyClickEffect)
        .transition(TransitionEffect.OPACITY.animation({ duration: 100 }))
        .onClick(() => {
          const param: WriteReplyParam = {
            defaultTransition: true,
            tid: '',
            subjectToReply: '',
            fid: this.forumInfo?.fid || '0',
            mode: WriteReplyMode.NEW_THREAD
          }
          openWriteReply(this.pathStack, param, () => {
          })
        })

        PageSlider({
          pageIndex: this.currentPage,
          totalPage: this.totalPage,
          doJump: page => {
            this.jumpToPage = page
          },
          hideTotal: true
        })
      }

      if (this.threadTypes.length > 1) {
        Tabs({ barPosition: BarPosition.Start }) {
          ForEach(this.threadTypes, (item: ThreadTypeItemViewData, index: number) => {
            TabContent() {
            }.tabBar(SubTabBarStyle.of(item.name)
              .labelStyle({ selectedColor: this.appTheme.fontEmphasize })
              .indicator({
                color: this.appTheme.fontEmphasize
              })
            )
          }, (item: ThreadTypeItemViewData) => item.typeid)
        }
        .barBackgroundColor(this.appTheme.backgroundSecondary)
        .barMode(BarMode.Scrollable)
        .scrollable(false)
        .barHeight(56)
        .height('auto')
        .animation({ duration: 50 })
        .onContentWillChange((currentIndex: number, index: number) => {
          if (this.threadTypes[index]) {
            this.threadTypeFilter = this.threadTypes[index].typeid
            this.reloadCtrl.reload()
          }
          return true
        })
      }
      SwipePageViewer({
        enablePullToRefresh: this.pullToRefreshEnabled,
        currentPage: this.currentPage,
        contentBuilder: this.threadPageContent,
        jumpToPage: this.jumpToPage,
        reloadCtrl: this.reloadCtrl,
        maxPage: this.totalPage
      })
    }
  }
}

@Component({ freezeWhenInactive: true })
@Reusable
struct ThreadListPage {
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @Consume forumInfo?: ForumInfo
  context = getContext(this) as common.UIAbilityContext
  clickEffectModifier: AttributeModifier<CommonAttribute> = new ClickDarkenEffect()
  pageLoadedKey: string = ''
  @Prop @Watch('requestPageData') pageToLoad: number
  @Consume @Watch('requestPageData') dataControlCounter: number
  @Consume threadTypeFilter: string
  @Consume forumId: string
  @Consume sublist: ForumInfo[]
  @Consume threadReadAccess: number
  @State threadList: ThreadListItemViewData[] = []
  @State dataLoading: boolean = false
  @State threadNewReplyCount: Map<string, string> = new Map
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  loadingIcon?: SwipePageLoadingIcon
  @StorageProp(BLOCK_USER_LIST_STATE) blockList: Set<string> = new Set

  aboutToAppear(): void {
    this.requestPageData()
  }

  aboutToReuse(): void {
    if (this.generatePageKey() != this.pageLoadedKey) {
      this.threadList = []
    }
    this.requestPageData()
  }

  generatePageKey() {
    return `${this.pageToLoad},${this.dataControlCounter},${this.threadTypeFilter}`
  }

  async processThreadList(v: wrapper<ThreadList>) {
    if (this.forumInfo && v.Variables.forum.threadcount != this.forumInfo?.threadcount) {
      this.forumInfo.threadcount = v.Variables.forum.threadcount
    }
    if (this.sublist.length != v.Variables.sublist.length) {
      this.sublist = v.Variables.sublist
    }
    if (this.pageToLoad == 1) {
      let showTopList: boolean = true
      await PreferenceManager.readonly(conf => showTopList = conf.show_top_thread)
      if (!showTopList) {
        v.Variables.forum_threadlist =
          v.Variables.forum_threadlist.filter(v => v.displayorder != ForumThreadDisplayOrder.top)
      }
    }
    let threadTypeNameMap = v.Variables.threadtypes.types
    this.context.eventHub.emit(Event.ThreadTypesInit, threadTypeNameMap)
    let viewData = v.Variables.forum_threadlist.map(v => {
      let readAccess = parseInt(v.readperm)
      readAccess = isNaN(readAccess) ? 0 : readAccess
      let t: ThreadListItemViewData = {
        subject: unescapeAll(v.subject),
        replies: v.replies,
        typeName: threadTypeNameMap[v.typeid] || '',
        tid: v.tid,
        uid: v.authorid,
        readperm: readAccess
      }
      return t
    })
    if (this.threadList.length > 0) {
      const tidSet: Set<string> = new Set()
      this.threadList.forEach(t => tidSet.add(t.tid))
      if (viewData.filter(t => tidSet.has(t.tid)).length > THREAD_PER_PAGE * 0.1) {
        animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
          this.threadList = viewData
        })
      } else {
        this.threadList = viewData
      }
    } else {
      this.threadList = viewData
    }
    this.loadingIcon?.hide(this.pageToLoad)
    this.dataLoading = false
    QueryThreadReplyCount(v.Variables.forum_threadlist.map(v => parseInt(v.tid))).then(viewedThread => {
      const threadWithReplyCount = new Set<string>()
      v.Variables.forum_threadlist.forEach(v => {
        if (viewedThread[v.tid]) {
          const replies = parseInt(v.replies) + 1 // v.replies没有计入主楼，而数据库记录的回帖数把主楼计入了，需要+1来匹配
          const newCount = replies - viewedThread[v.tid]
          const newCountStr = newCount.toString()
          if (!isNaN(newCount) && newCount >= 0) {
            if (this.threadNewReplyCount.get(v.tid) !== newCountStr) {
              this.threadNewReplyCount.set(v.tid, newCountStr)
            }
            threadWithReplyCount.add(v.tid)
          }
        }
      })
      for(const tid of this.threadNewReplyCount.keys()) {
        if (!threadWithReplyCount.has(tid)) {
          this.threadNewReplyCount.delete(tid)
        }
      }
    })
    return v
  }

  requestPageData() {
    if (this.generatePageKey() == this.pageLoadedKey) {
      this.loadingIcon?.hide(this.pageToLoad)
      return
    }
    this.loadingIcon?.show(this.pageToLoad)
    this.pageLoadedKey = this.generatePageKey()
    this.dataLoading = true
    let requestPageIndex = this.pageToLoad.toString()
    return new request<wrapper<ThreadList>>(URL.FORUM_THREAD_LIST)
      .param('fid', this.forumId)
      .param('page', requestPageIndex)
      .param('typeid', this.threadTypeFilter)
      .param('tpp', THREAD_PER_PAGE.toString())
      .cache((v): Promise<wrapper<ThreadList>> => this.processThreadList(v),
        this.threadList.length > 0 && this.generatePageKey() == this.pageLoadedKey)
      .get()
      .then((v): Promise<wrapper<ThreadList>> => this.processThreadList(v))
  }

  build() {
    Stack() {
      Column() {
        Repeat(this.threadList)
          .each(threadInfo => {
            Row() {
              Text() {
                if (threadInfo.item.typeName.length > 0) {
                  Span(`[${threadInfo.item.typeName}] `)
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                }
                Span(threadInfo.item.subject)
                if (threadInfo.item.readperm) {
                  Span(` [阅读权限${threadInfo.item.readperm}] `)
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp13)
                }
                if (this.blockList.has(threadInfo.item.uid)) {
                  Span(` [在黑名单中] `)
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp13)
                }
                Span('   ' + threadInfo.item.replies)
                  .fontColor(this.appTheme.fontEmphasize)
                if (this.threadNewReplyCount.has(threadInfo.item.tid)) {
                  Span(` (+${this.threadNewReplyCount.get(threadInfo.item.tid)})`)
                    .fontColor(this.appTheme.fontEmphasize).transition(OpacityTransition)
                }
              }.fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              .width('100%')
              .padding({
                left: 18,
                right: 18,
                top: 9,
                bottom: 9
              })
            }
            .enabled(this.threadReadAccess >= threadInfo.item.readperm)
            .opacity(this.threadReadAccess >= threadInfo.item.readperm && !this.blockList.has(threadInfo.item.uid) ? 1 :
              0.6)
            .height('auto')
            .width('100%')
            .geometryTransition('thread_item' + this.pageToLoad + '_' + threadInfo.item.tid, { follow: true })
            .transition(AppearDisappearAni)
            .attributeModifier(this.clickEffectModifier)
            .clickEffect({
              level: ClickEffectLevel.MIDDLE,
              scale: 0.9
            })
            .gesture(LongPressGesture().onAction(e => {
              const param: ThreadPostParam = {
                tid: threadInfo.item.tid,
                jumpToPage: -1,
                subject: threadInfo.item.subject,
                replies: threadInfo.item.replies,
              }
              openThreadPost(param, this.pathStack, true)
            }))
            .onClick(e => {
              const param: ThreadPostParam = {
                tid: threadInfo.item.tid,
                subject: threadInfo.item.subject,
                replies: threadInfo.item.replies,
              }
              openThreadPost(param, this.pathStack, true)
            })
          })
          .key(item => item.tid + item.replies)
        BottomSafeArea()
      }.opacity(this.dataLoading ? 0.6 : 1)
      .animation({ duration: 100 })
      .constraintSize({
        minHeight: '100%'
      })
    }
  }
}