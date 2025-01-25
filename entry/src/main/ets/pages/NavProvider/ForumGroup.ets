import { URL } from '../../api/base'
import request from '../../api/request'
import { ForumGroup, ForumInfo } from '../../api/model/forumGroup'
import wrapper from '../../api/wrapper'
import { ClickDarkenEffect, HeavyClickEffect } from '../../common/Animation'
import { OuterScroller } from '../../common/component/OuterScroller'
import { PullToRefresh, PullToRefreshStage } from '../../common/component/PullToRefresh'
import { TitleBar, TitleBarLeftButtonType } from '../../common/component/TitleBar'
import { common } from '@kit.AbilityKit'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { openSearchPage } from '../NavDest/SearchPage'
import { openInBrowser } from '../../common/WantUitl'
import { PreferenceState } from './NavigationPage'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PropKey, SafeArea } from '../../common/Constants'
import { Event } from '../../common/Events'


@Component
export struct ForumGroupView {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  context = getContext(this) as common.UIAbilityContext
  @State forumGroupId: string[] = []
  @State forumGroupName: Map<string, string> = new Map()
  @State forumGroupTodayPost: Map<string, string> = new Map()
  @State forumGroupItemOffsetY: Map<string, number> = new Map()
  forumInfoMap: Map<string, ForumInfo> = new Map()
  @Consume forumInfo?: ForumInfo
  @Consume sideMenuShow: number
  @State @Watch('pullDownStageChanged') refreshStage: PullToRefreshStage = PullToRefreshStage.unactivated
  @State clickEffectModifier: AttributeModifier<CommonAttribute> = new ClickDarkenEffect()
  @StorageProp(SafeArea.bottom) bottomRectHeight: number = 0
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @State pullToRefreshEnabled: boolean = true
  @StorageProp(PropKey.userId) @Watch('refreshThreadGroup') uid?: string = undefined

  pullDownStageChanged() {
    if (this.refreshStage == PullToRefreshStage.doLoading) {
      this.refreshThreadGroup().then(() => this.refreshStage = PullToRefreshStage.unactivated)
    }
  }

  aboutToAppear(): void {
    if (this.forumGroupName.size == 0) {
      this.refreshThreadGroup()
    }
  }

  processData(v: wrapper<ForumGroup>) {
    let formGroupData = v.Variables.forumlist.sort((a, b) => parseInt(b.todayposts) - parseInt(a.todayposts))
    this.forumGroupId = formGroupData.map(v => v.fid)
    this.forumGroupName.clear()
    this.forumGroupTodayPost.clear()
    this.forumGroupItemOffsetY.clear()
    formGroupData.forEach((v, i) => {
      this.forumInfoMap.set(v.fid, v)
      this.forumGroupName.set(v.fid, v.name)
      this.forumGroupItemOffsetY.set(v.fid, i * FontSizeEnum[this.appState.fontSize].vp48)
      this.forumGroupTodayPost.set(v.fid, v.todayposts)
    })
  }

  refreshThreadGroup() {
    return new request<wrapper<ForumGroup>>(URL.FORUM_GROUP)
      .cache((v): void => this.processData(v), this.forumGroupId.length > 0, this.uid === undefined)
      .get()
      .then((v): void => this.processData(v))
  }

  build() {
    OuterScroller({
      onEnterAndLeaveTop: atTop => this.pullToRefreshEnabled = atTop
    }) {
      TitleBar({
        titleContent: "论坛",
        leftButtonType: TitleBarLeftButtonType.SIDEBAR,
        menu: [{
          value: '从浏览器中打开',
          action: () => {
            openInBrowser(this.context, URL.WEB_BASE)
          }
        }, {
          value: '前往指定帖子',
          action: () => {
            this.context.eventHub.emit(Event.OpenGotoThreadDialog)
          }
        }],
        clickLeftButton: () => {
          this.sideMenuShow = 1
        }
      }) {
        Stack() {
          Image($r('app.media.magnifyingglass'))
            .width(28)
            .height(28)
            .fillColor(this.appTheme.titleBarFont)
        }.width(50)
        .height(50)
        .clickEffect(HeavyClickEffect)
        .onClick(() => {
          openSearchPage(this.pathStack, {})
        })
      }

      PullToRefresh({
        enable: this.pullToRefreshEnabled,
        stage: this.refreshStage,
        scrollBar: BarState.Off
      }) {
        Stack() {
          ForEach(this.forumGroupId, (fid: string) => {
            Row() {
              Text(this.forumGroupName.get(fid))
                .margin({ right: 16 })
                .fontSize(FontSizeEnum[this.appState.fontSize].vp18)
              if (this.forumGroupTodayPost.get(fid) != '0') {
                Text(this.forumGroupTodayPost.get(fid)).fontColor(this.appTheme.fontEmphasize)
                  .fontSize(FontSizeEnum[this.appState.fontSize].vp18)
              }
            }
            .padding(12)
            .offset({ top: this.forumGroupItemOffsetY.get(fid) })
            .animation({ duration: 300, curve: Curve.EaseOut })
            .height(FontSizeEnum[this.appState.fontSize].vp48)
            .width('100%')
            .backgroundEffect({
              radius: 0,
              brightness: 1
            })
            .animation({ duration: 100 })
            .attributeModifier(this.clickEffectModifier)
            .clickEffect({
              level: ClickEffectLevel.MIDDLE,
              scale: 0.9
            })
            .onClick(e => {
              this.forumInfo = this.forumInfoMap.get(fid)
            })
          }, (fid: string) => fid)
          if (this.forumGroupId.length == 0) {
            LoadingProgress()
              .width(64)
              .height(64)
              .color($r('sys.color.ohos_id_color_emphasize'))
              .offset({ top: 200 })
          }
        }.width('100%')
        .height(this.forumGroupId.length * FontSizeEnum[this.appState.fontSize].vp48 + px2vp(this.bottomRectHeight))
        .constraintSize({
          minHeight: '100%'
        })
        .alignContent(Alignment.Top)
      }
    }
  }
}