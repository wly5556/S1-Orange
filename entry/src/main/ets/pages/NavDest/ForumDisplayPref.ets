import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import request from '../../api/request'
import { URL } from '../../api/base'
import wrapper from '../../api/wrapper'
import { ForumGroup, ForumInfo } from '../../api/model/forumGroup'
import { PreferenceManager } from '../../config/UserConfig'
import { ForumSortMode } from '../../config/v1/default'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PropKey } from '../../common/Constants'
import { Event } from '../../common/Events'

const SortModeText: string[] = []
SortModeText[ForumSortMode.byReplyCount] = '按回帖量排序'
SortModeText[ForumSortMode.custom] = '自定义排序'

@Component
export struct ForumDisplayPrefPage {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  context = getContext(this) as common.UIAbilityContext

  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: SortModeText.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('sortModeChanged') sortModeSelected: ForumSortMode[] = []
  @State sortMode: ForumSortMode = ForumSortMode.byReplyCount
  @State forums: ForumInfo[] = []
  private rawForums: ForumInfo[] = []
  @State hiddenFids: string[] = []
  @State customOrder: string[] = []
  @State loading: boolean = true

  popBack() {
    this.pathStack.pop()
  }

  sortModeChanged() {
    if (this.sortModeSelected.length === 0) {
      return
    }
    const newMode = this.sortModeSelected[0]
    if (newMode === this.sortMode) {
      return
    }
    PreferenceManager.modify(conf => {
      conf.forum_sort_mode = newMode
      if (newMode === ForumSortMode.custom && conf.forum_display_order.length === 0 && this.rawForums.length > 0) {
        const initOrder = this.rawForums.slice()
          .sort((a, b) => parseInt(b.todayposts) - parseInt(a.todayposts))
          .map(f => f.fid)
        conf.forum_display_order = initOrder
        this.customOrder = initOrder
      }
      this.sortMode = newMode
      this.applyDisplay()
    })
  }

  applyDisplay() {
    if (this.rawForums.length === 0) {
      return
    }
    const list = this.rawForums.slice()
    if (this.sortMode === ForumSortMode.custom && this.customOrder.length > 0) {
      const orderMap = new Map<string, number>()
      this.customOrder.forEach((fid, i) => orderMap.set(fid, i))
      list.sort((a, b) => {
        const ia = orderMap.has(a.fid) ? orderMap.get(a.fid)! : Number.MAX_SAFE_INTEGER
        const ib = orderMap.has(b.fid) ? orderMap.get(b.fid)! : Number.MAX_SAFE_INTEGER
        return ia - ib
      })
    } else {
      list.sort((a, b) => parseInt(b.todayposts) - parseInt(a.todayposts))
    }
    this.forums = list
  }

  processData(v: wrapper<ForumGroup>) {
    this.rawForums = v.Variables.forumlist
    this.syncForumPrefs()
  }

  syncForumPrefs() {
    if (this.rawForums.length === 0) {
      this.applyDisplay()
      this.loading = false
      return
    }
    const fidSet = new Set<string>()
    this.rawForums.forEach(f => fidSet.add(f.fid))
    let orderChanged = false
    const cleanedOrder = this.customOrder.filter(fid => {
      if (fidSet.has(fid)) {
        return true
      }
      orderChanged = true
      return false
    })
    const orderExistingSet = new Set<string>(cleanedOrder)
    const additional: string[] = []
    this.rawForums
      .filter(f => !orderExistingSet.has(f.fid))
      .slice()
      .sort((a, b) => parseInt(b.todayposts) - parseInt(a.todayposts))
      .forEach(f => additional.push(f.fid))
    if (additional.length > 0) {
      additional.forEach(fid => cleanedOrder.push(fid))
      orderChanged = true
    }
    let hiddenChanged = false
    const cleanedHidden = this.hiddenFids.filter(fid => {
      if (fidSet.has(fid)) {
        return true
      }
      hiddenChanged = true
      return false
    })
    if (this.sortMode === ForumSortMode.custom && cleanedOrder.length === 0 && this.rawForums.length > 0) {
      const initOrder = this.rawForums.slice()
        .sort((a, b) => parseInt(b.todayposts) - parseInt(a.todayposts))
        .map(f => f.fid)
      cleanedOrder.length = 0
      initOrder.forEach(fid => cleanedOrder.push(fid))
      orderChanged = true
    }
    this.customOrder = cleanedOrder
    this.hiddenFids = cleanedHidden
    if (orderChanged || hiddenChanged) {
      PreferenceManager.modify(conf => {
        conf.forum_display_order = cleanedOrder
        conf.forum_hidden = cleanedHidden
      })
    }
    this.applyDisplay()
    this.loading = false
  }

  reloadForums() {
    new request<wrapper<ForumGroup>>(URL.FORUM_GROUP)
      .cache((v): void => this.processData(v), this.rawForums.length > 0)
      .get()
      .then((v): void => this.processData(v))
      .catch(() => {
        this.loading = false
      })
  }

  toggleHidden(fid: string, isOn: boolean) {
    const hiddenSet = new Set(this.hiddenFids)
    if (isOn) {
      hiddenSet.delete(fid)
    } else {
      hiddenSet.add(fid)
    }
    const newHidden = Array.from(hiddenSet)
    this.hiddenFids = newHidden
    PreferenceManager.modify(conf => {
      conf.forum_hidden = newHidden
    })
  }

  reorder(from: number, to: number) {
    if (this.sortMode !== ForumSortMode.custom) {
      return
    }
    if (from === to) {
      return
    }
    const arr = this.forums.slice()
    const removed = arr.splice(from, 1)
    arr.splice(to, 0, removed[0])
    this.forums = arr
    const newOrder = arr.map(f => f.fid)
    this.customOrder = newOrder
    PreferenceManager.modify(conf => {
      conf.forum_display_order = newOrder
    })
  }

  aboutToAppear() {
    PreferenceManager.readonly(conf => {
      this.sortMode = conf.forum_sort_mode
      this.hiddenFids = conf.forum_hidden
      this.customOrder = conf.forum_display_order
      this.sortModeSelected.push(conf.forum_sort_mode)
      this.reloadForums()
    })
  }

  aboutToDisappear() {
    this.context.eventHub.emit(Event.ForumDisplayPrefChanged)
  }

  @Builder
  dragHandle() {
    Image($r('app.media.dot_grid'))
      .width(20)
      .height(20)
      .fillColor(this.appTheme.fontSecondary)
      .opacity(0.6)
      .margin({ right: 8 })
  }

  @Builder
  forumListItem(f: ForumInfo) {
    ListItem() {
      Row() {
        if (this.sortMode === ForumSortMode.custom) {
          this.dragHandle()
        }
        Column({ space: 4 }) {
          Text(f.name)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .fontColor(this.appTheme.fontPrimary)
            .fontWeight(FontWeight.Medium)
          Text(`今日回帖 ${f.todayposts}`)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp13)
            .fontColor(this.appTheme.fontSecondary)
            .opacity(0.8)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({
          type: ToggleType.Switch,
          isOn: !this.hiddenFids.includes(f.fid)
        }).onChange(isOn => {
          this.toggleHidden(f.fid, isOn)
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .backgroundColor(this.appTheme.backgroundPrimary)
    .borderRadius(12)
    .margin({ left: 16, right: 16 })
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: '调整板块展示',
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        })

        Column() {
          SegmentButton({
            options: this.segmentOption,
            selectedIndexes: $sortModeSelected
          })
            .width('100%')
            .padding({ left: 16, right: 16, top: 12 })

          Text('请选择要在首页展示的板块。' + (this.sortMode === ForumSortMode.custom
            ? '通过拖拽调整它们的顺序。'
            : ''))
            .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 4 })

          if (this.loading) {
            Column() {
              LoadingProgress()
                .width(48)
                .height(48)
                .color($r('sys.color.ohos_id_color_emphasize'))
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            List({ space: 4 }) {
              if (this.sortMode === ForumSortMode.custom) {
                ForEach(this.forums, (f: ForumInfo) => {
                  this.forumListItem(f)
                }, (f: ForumInfo) => f.fid)
                  .onMove((from: number, to: number) => {
                    this.reorder(from, to)
                  })
              } else {
                ForEach(this.forums, (f: ForumInfo) => {
                  this.forumListItem(f)
                }, (f: ForumInfo) => f.fid)
              }

              ListItem() {
                BottomSafeArea()
              }
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .padding({ top: 4, bottom: 4 })
            .nestedScroll({
              scrollForward: NestedScrollMode.PARENT_FIRST,
              scrollBackward: NestedScrollMode.PARENT_FIRST
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  ForumDisplayPrefPage()
}

export function openForumDisplayPref(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.ForumDisplayPref)
}
