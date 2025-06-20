import { URL } from '../../api/base'
import { PostList, SpecialPollAllowVote, SpecialPollResultVisible } from '../../api/model/postList'
import request from '../../api/request'
import {
  getPollInfo,
  getPollList,
  openPollDetail,
  PollDetailParam,
  PollPopData,
  VotedUser
} from '../../pages/NavDest/PollDetail'
import { SpringCurve } from '../Animation'
import { AppThemeColor } from '../theme/basic/basic'
import wrapper from '../../api/wrapper'
import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { unescapeXml } from '../XmlParser'
import { PropKey } from '../Constants'


export interface PollOptionVM {
  polloptionid: string
  polloption: string
  votes: string
  percent: string
  color: string
  selected: boolean
  votedUser?: VotedUser[]
}

export interface PollInfoVM {
  expirations: number
  maxchoices: number
  voterscount: string
  visiblepoll: SpecialPollResultVisible
  allowvote: SpecialPollAllowVote
}

@Component
export struct PollPanel {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  tid: string = ''
  @Prop @Require pollList: PollOptionVM[]
  @Prop @Require pollInfo: PollInfoVM
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  compTransitionId = 'PollPanel'
  requestReload: () => void = () => {
  }

  goPoll(pollList: PollOptionVM[], e: ClickEvent) {
    const param: PollDetailParam = {
      tid: this.tid,
      pollList: pollList,
      pollInfo: this.pollInfo,
      transitionId: this.compTransitionId,
      scrollTo: parseFloat(e.target.area.position.y?.toString() || '0')
    }
    openPollDetail(this.pathStack, param, (info) => {
      if ((info.result as PollPopData).pollAdded) {
        new request<wrapper<PostList>>(URL.THREAD_POST_LIST)
          .param('tid', this.tid)
          .param('page', '1')
          .get()
          .then(v => {
            const pollData = v.Variables.special_poll
            if (pollData == undefined) {
              return
            }
            this.pollInfo = getPollInfo(pollData)
            this.pollList = getPollList(pollData)
          })
      }
    })
  }

  build() {
    PollPanelComp({
      appTheme: this.appTheme,
      appState: this.appState,
      pollList: this.pollList,
      pollInfo: this.pollInfo,
      transitionIndex: this.compTransitionId,
      expired: this.pollInfo.expirations * 1000 < Date.now(),
      allowVote: this.pollInfo.allowvote == SpecialPollAllowVote.ALLOW,
      onSelected: (index: number, e: ClickEvent) => {
        const temp = JSON.parse(JSON.stringify(this.pollList)) as PollOptionVM[]
        if (this.pollInfo.allowvote == SpecialPollAllowVote.ALLOW) {
          temp[index].selected = true
        }
        this.goPoll(temp, e)
      }
    })
  }
}


export interface PollPanelCompData {
  appTheme: AppThemeColor
  appState: PreferenceState
  pollList: PollOptionVM[]
  pollInfo: PollInfoVM
  transitionIndex: string
  showVotedUser?: boolean
  onSelected: (index: number, e: ClickEvent) => void
  allowVote: boolean
  expired: boolean
}

@Builder
export function PollPanelComp(data: PollPanelCompData) {
  Column({ space: 4 }) {
    Row() {
      Text('投票').fontWeight(FontWeight.Bold).fontSize(FontSizeEnum[data.appState.fontSize].vp22).fontColor(data.appTheme.themeColorDarken)
      Text(`参与人数 ${data.pollInfo.voterscount}`).opacity(0.6).fontSize(FontSizeEnum[data.appState.fontSize].vp16)
      Text(`最多可投 ${data.pollInfo.maxchoices} 项`).opacity(0.6).fontSize(FontSizeEnum[data.appState.fontSize].vp16)
    }.justifyContent(FlexAlign.SpaceBetween).alignItems(VerticalAlign.Top)
    .width('100%')

    if (data.expired) {
      Text('投票已结束')
        .fontSize(FontSizeEnum[data.appState.fontSize].vp18)
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontStyle(FontStyle.Italic)
        .margin(6)
    }
    ForEach(data.pollList, (item: PollOptionVM, index: number) => {
      Column({ space: 8 }) {
        Row() {
          if (data.allowVote && !data.expired) {
            if (data.pollInfo.maxchoices == 1) {
              Stack() {
                RadioButton(item.selected)
              }
            } else {
              Stack() {
                CheckButton(item.selected)
              }
            }
          }
          Text(unescapeXml(item.polloption)).flexGrow(1).flexShrink(1).padding({ right: 12 }).fontSize(FontSizeEnum[data.appState.fontSize].vp16)
          if (data.pollInfo.visiblepoll == SpecialPollResultVisible.VISIBLE) {
            Text() {
              Span(item.percent + '%').fontColor(data.appTheme.fontSecondary)
              Span(` (${item.votes})`).fontColor('#' + item.color)
            }.flexShrink(0).fontSize(FontSizeEnum[data.appState.fontSize].vp16)
          }
        }.justifyContent(FlexAlign.SpaceBetween)
        .width('100%')

        if (item.votedUser && data.showVotedUser) {
          Text() {
            ForEach(item.votedUser, (user: VotedUser, userIndex: number) => {
              Span(`  ${user.username}  `)
            })
          }.copyOption(CopyOptions.LocalDevice).fontSize(FontSizeEnum[data.appState.fontSize].vp16)
          .opacity(0.8)
        }
        if (data.pollInfo.visiblepoll == SpecialPollResultVisible.VISIBLE) {
          Rect()
            .radius(5)
            .width(item.percent + '%')
            .height(16)
            .fill('#' + item.color)
        }

      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .borderRadius(8)
      .padding(8)
      .backgroundColor(item.selected ? '#15000000' : undefined)
      .onClick((e) => {
        data.onSelected && data.onSelected(index, e)
      })
    }, (item: PollOptionVM) => item.selected + item.polloptionid + item.votedUser?.length)
  }.margin({ top: 20 })
  .geometryTransition(data.transitionIndex, { follow: true })
  .zIndex(80)
}

@Builder
function RadioButton(selected: boolean) {
  Stack() {
    if (selected) {
      Circle()
        .width(12)
        .height(12)
        .fill($r('sys.color.ohos_id_color_emphasize'))
        .transition(TransitionEffect.opacity(0.8).combine(TransitionEffect.scale({
          x: 0.8, y: 0.8
        }).animation(SpringCurve)))
    }
  }
  .width(16)
  .height(16)
  .borderRadius(8)
  .backgroundColor($r('sys.color.background_primary'))
  .margin({ right: 12 })
  .shadow(ShadowStyle.OUTER_DEFAULT_XS)
}

@Builder
function CheckButton(selected: boolean) {
  Stack() {
    if (selected) {
      Rect()
        .width(12)
        .height(12)
        .fill($r('sys.color.ohos_id_color_emphasize'))
        .borderRadius(2)
        .transition(TransitionEffect.opacity(0.8).combine(TransitionEffect.scale({
          x: 0.8, y: 0.8
        })))
    }
  }
  .width(16)
  .height(16)
  .borderRadius(2)
  .backgroundColor($r('sys.color.background_primary'))
  .margin({ right: 12 })
  .shadow(ShadowStyle.OUTER_DEFAULT_XS)
}