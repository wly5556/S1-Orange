import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import { AniSpeed, SpringCurve } from '../../common/Animation'
import request from '../../api/request'
import { URL } from '../../api/base'
import { PollInfoVM, PollOptionVM, PollPanelComp } from '../../common/component/PollPanel'
import { PostList, SpecialPoll, SpecialPollAllowVote, SpecialPollResultVisible } from '../../api/model/postList'
import wrapper, { wrapperApp } from '../../api/wrapper'
import { PollDesc } from '../../api/model/app/poll'
import Account from '../../api/model/account'
import { url } from '@kit.ArkTS'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { curves } from '@kit.ArkUI'
import { unescapeXml } from '../../common/XmlParser'
import { formatRelativeTime } from '../../common/TimeFormat'

export interface PollPopData {
  pollAdded: boolean
}

export interface PollDetailParam {
  tid: string
  pollList: PollOptionVM[]
  pollInfo: PollInfoVM
  transitionId: string
  scrollTo: number
}

export function getPollInfo(pollData: SpecialPoll): PollInfoVM {
  const maxChoices = parseInt(pollData.maxchoices)
  return {
    expirations: parseInt(pollData.expirations),
    maxchoices: isNaN(maxChoices) ? 1 : maxChoices,
    voterscount: pollData.voterscount,
    visiblepoll: pollData.visiblepoll,
    allowvote: pollData.allowvote
  }
}

export function getPollList(pollData: SpecialPoll) {
  return Object.values(pollData.polloptions).map(p => {
    const result: PollOptionVM = {
      polloptionid: p.polloptionid,
      polloption: p.polloption,
      votes: p.votes,
      percent: p.percent,
      color: p.color,
      selected: false
    }
    return result
  })
}

@Component
export struct PollDetail {
  @State pageParam: PollDetailParam = {
    tid: '',
    pollList: [],
    transitionId: '',
    scrollTo: 0,
    pollInfo: {
      expirations: 0,
      maxchoices: 1,
      voterscount: '',
      visiblepoll: SpecialPollResultVisible.VISIBLE,
      allowvote: SpecialPollAllowVote.ALLOW
    }
  }
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @State multiSelected: number[] = []
  @State addRatingShow: boolean = false
  votedUserLoaded: boolean = false
  @State votedUserShow: boolean = false
  @State voteOvert?: boolean = undefined
  @State voteAlready?: boolean = undefined
  @State hideForTransitionAnimation: boolean = true // 为了退出页面的时候，geometryTransition动画不被遮挡，用它来无动画地移除其它元素
  context = getContext(this) as common.UIAbilityContext
  selectedScroller: Scroller = new Scroller()
  selectionsScroller: Scroller = new Scroller()
  popData: PollPopData = {
    pollAdded: false
  }

  reload() {
    new request<wrapper<PostList>>(URL.THREAD_POST_LIST)
      .param('tid', this.pageParam.tid)
      .param('page', '1')
      .get()
      .then(v => {
        const pollData = v.Variables.special_poll
        if (pollData == undefined) {
          return
        }
        animateTo(SpringCurve, () => {
          this.pageParam.pollInfo = getPollInfo(pollData)
          this.pageParam.pollList = getPollList(pollData)
          this.popData.pollAdded = true
        })
        this.loadPollConfig()
      })
  }

  loadPollConfig() {
    new request<wrapperApp<PollDesc>>(URL.VOTE_INFO_APP, URL.APP_BASE)
      .appToken()
      .post({
        'tid': this.pageParam.tid
      }).then(pollDesc => {
      if (!pollDesc.success) {
        return
      }
      animateTo({ curve: curves.springMotion(AniSpeed.ratio * 0.2) }, () => {
        this.voteOvert = pollDesc.data.overt == 1
        this.voteAlready = pollDesc.data.voted
      })
    })
  }

  popBack() {
    this.hideForTransitionAnimation = false
    animateTo(SpringCurve, () => {
      this.pathStack.pop(this.popData, false)
    })
  }

  getVoteUsers(voteIndex: number, page: number) {
    new request<string>(URL.VOTE_VIEW_USER, URL.WEB_BASE)
      .param('tid', this.pageParam.tid)
      .param('page', page.toString())
      .param('polloptionid', this.pageParam.pollList[voteIndex].polloptionid)
      .toText()
      .get()
      .then(htmlStr => {
        const data = extractUsers(htmlStr)
        const temp = this.pageParam.pollList.slice(0)
        if (temp[voteIndex].votedUser !== undefined && temp[voteIndex].votedUser!.length > 0) {
          temp[voteIndex].votedUser = temp[voteIndex].votedUser!.concat(data)
        } else {
          temp[voteIndex].votedUser = data
        }
        if (temp[voteIndex].votedUser!.length < parseInt(this.pageParam.pollList[voteIndex].votes)
          && data.length > 0) {
          setTimeout((): void => this.getVoteUsers(voteIndex, page + 1), 100)
        }
        animateTo(SpringCurve, () => {
          this.pageParam.pollList = temp
          this.votedUserShow = true
        })
        this.votedUserLoaded = true
      })
  }

  build() {
    NavDestination() {
      Column() {
        TitleBar({
          titleContent: `投票详情`,
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        }) {
          Row() {
            if (this.hideForTransitionAnimation) {
              if (this.voteOvert === true) {
                Button(this.votedUserShow ? '隐藏参与者' : '显示参与者')
                  .buttonStyle(ButtonStyleMode.TEXTUAL)
                  .backgroundColor(this.appTheme.backgroundTertiary)
                  .onClick(() => {
                    if (this.votedUserShow) {
                      animateTo(SpringCurve, () => {
                        this.votedUserShow = false
                      })
                    } else {
                      if (this.votedUserLoaded) {
                        animateTo(SpringCurve, () => {
                          this.votedUserShow = true
                        })
                      } else {
                        this.pageParam.pollList.forEach((p, i) => {
                          setTimeout(() => {
                            this.getVoteUsers(i, 1)
                          }, i * 200)
                        })
                      }
                    }
                  })
              } else if (this.voteOvert === false) {
                Text('（不公开参与者的投票）')
                  .textAlign(TextAlign.Center)
                  .fontStyle(FontStyle.Italic)
                  .opacity(0.7)
              }
            }
          }.alignSelf(ItemAlign.Stretch)
          .justifyContent(FlexAlign.Center)
          .padding({ right: 12 })
        }

        Column() {
          Scroll(this.selectionsScroller) {
            Column() {
              Text('投票结束时间 ' + formatRelativeTime(new Date, new Date(this.pageParam.pollInfo.expirations * 1000))).opacity(0.6).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                .margin({ top: 8 })
              PollPanelComp({
                appTheme: this.appTheme,
                appState: this.appState,
                pollList: this.pageParam.pollList,
                pollInfo: this.pageParam.pollInfo,
                expired: this.pageParam.pollInfo.expirations * 1000 < Date.now(),
                transitionIndex: this.pageParam.transitionId,
                showVotedUser: this.votedUserShow,
                onSelected: index => {
                  if (this.pageParam.pollInfo.allowvote == SpecialPollAllowVote.FORBIDDEN) {
                    return
                  }
                  const newPollList = this.pageParam.pollList.slice()
                  let newSelected = this.multiSelected.slice()
                  if (this.pageParam.pollInfo.maxchoices == 1) {
                    newSelected.pop()
                    if (newPollList[index].selected == false) {
                      for (let i = 0; i < newPollList.length; i++) {
                        if (i == index) {
                          newSelected.push(i)
                          newPollList[i].selected = true
                        } else {
                          newPollList[i].selected = false
                        }
                      }
                    } else {
                      newPollList[index].selected = false
                    }
                  } else {
                    if (newPollList[index].selected == false) {
                      if (newSelected.length == this.pageParam.pollInfo.maxchoices) {
                        newPollList[newSelected.splice(0, 1)[0]].selected = false
                      }
                      newPollList[index].selected = true
                      newSelected.push(index)
                    } else {
                      newPollList[index].selected = false
                      newSelected = newSelected.filter(i => i != index)
                    }
                  }
                  animateTo(SpringCurve, () => {
                    this.pageParam.pollList = newPollList
                    if (this.multiSelected.length < newSelected.length) {
                      setTimeout((): void => this.selectedScroller.scrollEdge(Edge.Bottom))
                    }
                    this.multiSelected = newSelected
                  })
                },
                allowVote: !this.voteAlready && !(this.pageParam.pollInfo.allowvote == SpecialPollAllowVote.FORBIDDEN)
              })
            }
          }.flexGrow(1)
          .flexShrink(1)
          .padding({ left: 6, right: 6 })
          .edgeEffect(EdgeEffect.Spring)

          if (this.hideForTransitionAnimation) {
            Divider()
            if (this.voteAlready) {
              Text('已投票，感谢参与')
                .width('100%')
                .textAlign(TextAlign.Center)
                .fontStyle(FontStyle.Italic)
                .opacity(0.7)
                .height(60)
            } else {
              if (this.multiSelected.length > 0) {
                Row() {
                  Text('当前选择')
                    .fontWeight(FontWeight.Bold)
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp22)
                    .fontColor(this.appTheme.themeColorDarken)
                  Text('已选 ' + this.multiSelected.length + ' 项，还可选 ' +
                    (this.pageParam.pollInfo.maxchoices - this.multiSelected.length) + '项')
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp16).opacity(.7)
                }.alignItems(VerticalAlign.Bottom)
                .justifyContent(FlexAlign.SpaceBetween)
                .width('100%')
                .margin({ top: 10, bottom: 10 })
                .padding({ left: 8, right: 8 })

                Scroll(this.selectedScroller) {
                  Column() {
                    ForEach(this.multiSelected, (itemIndex: number, index: number) => {
                      Row() {
                        Text(unescapeXml(this.pageParam.pollList[itemIndex].polloption)).flexGrow(1).flexShrink(1)
                          .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                        Button('移除')
                          .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                          .height(FontSizeEnum[this.appState.fontSize].vp36)
                          .backgroundColor('#00000000')
                          .fontColor(this.appTheme.fontSecondary)
                          .onClick(e => {
                            const temp = this.pageParam.pollList.slice()
                            temp[itemIndex].selected = false
                            animateTo(SpringCurve, () => {
                              this.multiSelected = this.multiSelected.filter(i => i != itemIndex)
                              this.pageParam.pollList = temp
                            })
                          })
                      }.width('100%')
                      .opacity(0.8)
                    }, (itemIndex: number) => itemIndex.toString())
                  }.padding({ left: 8, right: 8 })
                }.constraintSize({
                  maxHeight: '32%'
                })
              }
              Button('提交投票')
                .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                .width('100%')
                .buttonStyle(ButtonStyleMode.TEXTUAL)
                .backgroundColor(this.appTheme.backgroundTertiary)
                .enabled(this.multiSelected.length > 0)
                .opacity(this.multiSelected.length > 0 ? 1 : 0.6)
                .margin({ top: 6, bottom: 6 })
                .onClick(e => {
                  new request<wrapper<Account>>(URL.VOTE_ACTION, URL.WEB_BASE)
                    .formHash()
                    .post(new url.URLParams(`tid=${this.pageParam.tid}&${this.multiSelected.map(i => `pollanswers[]=${this.pageParam.pollList[i].polloptionid}`)
                      .join('&')}`).toString()).then(v => {
                    this.reload()
                    this.popData.pollAdded = true
                  })
                })
            }
          }
        }
        .flexGrow(1)
        .flexShrink(1)

        BottomSafeArea()
      }
      .justifyContent(FlexAlign.Start)
      .width('100%')
      .height('100%')
      .backgroundColor(this.appTheme.backgroundSecondary)
    }.hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.pageParam = context.pathInfo.param as PollDetailParam
      this.pageParam.pollList.forEach((p, i) => {
        if (p.selected) {
          this.multiSelected.push(i)
        }
      })
      setTimeout((): void => this.selectionsScroller.scrollTo({
        yOffset: this.pageParam.scrollTo - 300,
        xOffset: 0,
        animation: true
      }))
      this.loadPollConfig()
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  PollDetail()
}

export function openPollDetail(pathStack: NavPathStack, param: PollDetailParam,
  popCallback: Callback<PopInfo>) {
  animateTo(SpringCurve, () => {
    openOrJumpTo(pathStack, PageNameEnum.PollDetail, param, false, e => JSON.stringify(e) == JSON.stringify(param),
      popCallback)
  })
}

export interface VotedUser {
  username: string
  uid: string
}

function extractUsers(html: string): VotedUser[] {
  const userPattern = /<li><p><a href="space-uid-(\d+)\.html" target="_blank">([^<]+)<\/a><\/p><\/li>/g
  const users: VotedUser[] = []
  let match: RegExpExecArray | null
  while ((match = userPattern.exec(html)) !== null) {
    if (match.length != 3) {
      continue
    }
    const uid = match[1]
    const username = match[2]
    users.push({ username, uid })
  }
  return users
}