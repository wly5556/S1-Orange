import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import request from '../../api/request'
import { common } from '@kit.AbilityKit'
import { PageIndexDataSource, SwipePageLoadingIcon, SwipePageViewer } from '../../common/component/SwipePageViewer'
import { PageSlider } from '../../common/component/PageSlider'
import wrapper from '../../api/wrapper'
import { URL } from '../../api/base'
import { PreferenceManager } from '../../config/UserConfig'
import { ErrorTips } from '../../common/component/ErrorTips'
import { HeavyClickEffect, SpringCurve } from '../../common/Animation'
import { PrivateMessageList } from '../../api/model/privateMessage'
import { Avatar } from '../../common/component/Avatar'
import { formatRelativeTime } from '../../common/TimeFormat'
import { openPmDetail, PmDetailParam } from './PrivateMessageDetail'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { ReloadController } from '../../common/BasicDataSource'
import { PropKey } from '../../common/Constants'

@Component
export struct PrivateMessageViewer {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  dataSource: PageIndexDataSource = new PageIndexDataSource(0)
  context = getContext(this) as common.UIAbilityContext
  reloadCtrl: ReloadController = new ReloadController()
  @Provide totalPage: number = 1
  @State jumpToPage: number = -1
  @State currentPage: number = 1
  @State pullToRefreshEnabled: boolean = true
  @StorageProp(PropKey.userId) @Watch('onAccountUpdate') uid?: string = undefined

  onAccountUpdate() {
    this.reloadCtrl.reload()
  }

  @Provide nowDate: Date = new Date()
  dateInterval: number = 0

  popBack() {
    this.pathStack.pop()
  }

  aboutToAppear(): void {
    this.dateInterval = setInterval(() => {
      this.nowDate = new Date()
    }, 60000)
    PreferenceManager.readonly(conf => {
      this.uid = conf.user_uid
    })
  }

  aboutToDisappear(): void {
    clearInterval(this.dateInterval)
  }

  @Builder
  contentBuilder(page: number, index: number, loadingIcon: SwipePageLoadingIcon) {
    PrivateMessagePage({
      pageToLoad: page,
      loadingIcon
    })
  }

  build() {
    NavDestination() {
      OuterScroller({
        onEnterAndLeaveTop: atTop => this.pullToRefreshEnabled = atTop
      }) {
        TitleBar({
          titleContent: `私信`,
          clickLeftButton: () => {
            this.popBack()
          },
          menu: [{
            value: '刷新',
            action: () => this.reloadCtrl.reload()
          }]
        }) {
          PageSlider({
            pageIndex: this.currentPage,
            totalPage: this.totalPage,
            doJump: page => this.jumpToPage = page
          })
        }

        if (this.uid) {
          SwipePageViewer({
            enablePullToRefresh: this.pullToRefreshEnabled,
            currentPage: this.currentPage,
            contentBuilder: this.contentBuilder,
            reloadCtrl: this.reloadCtrl,
            jumpToPage: this.jumpToPage,
            maxPage: this.totalPage
          }).backgroundColor(this.appTheme.backgroundSecondary)
        } else {
          Column() {
            ErrorTips('请先登录')
          }.backgroundColor(this.appTheme.backgroundSecondary)
          .width('100%')
          .height('100%')
        }
      }
    }.hideTitleBar(true)

    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

interface PmListItem {
  plid: string
  touid: string
  tousername: string
  pmnum: string
  lastdateline: Date
  lastauthor: string
  lastsummary: string
  isnew: string
}

@Component
struct PrivateMessagePage {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume @Watch('requestPostData') dataControlCounter: number
  pageToLoad: number = 1
  loadingIcon?: SwipePageLoadingIcon
  @Consume totalPage: number
  @Consume nowDate: Date
  @State pmItem: PmListItem[] = []
  @Consume appState: PreferenceState

  aboutToAppear(): void {
    this.requestPostData()
  }

  requestPostData() {
    this.loadingIcon?.show(this.pageToLoad)
    new request<wrapper<PrivateMessageList>>(URL.PM_LIST)
      .param('page', this.pageToLoad.toString())
      .get()
      .then(v => {
        if (v.Variables.list != null && v.Variables.count != null && v.Variables.perpage != null) {
          animateTo(SpringCurve, () => {
            this.totalPage = Math.ceil(parseInt(v.Variables.count!) / parseInt(v.Variables.perpage!))
            this.pmItem = v.Variables.list!.map(pm => ({
              plid: pm.plid,
              touid: pm.touid,
              tousername: pm.tousername,
              pmnum: pm.pmnum,
              lastdateline: new Date(parseInt(pm.lastdateline) * 1000),
              lastauthor: pm.lastauthor,
              lastsummary: pm.lastsummary,
              isnew: pm.isnew
            } as PmListItem))
          })
        } else {
          this.pmItem = []
          this.totalPage = 1
        }
        this.loadingIcon?.hide(this.pageToLoad)
      })
  }

  build() {
    Column({ space: 12 }) {
      ForEach(this.pmItem, (item: PmListItem, compIndex: number) => {
        Row({ space: 12 }) {
          Stack() {
            Avatar({
              uid: item.touid,
              avatarSize: 46
            })
            if (item.isnew === '1') {
              Stack()
                .width(12)
                .height(12)
                .borderRadius(6)
                .backgroundColor(Color.Red)
                .position({
                  top: 0,
                  right: 0
                })
            }
          }.width(46)
          .height(46)

          Column({ space: 12 }) {
            Flex({
              wrap: FlexWrap.Wrap,
              justifyContent: FlexAlign.SpaceBetween
            }) {
              Text(item.tousername).fontSize(FontSizeEnum[this.appState.fontSize].vp18)
              Text() {
                Span(`${item.pmnum}条 · `)
                Span(formatRelativeTime(this.nowDate, item.lastdateline))
              }.fontSize(FontSizeEnum[this.appState.fontSize].vp14).opacity(.6)
            }

            Text() {
              if (item.lastauthor == item.tousername) {
                Span(item.lastauthor + ': ')
              }
              Span(item.lastsummary)
            }.opacity(.7)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          }.flexGrow(1)
          .flexShrink(1)
        }.width('100%')
        .padding(12)
        .clickEffect(HeavyClickEffect)
        .onClick(() => {
          const param: PmDetailParam = {
            touid: item.touid,
            tousername: item.tousername
          }
          openPmDetail(this.pathStack, param)
        })
      }, (item: PmListItem, compIndex: number) => item.plid)
      BottomSafeArea()
    }.constraintSize({
      minHeight: '100%'
    })
    .alignItems(HorizontalAlign.Start)
  }
}


@Builder
export function RegisterBuilder() {
  PrivateMessageViewer()
}

export function openPrivateMessage(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.PrivateMessage)
}