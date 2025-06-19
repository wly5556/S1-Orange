import { ArrayDataSource } from '../../common/BasicDataSource'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import {
  BlockUserInfo,
  blockUserList,
  blockUserListSyncAt,
  SyncBlockUserListWithWeb,
  UnblockUser
} from '../../common/dataStore/BlockUser'
import { Avatar } from '../../common/component/Avatar'
import { formatRelativeTime } from '../../common/TimeFormat'
import { openUserSpace, UserSpaceParam } from './UserSpace'
import { Spring035s } from '../../common/Animation'
import {
  BlockKeyword,
  blockKeywordInfo,
  BlockKeywordInfo,
  ToggleEnableBlockKeyword,
  UnblockKeyword
} from '../../common/dataStore/BlockKeyword'
import { CopyText } from '../../common/ShareKit'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PropKey } from '../../common/Constants'


@Component
export struct BlockListPage {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  dataSourceBlockUser: ArrayDataSource<BlockUserInfo> = new ArrayDataSource()
  context = getContext(this) as common.UIAbilityContext
  @State nowDate: Date = new Date()
  dateInterval: number = 0
  @State blockUserListLen?: number = undefined
  @State syncTipShow: boolean = false
  @State remoteSyncAt: Date = new Date()
  @State blockKwList: BlockKeywordInfo[] = []
  @State blockKwInput: string = ''
  @StorageProp(PropKey.userId) @Watch('onAccountUpdate') uid?: string = undefined

  onAccountUpdate() {
    this.reloadBlockUsers()
    this.reloadBlockKws()
  }

  popBack() {
    this.pathStack.pop()
  }

  reloadBlockUsers() {
    animateTo(Spring035s, () => {
      this.dataSourceBlockUser.reload(Object.values(blockUserList).sort((a, b) => b.date - a.date))
      this.blockUserListLen = this.dataSourceBlockUser.totalCount()
      this.remoteSyncAt = new Date(blockUserListSyncAt)
      this.nowDate = new Date()
    })
  }

  reloadBlockKws() {
    animateTo(Spring035s, () => {
      this.blockKwList = blockKeywordInfo
      this.nowDate = new Date()
    })
  }

  aboutToAppear(): void {
    this.dateInterval = setInterval(() => {
      this.nowDate = new Date()
    }, 60000)
  }

  aboutToDisappear(): void {
    clearInterval(this.dateInterval)
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: `黑名单`,
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        })
        Tabs() {
          TabContent() {
            List() {
              ListItem() {
                Column({ space: 8 }) {
                  Row({ space: 12 }) {
                    Image($r('app.media.questionmark_circle'))
                      .width(24).height(24)
                    Text(this.syncTipShow ? '收起说明 <' : '查看说明 >')
                  }.alignSelf(ItemAlign.Start)
                  .onClick(e => {
                    animateTo(Spring035s, () => {
                      this.syncTipShow = !this.syncTipShow
                    })
                  })

                  if (this.syncTipShow) {
                    Column({ space: 8 }) {
                      Text('屏蔽用户的“添加时间”并非屏蔽该用户的时刻，而是代表软件内记录了该用户的屏蔽信息的时刻。')
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      Text('登陆账号时，将从网页端载入您的屏蔽用户列表，您在本应用内发起的屏蔽，将会向网页端发送请求，更改屏蔽用户列表。')
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      Text('但除此之外，屏蔽用户列表不会自动刷新。若您在其它设备、网页端更改了屏蔽用户，则可在本应用内发起同步，获取更新。')
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    }
                  }
                  Row() {
                    Column({ space: 12 }) {
                      Text('屏蔽列表同步于').fontColor($r('sys.color.font_primary'))
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                        .fontWeight(FontWeight.Medium)
                      Text(formatRelativeTime(this.nowDate, this.remoteSyncAt))
                        .fontColor($r('sys.color.font_secondary'))
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                    }.alignItems(HorizontalAlign.Start)

                    Button('立即同步')
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      .buttonStyle(ButtonStyleMode.NORMAL)
                      .onClick(async () => {
                        await SyncBlockUserListWithWeb()
                        this.reloadBlockUsers()
                      })
                  }.constraintSize({
                    minHeight: 48
                  })
                  .padding({ top: 12, bottom: 12 })
                  .justifyContent(FlexAlign.SpaceBetween)
                  .width('100%')
                }.backgroundColor(this.appTheme.backgroundTertiary)
                .padding(20)
                .borderRadius(20)
              }

              ListItem() {
                if (this.blockUserListLen === 0) {
                  Stack() {
                    Text('无被屏蔽的用户').fontStyle(FontStyle.Italic).opacity(.8)
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                  }.width('100%')
                  .height(60)
                } else {
                  Text('当前屏蔽用户数量: ' + this.blockUserListLen).opacity(.8)
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    .padding(20)
                }
              }

              LazyForEach(this.dataSourceBlockUser, (item: BlockUserInfo) => {
                ListItem() {
                  Column({ space: 8 }) {
                    Row({ space: 12 }) {
                      Avatar({
                        uid: item.uid,
                        transitionIndex: 'block_list' + item.uid
                      }).onClick(() => {
                        const userSpaceParam: UserSpaceParam = {
                          uid: item.uid,
                          username: item.username,
                          avatarTransitionIndex: 'block_list' + item.uid
                        }
                        openUserSpace(userSpaceParam, this.pathStack)
                      })
                      Text(item.username)
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp18)
                        .fontWeight(FontWeight.Regular)
                      Blank()
                      Button('解除')
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                        .buttonStyle(ButtonStyleMode.NORMAL)
                        .fontColor(Color.Red)
                        .onClick(() => {
                          UnblockUser(item.uid).then((): void => this.reloadBlockUsers())
                        })
                    }.width('100%')

                    Text('添加时间: ' + formatRelativeTime(this.nowDate, new Date(item.date)))
                      .opacity(.8)
                      .alignSelf(ItemAlign.End)
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    Divider()
                  }.padding(12)
                  .alignItems(HorizontalAlign.Start)
                }
                .clickEffect({ level: ClickEffectLevel.HEAVY })
                .geometryTransition(item.uid)
              }, (item: BlockUserInfo, index: number) => item.uid)
              ListItem() {
                BottomSafeArea()
              }
            }
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
            .padding({ left: 6, right: 6 })
            .constraintSize({
              minHeight: '100%'
            })
            .nestedScroll({
              scrollForward: NestedScrollMode.PARENT_FIRST,
              scrollBackward: NestedScrollMode.PARENT_FIRST
            })
          }.tabBar(SubTabBarStyle.of('用户屏蔽')
            .labelStyle({
              selectedColor: this.appTheme.fontEmphasize,
              font: {
                size: FontSizeEnum[this.appState.fontSize].vp16
              }
            })
            .indicator({
              color: this.appTheme.fontEmphasize
            }))

          TabContent() {
            List() {
              ListItem() {
                Row({ space: 8 }) {
                  TextInput({
                    text: $$this.blockKwInput,
                    placeholder: '输入屏蔽词，支持正则表达式'
                  }).width('80%').fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                  Button('添加').onClick(e => {
                    try {
                      const regex = new RegExp(this.blockKwInput)
                      BlockKeyword(this.blockKwInput)
                      this.reloadBlockKws()
                      this.blockKwInput = ''
                    } catch (err) {
                      this.getUIContext().getPromptAction().showToast({
                        message: '不符合正则语法，添加失败'
                      })
                    }
                  }).enabled(this.blockKwInput.length > 0)
                }.justifyContent(FlexAlign.SpaceBetween)
                .width('100%')
              }

              ListItem() {
                if (this.blockKwList.length === 0) {
                  Stack() {
                    Text('无屏蔽词')
                      .fontStyle(FontStyle.Italic)
                      .opacity(.8)
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                  }.width('100%')
                  .height(60)
                } else {
                  Text('当前屏蔽词数量: ' + this.blockKwList.length).opacity(.8)
                    .padding(20).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                }
              }

              ForEach(this.blockKwList, (item: BlockKeywordInfo) => {
                ListItem() {
                  Column({ space: 8 }) {
                    Row({ space: 12 }) {
                      Text(item.regex)
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp18)
                        .fontWeight(FontWeight.Regular)
                      Blank()
                      Toggle({
                        isOn: item.enabled,
                        type: ToggleType.Switch
                      }).onChange(isOn => {
                        ToggleEnableBlockKeyword(item.date, isOn)
                      })
                    }.width('100%')

                    Row() {
                      Button('移除')
                        .buttonStyle(ButtonStyleMode.NORMAL)
                        .fontColor(Color.Red)
                        .onClick(() => {
                          UnblockKeyword(item.date)
                          this.reloadBlockKws()
                        })
                      Text('添加时间: ' + formatRelativeTime(this.nowDate, new Date(item.date)))
                        .opacity(.8)
                    }.width('100%')
                    .justifyContent(FlexAlign.SpaceBetween)

                    Divider()
                  }.padding(12)
                  .alignItems(HorizontalAlign.Start)
                }
                .clickEffect({ level: ClickEffectLevel.HEAVY })
                .geometryTransition(String(item.date))
                .gesture(LongPressGesture().onAction(e => {
                  CopyText(item.regex, '已复制屏蔽规则')
                }))
              }, (item: BlockKeywordInfo, index: number) => String(item.date))

              ListItem() {
                BottomSafeArea()
              }
            }
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
            .padding({ left: 6, right: 6 })
            .constraintSize({
              minHeight: '100%'
            })
            .nestedScroll({
              scrollForward: NestedScrollMode.PARENT_FIRST,
              scrollBackward: NestedScrollMode.PARENT_FIRST
            })
          }.tabBar(SubTabBarStyle.of('关键词屏蔽')
            .labelStyle({
              selectedColor: this.appTheme.fontEmphasize,
              font: {
                size: FontSizeEnum[this.appState.fontSize].vp16
              }
            })
            .indicator({
              color: this.appTheme.fontEmphasize
            }))
        }.barBackgroundColor(this.appTheme.backgroundSecondary)
        .barMode(BarMode.Scrollable)
        .barHeight(FontSizeEnum[this.appState.fontSize].vp56)
        .height('auto')

      }
    }.hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.onAccountUpdate()
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  BlockListPage()
}

export function openBlockList(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.BlockList)
}