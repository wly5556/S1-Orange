import { BasicDataSource, ReloadController } from '../BasicDataSource';
import { PullToRefresh, PullToRefreshStage } from './PullToRefresh';

export class PageIndexDataSource extends BasicDataSource<number> {
  private pageCount: number

  constructor(pageCount: number) {
    super();
    this.pageCount = pageCount
  }

  public setPageCount(count: number) {
    this.pageCount = count
    this.notifyDataReload()
  }

  public totalCount(): number {
    return this.pageCount
  }

  public getData(index: number): number {
    return (index + 1)
  }
}

export interface SwipePageLoadingIcon {
  show: (page: number) => void
  hide: (page: number) => void
}

@Component
export struct SwipePageViewer {
  @Prop @Require @Watch('maxPageUpdate') maxPage: number
  @Prop @Require enablePullToRefresh: boolean
  dataSource: PageIndexDataSource = new PageIndexDataSource(this.maxPage)
  cacheCount: number = 1
  @Link currentPage: number
  @Prop @Watch('requestJump') jumpToPage: number = -1
  @State currentSwiperIndex: number = 0
  @State swiperDisabled: boolean = false
  @State contentReady: Record<number, boolean> = {}
  @Provide dataControlCounter: number = 0
  @Provide @Watch('pullDownStageChanged') refreshStage: PullToRefreshStage = PullToRefreshStage.unactivated
  reloadCtrl: ReloadController = new ReloadController()
  useList: boolean = false

  maxPageUpdate() {
    this.dataSource.setPageCount(this.maxPage)
  }

  requestJump() {
    if (this.jumpToPage > 0 && this.jumpToPage <= this.maxPage) {
      this.currentSwiperIndex = this.jumpToPage - 1
      this.currentPage = this.jumpToPage
      this.jumpToPage = -1
    }
  }

  aboutToAppear(): void {
    this.requestJump()
    this.reloadCtrl.reload = (): void => this.allContentReload()
  }

  pullDownStageChanged() {
    if (this.refreshStage == PullToRefreshStage.pullDownBegin) {
      this.swiperDisabled = true
    } else {
      this.swiperDisabled = false
    }
    if (this.refreshStage == PullToRefreshStage.doLoading) {
      this.allContentReload()
    }
  }

  allContentReload() {
    this.contentReady = {}
    this.dataControlCounter += 1
  }

  @Builder
  blankBuilder() {
  }

  @BuilderParam contentBuilder: (page: number, index: number, loadingIcon: SwipePageLoadingIcon,
    scroller?: Scroller) => void = this.blankBuilder;

  build() {
    Swiper() {
      LazyForEach(this.dataSource, (page: number, index: number) => {
        Stack() {
          PullToRefresh({
            enable: this.enablePullToRefresh,
            stage: this.refreshStage,
            useList: this.useList,
            contentBuilder: (scroller) => this.contentBuilder(page, index, {
              show: page => this.contentReady[page] = false,
              hide: page => {
                if (page == this.currentPage) {
                  this.refreshStage = PullToRefreshStage.unactivated
                  this.swiperDisabled = false
                }
                this.contentReady[page] = true
              }
            }, scroller)
          })
          if (!this.contentReady[page] && this.refreshStage != PullToRefreshStage.doLoading) {
            LoadingProgress()
              .width(64)
              .height(64)
              .color($r('sys.color.ohos_id_color_emphasize'))
          }
        }.width('100%')
        .height('100%')
      }, (page: number) => page.toString())
    }
    .cachedCount(this.cacheCount)
    .disableSwipe(this.swiperDisabled || this.maxPage == 1)
    .indicator(false)
    .loop(false)
    .effectMode(EdgeEffect.None)
    .index($$this.currentSwiperIndex)
    .onAnimationStart((i, targetIndex) => {
      this.currentPage = targetIndex + 1
    })
  }
}