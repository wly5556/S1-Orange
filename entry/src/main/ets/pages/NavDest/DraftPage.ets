import { DbPageDataSource } from '../../common/BasicDataSource'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import {
  DeleteDraft,
  DraftDbSetUser,
  DraftItem,
  DraftModifiedListener,
  GetDraftItemKey,
  MAX_DRAFT_ITEM,
  QueryDraft
} from '../../common/dataStore/DraftData'
import { openWriteReply, WriteReplyMode, WriteReplyParam, WriteReplyPopData } from './WriteReply'
import { PreferenceManager } from '../../config/UserConfig'
import { LongPressDelete } from '../../common/component/LongPressDelete'
import { formatRelativeTime } from '../../common/TimeFormat'
import { EventListenerHandler } from '../../common/EventListener'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PropKey } from '../../common/Constants'

class DraftDataSource extends DbPageDataSource<DraftItem> {
  override pageSize: number = 20

  override queryDatabase(offset: number, size: number): Promise<DraftItem[]> {
    return QueryDraft(offset, size)
  }
}

const draftTypeName: string[] = []
draftTypeName[WriteReplyMode.NEW_THREAD] = '新帖'
draftTypeName[WriteReplyMode.EDIT] = '编辑'
draftTypeName[WriteReplyMode.NEW_POST] = '回复'
draftTypeName[WriteReplyMode.NEW_PM] = '私信'

const draftTagColor: string[] = []
draftTagColor[WriteReplyMode.NEW_THREAD] = '#BBB529'
draftTagColor[WriteReplyMode.EDIT] = '#60806A'
draftTagColor[WriteReplyMode.NEW_POST] = '#65CCE1'
draftTagColor[WriteReplyMode.NEW_PM] = '#AA7DFC'

@Component
export struct DraftPage {
  draftInsertedListener?: EventListenerHandler<void>
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  dataSource: DraftDataSource = new DraftDataSource()
  context = getContext(this) as common.UIAbilityContext
  @State nowDate: Date = new Date()
  dateInterval: number = 0
  @State draftCount?: number = undefined
  @StorageProp(PropKey.userId) @Watch('loadUser') uid?: string = undefined

  popBack() {
    this.pathStack.pop()
  }

  loadUser() {
    PreferenceManager.readonly(async conf => {
      await DraftDbSetUser(conf.user_uid)
      this.draftCount = await this.dataSource.reload()
    })
  }

  aboutToAppear(): void {
    this.dateInterval = setInterval(() => {
      this.nowDate = new Date()
    }, 60000)
    this.draftInsertedListener = DraftModifiedListener.on((): void => this.loadUser())
  }

  aboutToDisappear(): void {
    this.draftInsertedListener && DraftModifiedListener.off(this.draftInsertedListener)
    clearInterval(this.dateInterval)
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: `草稿`,
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        })
        List() {
          ListItem() {
            if (this.draftCount === 0) {
              Stack() {
                Text('无草稿记录').fontStyle(FontStyle.Italic).opacity(.8)
              }.width('100%')
              .height(60)
            }
          }

          LazyForEach(this.dataSource, (item: DraftItem) => {
            ListItem() {
              Column() {
                LongPressDelete({
                  transitionId: 'draftItem_' + GetDraftItemKey(item),
                  click: () => {
                    const param: WriteReplyParam = {
                      defaultTransition: true,
                      tid: String(item.thread_id || ''),
                      subjectToReply: item.thread_subject,
                      mode: item.draft_type,
                      fid: item.forum_id ? String(item.forum_id) : undefined,
                      editPid: item.edit_pid ? String(item.edit_pid) : undefined,
                      quotePid: item.quote_pid ? String(item.quote_pid) : undefined,
                      pmUid: item.pm_uid ? String(item.pm_uid) : undefined,
                      draft: item
                    }
                    openWriteReply(this.pathStack, param, (data: PopInfo) => {
                      if ((data.result as WriteReplyPopData).replied) {
                        this.dataSource.reload()
                      }
                    })
                  },
                  delete: async () => {
                    const result = await DeleteDraft(item)
                    if (!result) {
                      this.getUIContext().getPromptAction().showToast({
                        message: '删除时发生了预料外的错误'
                      })
                    }
                    this.draftCount = await this.dataSource.reload()
                  }
                }) {
                  Column({ space: 8 }) {
                    Row() {
                      Row() {
                        Text(draftTypeName[item.draft_type])
                          .fontColor($r('sys.color.white'))
                          .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                      }.borderRadius(24)
                      .backgroundColor(draftTagColor[item.draft_type])
                      .padding({
                        top: 6,
                        bottom: 6,
                        left: 12,
                        right: 12
                      })

                      Text(formatRelativeTime(this.nowDate, new Date(item.date)))
                        .opacity(.6)
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                    }
                    .justifyContent(FlexAlign.SpaceBetween)
                    .width('100%')

                    Text(item.thread_subject)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                      .opacity(.8)
                    Text(item.content)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.flexGrow(1)
                  .flexShrink(1)
                  .padding(12)
                  .alignItems(HorizontalAlign.Start)
                }
              }
              .alignItems(HorizontalAlign.Start)
              .backgroundColor(this.appTheme.backgroundSecondary)
            }.padding({ bottom: 1 })
            .clickEffect({ level: ClickEffectLevel.HEAVY })
            .backgroundColor(this.appTheme.backgroundTertiary)
          }, (item: DraftItem, index: number) => JSON.stringify(item) + index)
          ListItem() {
            Column({ space: 8 }) {
              Row({ space: 12 }) {
                Image($r('app.media.questionmark_circle'))
                  .width(24).height(24)
                Text('说明')
              }.alignSelf(ItemAlign.Start)

              Column({ space: 8 }) {
                Text(`未发表的内容将自动添加到此处。\n`).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                Text(`草稿数据储存在本地，上限${MAX_DRAFT_ITEM}条。`).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                Text(`长按草稿条目，可显示删除按钮。超限后最早的草稿会被自动移除。`).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              }.alignItems(HorizontalAlign.Start)

            }.backgroundColor(this.appTheme.backgroundTertiary)
            .padding(20)
            .margin({
              top: 20
            })
            .borderRadius(20)
            .alignSelf(ItemAlign.Center)
          }.width('100%')

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
      this.loadUser()
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  DraftPage()
}

export function openDraftPage(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.DraftPage)
}