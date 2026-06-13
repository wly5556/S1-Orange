import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import request from '../../api/request'
import { URL } from '../../api/base'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { Avatar } from '../../common/component/Avatar'
import { openUserSpace, UserSpaceParam } from './UserSpace'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PropKey } from '../../common/Constants'
import { AniSpeed } from '../../common/Animation'
import { BasicDataSource } from '../../common/BasicDataSource'
import { PageSlider } from '../../common/component/PageSlider'

interface DarkRoomItem {
  cid: string
  uid: string
  operatorid: string
  operator: string
  action: string
  reason: string
  dateline: string
  username: string
  groupexpiry: string
}

interface DarkRoomResponse {
  message: string
  data: Record<string, DarkRoomItem>
}

class DarkRoomDataSource extends BasicDataSource<DarkRoomItem> {
  private data: DarkRoomItem[] = []
  private nextCid: string = ''
  private hasMore: boolean = true
  private querying: boolean = false
  private threshold: number = 5
  private pageStartIndex: number[] = []

  public totalCount(): number {
    return this.data.length
  }

  public getData(index: number): DarkRoomItem {
    if (this.totalCount() - index < this.threshold && this.hasMore && !this.querying) {
      this.loadMore()
    }
    return this.data[index]
  }

  public isHasMore(): boolean {
    return this.hasMore
  }

  public pageOfIndex(index: number): number {
    if (index < 0) {
      return 1
    }
    let page = 1
    for (let p = 0; p < this.pageStartIndex.length; p++) {
      if (this.pageStartIndex[p] <= index) {
        page = p + 1
      } else {
        break
      }
    }
    return page
  }

  public loadedPageCount(): number {
    return this.pageStartIndex.length
  }

  private async loadMore() {
    this.querying = true
    try {
      const resp = await new request<string>(URL.WEB_BASE + URL.DARKROOM)
        .param('cid', this.nextCid)
        .toText()
        .get()
      const darkroom: DarkRoomResponse = JSON.parse(resp.replace(/(\d+):\{"cid":/g, '"$1":{"cid":'))
      const msgParts = darkroom.message.split('|')
      if (msgParts.length === 2 && msgParts[0] === '1') {
        this.nextCid = msgParts[1]
      }

      const newItems = Object.values(darkroom.data)
      if (newItems.length === 0) {
        this.hasMore = false
      } else {
        this.pageStartIndex.push(this.data.length)
        this.data = this.data.concat(newItems)
        this.notifyDataReload()
      }
    } catch (err) {
      console.error('DarkRoom load error:', err)
    } finally {
      this.querying = false
    }
  }

  public async reload(): Promise<void> {
    this.nextCid = ''
    this.hasMore = true
    this.querying = false
    this.data = []
    this.pageStartIndex = []
    await this.loadMore()
  }
}

@Component
export struct DarkRoomPage {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  context = getContext(this) as common.UIAbilityContext
  dataSource: DarkRoomDataSource = new DarkRoomDataSource()
  @State currentPage: number = 1
  @State loadedPage: number = 0
  @State hasMore: boolean = true

  popBack() {
    this.pathStack.pop()
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: '小黑屋',
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        }) {
          if (this.loadedPage > 0) {
            PageSlider({
              pageIndex: this.currentPage,
              totalPage: this.loadedPage,
              hideTotal: this.hasMore,
              clickable: false
            })
          }
        }

        List() {
          LazyForEach(this.dataSource, (item: DarkRoomItem) => {
            ListItem() {
              Column({ space: 8 }) {
                Row({ space: 12 }) {
                  Avatar({
                    uid: item.uid,
                    transitionIndex: 'darkroom_' + item.uid
                  }).onClick(() => {
                    const userSpaceParam: UserSpaceParam = {
                      uid: item.uid,
                      username: item.username,
                      avatarTransitionIndex: 'darkroom_' + item.uid
                    }
                    openUserSpace(userSpaceParam, this.pathStack)
                  })

                  Column({ space: 4 }) {
                    Text(item.username)
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.appTheme.fontPrimary)

                    Text(`${item.action} 至 ${item.groupexpiry}`)
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                      .fontColor(this.appTheme.fontSecondary)
                      .opacity(0.8)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)

                if (item.reason) {
                  Text(`原因: ${item.reason}`)
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    .fontColor(this.appTheme.fontPrimary)
                    .padding({ left: 4, right: 4 })
                }

                Row() {
                  Text(`${item.operator} 操作于 ${item.dateline}`)
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                    .fontColor(this.appTheme.fontSecondary)
                    .opacity(0.6)
                }
                .width('100%')
                .justifyContent(FlexAlign.End)
              }
              .padding(12)
              .alignItems(HorizontalAlign.Start)
              .transition(TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms120 }))
            }
            .padding({ bottom: 1 })
          }, (item: DarkRoomItem) => item.cid)

          ListItem() {
            BottomSafeArea()
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(this.appTheme.backgroundSecondary)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
        .edgeEffect(EdgeEffect.None)
        .onScrollIndex((start: number, end: number) => {
          this.currentPage = this.dataSource.pageOfIndex(start)
          this.loadedPage = this.dataSource.loadedPageCount()
          this.hasMore = this.dataSource.isHasMore()
        })
        .padding({ left: 6, right: 6 })
        .constraintSize({
          minHeight: '100%'
        })
      }
    }
    .hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.dataSource.reload().then(() => {
        this.currentPage = 1
        this.loadedPage = this.dataSource.loadedPageCount()
        this.hasMore = this.dataSource.isHasMore()
      })
    })
    .onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  DarkRoomPage()
}

export function openDarkRoom(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.DarkRoom)
}
