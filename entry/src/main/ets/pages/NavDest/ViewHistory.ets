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
import { PreferenceManager } from '../../config/UserConfig'

class HistoryDataSource extends DbPageDataSource<ViewHistoryItem> {
  override queryDatabase(offset: number, size: number): Promise<ViewHistoryItem[]> {
    return QueryViewHistory(offset, size)
  }
}

function isSameDay(leftTime: number, rightTime: number): boolean {
  const left = new Date(leftTime)
  const right = new Date(rightTime)
  return left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate()
}

function formatHistoryDate(time: number): string {
  const date = new Date(time)
  const monthDay = `${date.getMonth() + 1}月${date.getDate()}日`
  if (date.getFullYear() === new Date().getFullYear()) {
    return monthDay
  }
  return `${date.getFullYear()}年${monthDay}`
}

@Component
export struct ViewHistory {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  dataSource: HistoryDataSource = new HistoryDataSource()
  context = getContext(this) as common.UIAbilityContext
  @StorageProp(PropKey.userId) @Watch('onAccountUpdate') uid?: string = undefined
  @State showDateDivider: boolean = false

  onAccountUpdate() {
    this.dataSource.reload()
  }

  popBack() {
    this.pathStack.pop()
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.showDateDivider = conf.view_history_show_date
    })
  }

  toggleDateDivider() {
    const showDateDivider = !this.showDateDivider
    PreferenceManager.modify(conf => {
      conf.view_history_show_date = showDateDivider
      this.showDateDivider = showDateDivider
      this.dataSource.notifyDataReload()
    })
  }

  shouldShowDateDivider(item: ViewHistoryItem, index: number): boolean {
    if (!this.showDateDivider) {
      return false
    }
    if (index === 0) {
      return true
    }
    const previous = this.dataSource.getData(index - 1)
    return !isSameDay(previous.date, item.date)
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: `历史记录`,
          useRightMenu: true,
          menu: [{
            value: '切换：日期显示',
            action: () => this.toggleDateDivider()
          }],
          clickLeftButton: () => {
            this.popBack()
          }
        })
        List() {
          LazyForEach(this.dataSource, (item: ViewHistoryItem, index: number) => {
            ListItem() {
              Column() {
                if (this.shouldShowDateDivider(item, index)) {
                  Text(formatHistoryDate(item.date))
                    .width('100%')
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                    .fontColor(this.appTheme.fontSecondary)
                    .padding({
                      left: 18,
                      right: 18,
                      top: 14,
                      bottom: 4
                    })
                }
                Row() {
                  Text(item.title)
                    .textAlign(TextAlign.Start)
                    .width('100%')
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    .lineSpacing({
                      value: this.appState.contentLineSpace,
                      unit: LengthUnit.VP
                    })
                }
                .width('100%')
                .padding({
                  left: 18,
                  right: 18,
                  top: this.appState.threadItemGap,
                  bottom: this.appState.threadItemGap
                })
                .clickEffect({ level: ClickEffectLevel.HEAVY })
                .onClick(e => {
                  const param: ThreadPostParam = {
                    tid: item.thread_id.toString(),
                    subject: item.title,
                    replies: item.reply.toString()
                  }
                  openThreadPost(param, this.pathStack, true)
                })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }, (item: ViewHistoryItem, index: number) => item.pid + ',' + index)
          ListItem() {
            BottomSafeArea()
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .padding({ left: 6, right: 6 })
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
