import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import request, { RequestError } from '../../api/request'
import { common } from '@kit.AbilityKit'
import { openThreadPost, ThreadPostParam } from './ThreadPostList'
import { PageIndexDataSource, SwipePageLoadingIcon, SwipePageViewer } from '../../common/component/SwipePageViewer'
import { PageSlider } from '../../common/component/PageSlider'
import wrapper from '../../api/wrapper'
import { FavList } from '../../api/model/favlist'
import { URL } from '../../api/base'
import { PreferenceManager } from '../../config/UserConfig'
import { ErrorTips } from '../../common/component/ErrorTips'
import { SpringCurve } from '../../common/Animation'
import Account from '../../api/model/account'
import { LongPressDelete } from '../../common/component/LongPressDelete'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { ReloadController } from '../../common/BasicDataSource'
import { PropKey } from '../../common/Constants'
import { LengthUnit } from '@kit.ArkUI'

@Component
export struct FavoriteList {
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

  popBack() {
    this.pathStack.pop()
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.uid = conf.user_uid
    })
  }

  @Builder
  contentBuilder(page: number, index: number, loadingIcon: SwipePageLoadingIcon) {
    SingleFavPage({
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
          titleContent: `收藏`,
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

interface FavItemVM {
  favid: string
  id: string // tid
  title: string
  dateline: string
  replies: string
  author: string
}

@Component
struct SingleFavPage {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume @Watch('requestPostData') dataControlCounter: number
  pageToLoad: number = 1
  loadingIcon?: SwipePageLoadingIcon
  @Consume totalPage: number
  @Consume appState: PreferenceState
  @State favItem: FavItemVM[] = []

  aboutToAppear(): void {
    this.requestPostData()
  }

  processFavList(v: wrapper<FavList>) {
    if (v.Variables.list != null && v.Variables.count != null && v.Variables.perpage != null) {
      animateTo(SpringCurve, () => {
        this.totalPage = Math.ceil(parseInt(v.Variables.count!) / parseInt(v.Variables.perpage!))
        this.favItem = v.Variables.list!.map(fav => ({
          favid: fav.favid,
          id: fav.id,
          title: fav.title,
          dateline: fav.dateline,
          replies: fav.replies,
          author: fav.author
        } as FavItemVM))
      })
    } else {
      this.favItem = []
      this.totalPage = 1
    }
    this.loadingIcon?.hide(this.pageToLoad)
  }

  requestPostData() {
    this.loadingIcon?.show(this.pageToLoad)
    new request<wrapper<FavList>>(URL.FAVLIST)
      .param('page', this.pageToLoad.toString())
      .cache((v): void => this.processFavList(v), this.favItem.length > 0)
      .get()
      .then((v): void => this.processFavList(v))
  }

  removeFavError(msg: string, itemId: string) {
    this.getUIContext().getPromptAction().showToast({
      message: '移除收藏失败: ' + msg
    })
  }

  build() {
    Column() {
      ForEach(this.favItem, (item: FavItemVM, compIndex: number) => {
        LongPressDelete({
          transitionId: 'favItem_' + item.id,
          click: () => {
            const param: ThreadPostParam = {
              tid: item.id.toString(),
              subject: item.title,
              replies: item.replies.toString(),
            }
            openThreadPost(param, this.pathStack, true)
          },
          delete: () => {
            new request<wrapper<Account>>(URL.FAV_REMOVE)
              .formHash()
              .post({
                'favid': item.favid
              }).then(e => {
              if (e.Message.messageval.includes('success')) {
                this.dataControlCounter += 1
              } else {
                this.removeFavError(e.Message.messageval, item.id)
              }
            }).catch((err: RequestError) => {
              if (err.type == 'Response') {
                this.removeFavError(err.data.statusCode.toString(), item.id)
              } else if (err.type == 'BusinessError') {
                this.removeFavError(String(err.data.data) || '', item.id)
              }
            })
          }
        }) {
          Text(item.title)
            .textAlign(TextAlign.Start)
            .flexGrow(1)
            .flexShrink(1)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .lineSpacing({
              value: this.appState.contentLineSpace,
              unit: LengthUnit.VP
            })
            .padding({
              left: 18,
              right: 18,
              top: this.appState.threadItemGap,
              bottom: this.appState.threadItemGap
            })
        }
      }, (item: FavItemVM, compIndex: number) => item.id)
      BottomSafeArea()
    }.constraintSize({
      minHeight: '100%'
    })
    .alignItems(HorizontalAlign.Start)
  }
}


@Builder
export function RegisterBuilder() {
  FavoriteList()
}

export function openFavoriteList(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.FavoriteList)
}