import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import request, { RequestError } from '../../api/request'
import { common } from '@kit.AbilityKit'
import { openThreadPost, ThreadOpenMotive, ThreadPostParam } from './ThreadPostList'
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
import { contentTextColor } from '../../common/component/preference/TextColorPref'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { ReloadController } from '../../common/BasicDataSource'
import { PropKey } from '../../common/Constants'
import { LengthUnit, promptAction } from '@kit.ArkUI'
import {
  FavoriteItem,
  LoadFavoriteCache,
  MergeFavoriteCache,
  RemoveFavoriteItem,
  SyncFavoriteList
} from '../../common/dataStore/FavoriteCache'

class FavoritePageUpdater {
  uid: string = ''
  onUpdated: (items: FavoriteItem[]) => void = () => {
  }

  report(page: number, items: FavoriteItem[]) {
    if (this.uid.length == 0 || items.length == 0) {
      return
    }
    MergeFavoriteCache(this.uid, page, items).then(merged => {
      if (merged != null) {
        this.onUpdated(merged)
      }
    })
  }
}

@Component
export struct FavoriteList {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  dataSource: PageIndexDataSource = new PageIndexDataSource(0)
  context = getContext(this) as common.UIAbilityContext
  reloadCtrl: ReloadController = new ReloadController()
  @Provide totalPage: number = 1
  @Provide favoritePageUpdater: FavoritePageUpdater = new FavoritePageUpdater()
  @State jumpToPage: number = -1
  @State currentPage: number = 1
  @State pullToRefreshEnabled: boolean = true
  @State searching: boolean = false
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
          if (!this.searching) {
            PageSlider({
              pageIndex: this.currentPage,
              totalPage: this.totalPage,
              doJump: page => this.jumpToPage = page
            })
          }
        }

        FavoriteSearchPanel({ searching: $searching })

        if (!this.searching) {
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
      }
    }.hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)

    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}


@Component
struct FavoriteSearchPanel {
  @Link searching: boolean
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @Consume favoritePageUpdater: FavoritePageUpdater
  @StorageProp(PropKey.userId) @Watch('onAccountUpdate') uid?: string = undefined
  @State keyword: string = ''
  @State searchFocused: boolean = false
  @State favoriteItems: FavoriteItem[] = []
  @State lastFetchAt: number = 0
  @State cacheLoaded: boolean = false
  @State syncing: boolean = false
  @State fetchedPages: number = 0
  @State totalPages: number = 0

  onAccountUpdate() {
    this.loadFavoriteCache()
  }

  aboutToAppear(): void {
    this.favoritePageUpdater.onUpdated = (items: FavoriteItem[]) => {
      this.favoriteItems = items
    }
    PreferenceManager.readonly(conf => {
      this.uid = conf.user_uid
      this.loadFavoriteCache()
    })
  }

  async loadFavoriteCache() {
    const uid = this.uid ?? ''
    this.favoritePageUpdater.uid = uid
    const cache = await LoadFavoriteCache(uid)
    this.favoriteItems = cache?.items ?? []
    this.lastFetchAt = cache?.fetchAt ?? 0
    this.cacheLoaded = true
    if (this.searchFocused && this.lastFetchAt == 0) {
      this.syncFavoriteCache()
    }
  }

  async syncFavoriteCache(manual: boolean = false) {
    if (this.syncing) {
      return
    }
    const uid = this.uid ?? ''
    if (uid.length == 0) {
      return
    }
    this.syncing = true
    this.fetchedPages = 0
    this.totalPages = 0
    try {
      const result = await SyncFavoriteList(uid, (page: number, totalPage: number) => {
        this.fetchedPages = page
        this.totalPages = totalPage
      })
      this.favoriteItems = result.items
      this.lastFetchAt = result.fetchAt
      if (manual) {
        let message = '本地已是最新状态'
        if (result.added > 0 && result.removed > 0) {
          message = `新增了 ${result.added} 条，移除了 ${result.removed} 条`
        } else if (result.added > 0) {
          message = `新增了 ${result.added} 条`
        } else if (result.removed > 0) {
          message = `移除了 ${result.removed} 条`
        }
        promptAction.showToast({
          message: message
        })
      }
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({
        message: '拉取收藏数据失败'
      })
    }
    this.syncing = false
  }

  filterFavorites(): FavoriteItem[] {
    const keyword = this.keyword.trim().toLowerCase()
    if (keyword.length == 0) {
      return []
    }
    return this.favoriteItems.filter(item => item.title.toLowerCase().includes(keyword))
  }

  removeFavoriteFromCache(favid: string) {
    this.favoriteItems = this.favoriteItems.filter(item => item.favid != favid)
    RemoveFavoriteItem(this.uid ?? '', favid)
  }

  build() {
    Column() {
      Row() {
        Search({ value: $$this.keyword, placeholder: '搜索帖子标题' })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.searching = value.length > 0
          })
          .onFocus(() => {
            this.searchFocused = true
            if (this.cacheLoaded && this.lastFetchAt == 0) {
              this.syncFavoriteCache()
            }
          })
          .onBlur(() => {
            this.searchFocused = false
          })
      }
      .width('100%')
      .padding({
        left: 12,
        right: 12,
        top: 8,
        bottom: 8
      })

      if (this.searchFocused || this.syncing) {
        Row() {
          Row() {
            Column({ space: 4 }) {
              Text('为搜索功能更新数据')
                .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                .fontColor($r('sys.color.font_primary'))
                .fontWeight(FontWeight.Medium)
              Text('新增收藏帖子后，无需主动更新记录，即可照常搜索。如果较久以前收藏下来的帖子被取消收藏，则需要进行数据更新')
                .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                .fontColor($r('sys.color.font_secondary'))
              if (this.syncing) {
                Text(this.totalPages > 0 ? `已拉取 ${this.fetchedPages}/${this.totalPages} 页` : '正在获取分页信息')
                  .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                  .fontColor($r('sys.color.font_secondary'))
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Button(this.syncing ? '数据拉取中…' : '更新')
              .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              .buttonStyle(ButtonStyleMode.NORMAL)
              .enabled(!this.syncing)
              .onClick(() => this.syncFavoriteCache(true))
          }
          .layoutWeight(1)
          .padding({ left: 18, right: 18, top: 12, bottom: 12 })
          .borderRadius(20)
          .backgroundColor(this.appTheme.backgroundTertiary)
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 12 })
      }

      if (this.keyword.length > 0) {
        FavoriteSearchList({
          items: this.filterFavorites(),
          onRemoved: (favid: string): void => this.removeFavoriteFromCache(favid)
        })
      }
    }
    .width('100%')
  }
}

@Component
struct FavItemEntry {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appState: PreferenceState
  @Consume appTheme: AppThemeColor
  item: FavoriteItem = {
    favid: '',
    id: '',
    title: '',
    replies: ''
  }
  onRemoved: () => void = () => {
  }

  removeFavError(msg: string) {
    this.getUIContext().getPromptAction().showToast({
      message: '移除收藏失败: ' + msg
    })
  }

  build() {
    LongPressDelete({
      transitionId: 'favItem_' + this.item.id,
      click: () => {
        const param: ThreadPostParam = {
          tid: this.item.id.toString(),
          subject: this.item.title,
          replies: this.item.replies.toString(),
        }
        openThreadPost(param, this.pathStack, ThreadOpenMotive.Content)
      },
      delete: () => {
        new request<wrapper<Account>>(URL.FAV_REMOVE)
          .formHash()
          .post({
            'favid': this.item.favid
          }).then(e => {
          if (e.Message.messageval.includes('success')) {
            this.onRemoved()
          } else {
            this.removeFavError(e.Message.messageval)
          }
        }).catch((err: RequestError) => {
          if (err.type == 'Response') {
            this.removeFavError(err.data.statusCode.toString())
          } else if (err.type == 'BusinessError') {
            this.removeFavError(String(err.data.data) || '')
          }
        })
      }
    }) {
      Text(this.item.title)
        .textAlign(TextAlign.Start)
        .flexGrow(1)
        .flexShrink(1)
        .fontColor(contentTextColor(this.appState, this.appTheme.isDark))
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
  }
}

@Component
struct FavoriteSearchList {
  @Prop @Require items: FavoriteItem[]
  onRemoved: (favid: string) => void = () => {
  }

  build() {
    List() {
      ForEach(this.items, (item: FavoriteItem) => {
        ListItem() {
          Column() {
            FavItemEntry({
              item: item,
              onRemoved: () => this.onRemoved(item.favid)
            })
          }.alignItems(HorizontalAlign.Start)
        }.width('100%')
      }, (item: FavoriteItem) => item.id)
      ListItem() {
        BottomSafeArea()
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .constraintSize({
      minHeight: '100%'
    })
    .nestedScroll({
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.PARENT_FIRST
    })
  }
}

@Component
struct SingleFavPage {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume @Watch('requestPostData') dataControlCounter: number
  pageToLoad: number = 1
  loadingIcon?: SwipePageLoadingIcon
  @Consume totalPage: number
  @Consume appState: PreferenceState
  @Consume appTheme: AppThemeColor
  @Consume favoritePageUpdater: FavoritePageUpdater
  @State favItem: FavoriteItem[] = []

  aboutToAppear(): void {
    this.requestPostData()
  }

  processFavList(v: wrapper<FavList>, fromCache: boolean = false) {
    if (v.Variables.list != null && v.Variables.count != null && v.Variables.perpage != null) {
      const items = v.Variables.list!.map(fav => ({
        favid: fav.favid,
        id: fav.id,
        title: fav.title,
        replies: fav.replies
      } as FavoriteItem))
      animateTo(SpringCurve, () => {
        this.totalPage = Math.ceil(parseInt(v.Variables.count!) / parseInt(v.Variables.perpage!))
        this.favItem = items
      })
      if (!fromCache) {
        this.favoritePageUpdater.report(this.pageToLoad, items)
      }
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
      .cache((v): void => this.processFavList(v, true), this.favItem.length > 0)
      .get()
      .then((v): void => this.processFavList(v))
  }

  build() {
    Column() {
      ForEach(this.favItem, (item: FavoriteItem, compIndex: number) => {
        FavItemEntry({
          item: item,
          onRemoved: () => {
            this.dataControlCounter += 1
          }
        })
      }, (item: FavoriteItem, compIndex: number) => item.id)
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
