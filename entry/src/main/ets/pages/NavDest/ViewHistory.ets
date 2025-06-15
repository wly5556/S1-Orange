import { QueryViewHistory, ViewHistoryItem } from '../../common/dataStore/HistoryData'
import { DbPageDataSource } from '../../common/BasicDataSource'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import { openThreadPost, ThreadPostParam } from './ThreadPostList'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PropKey } from '../../common/Constants'
import { LengthUnit } from '@kit.ArkUI'

class HistoryDataSource extends DbPageDataSource<ViewHistoryItem> {
  override queryDatabase(offset: number, size: number): Promise<ViewHistoryItem[]> {
    return QueryViewHistory(offset, size)
  }
}

@Component
export struct ViewHistory {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  dataSource: HistoryDataSource = new HistoryDataSource()
  context = getContext(this) as common.UIAbilityContext
  @StorageProp(PropKey.userId) @Watch('onAccountUpdate') uid?: string = undefined

  onAccountUpdate() {
    this.dataSource.reload()
  }

  popBack() {
    this.pathStack.pop()
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: `历史记录`,
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        })
        List() {
          LazyForEach(this.dataSource, (item: ViewHistoryItem) => {
            ListItem() {
              Text(item.title)
                .textAlign(TextAlign.Start)
                .width('100%')
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
            }.clickEffect({ level: ClickEffectLevel.HEAVY })
            .onClick(e => {
              const param: ThreadPostParam = {
                tid: item.thread_id.toString(),
                subject: item.title,
                replies: item.reply.toString()
              }
              openThreadPost(param,this.pathStack, true)
            })
          }, (item: ViewHistoryItem, index: number) => item.pid + ',' + index)
          ListItem() {
            BottomSafeArea()
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .padding({ left:6, right: 6 })
        .backgroundColor(this.appTheme.backgroundSecondary)
        .constraintSize({
          minHeight: '100%'
        })
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
      }
    }.hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.dataSource.reload()
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  ViewHistory()
}

export function openHistoryPage(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.ViewHistory)
}