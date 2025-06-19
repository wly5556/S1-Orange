import { URL } from '../../api/base'
import { Extcredits, Space, SpaceInfo } from '../../api/model/space'
import request from '../../api/request'
import wrapper from '../../api/wrapper'
import { AniSpeed, AvatarTransition, HeavyClickEffect, Spring035s } from '../../common/Animation'
import { ReloadController } from '../../common/BasicDataSource'
import { Avatar } from '../../common/component/Avatar'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { ImageViewer } from '../../common/component/ImageViewer'
import { OuterScroller } from '../../common/component/OuterScroller'
import {
  parseXML,
  PostContentParser,
  ThreadPostUINodeRender,
  UIRootNode
} from '../../common/component/ThreadPostContent'
import { TitleBar } from '../../common/component/TitleBar'
import { PropKey } from '../../common/Constants'
import { BLOCK_USER_LIST_STATE, BlockUser, UnblockUser } from '../../common/dataStore/BlockUser'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { openS1LinkLike } from '../../common/WantUitl'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { RoundPanel } from './Preferences'
import { openSearchPage, SearchPageParam, SearchType } from './SearchPage'
import { openUserThread, UserThreadParam } from './UserThread'
import { openWriteReply, WriteReplyMode, WriteReplyParam } from './WriteReply'
import { common } from '@kit.AbilityKit'

export interface UserSpaceParam {
  uid: string,
  username: string,
  avatarTransitionIndex?: string
}

class UserSpaceVM {
  username: string = ''
  uid: string = ''
  friends: string = '0'
  threads: string = '0'
  replies: string = '0'
  sig: UIRootNode[] = []
  credits: string = ''
  extcredits: ExtCreditVM[] = []
  dates: dateInfoVM[] = []
  groupTitle: string = ''
}

interface dateInfoVM {
  title: string
  date: string
}

interface ExtCreditVM extends Extcredits {
  count: string
}

@Component
export struct UserSpace {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @State pageParam: UserSpaceParam = {
    uid: '',
    username: '',
    avatarTransitionIndex: ''
  }
  @State userSpace: UserSpaceVM = new UserSpaceVM()
  @State imgViewerShow: boolean = false
  @State actionMenu: MenuElement[] = []
  @StorageProp(BLOCK_USER_LIST_STATE) blockList: Set<string> = new Set
  @StorageProp(PropKey.userId) @Watch('buildActionMenu') currUid?: string = undefined
  avatarSrc?: string
  avatarReload: ReloadController = new ReloadController()

  buildActionMenu(): void {
    const menu: MenuElement[] = [{
      value: '刷新头像',
      action: () => {
        this.avatarReload.reload()
      }
    }]
    if (this.pageParam.uid != this.currUid) {
      menu.push({
        value: this.blockList.has(this.pageParam.uid) ? '解除屏蔽' : '屏蔽',
        action: () => {
          if (this.blockList.has(this.pageParam.uid)) {
            UnblockUser(this.pageParam.uid)
          } else {
            BlockUser(this.pageParam.uid, this.pageParam.username)
          }
          this.getUIContext().getPromptAction().showToast({
            message: '操作完成'
          })
          this.popBack()
        }
      })
    }
    this.actionMenu = menu
  }

  requestUserSpace() {
    return new request<wrapper<Space>>(URL.USER_SPACE)
      .param('uid', this.pageParam.uid)
      .get()
      .then(v => {
        const space: SpaceInfo = v.Variables.space
        if (space) {
          this.pageParam.username =
            this.userSpace.username = space.username || ''
          this.userSpace.uid = space.uid || ''
          this.userSpace.friends = space.friends || '0'
          this.userSpace.threads = space.threads || '0'
          const numThreads = parseInt(space.threads)
          const numPosts = parseInt(space.posts)
          const numReplies = numPosts - numThreads
          this.userSpace.replies = isNaN(numReplies) ? '0' : numReplies.toString()
          const parsedSig = parseXML([{
            message: space.sightml
          }])
          this.userSpace.sig =
            space.sightml.length > 0 && parsedSig.length > 0 ? PostContentParser(parsedSig[0], []).node : []
          this.userSpace.groupTitle = space?.group?.grouptitle || ''
          this.userSpace.dates = [
            {
              title: '在线时间', date: (space.oltime || '') + '小时'
            },
            {
              title: '注册时间', date: space.regdate || ''
            },
            {
              title: '最后访问', date: space.lastvisit || ''
            },
            {
              title: '上次活动时间', date: space.lastactivity || ''
            },
            {
              title: '上次发表时间', date: space.lastpost || ''
            }]
          this.userSpace.credits = space.credits || '0'
          this.userSpace.extcredits.push({
            title: '积分',
            count: this.userSpace.credits,
            unit: ''
          })
          Object.keys(v.Variables.extcredits).forEach(k => {
            const credit: ExtCreditVM = {
              count: Reflect.get(space, 'extcredits' + k) || '0',
              title: v.Variables.extcredits[k].title || '',
              unit: v.Variables.extcredits[k].unit || ''
            }
            this.userSpace.extcredits.push(credit)
          })
        }
      })
  }

  popBack() {
    this.getUIContext().animateTo(AvatarTransition, () => {
      this.pathStack.pop(false)
    })
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: `${this.pageParam.username || ""}`,
          useRightMenu: true,
          menu: this.actionMenu,
          clickLeftButton: () => {
            this.popBack()
          }
        })
        Scroll() {
          Column() {
            Stack() {
              Column({ space: 8 }) {
                Row() {
                  Avatar({
                    uid: this.pageParam.uid,
                    avatarSize: 120,
                    transitionIndex: this.pageParam.avatarTransitionIndex,
                    avatarLoaded: src => this.avatarSrc = src,
                    reloadCtrl: this.avatarReload
                  }).onClick(e => {
                    if (this.avatarSrc) {
                      this.imgViewerShow = true
                    }
                  })
                }.justifyContent(FlexAlign.Center)
                .width('100%')
                .height(180)

                Text(this.userSpace.username)
                  .fontSize(FontSizeEnum[this.appState.fontSize].vp24)
                  .fontWeight(FontWeight.Medium)
                  .margin(6)
                Text('UID :' + this.userSpace.uid).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                Text(this.userSpace.groupTitle).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                if (this.userSpace.uid != '' && this.userSpace.uid != this.currUid) {
                  Stack() {
                    Image($r('app.media.envelope'))
                      .width(28)
                      .height(28)
                      .fillColor(this.appTheme.fontSecondary)
                  }
                  .width(50)
                  .height(50)
                  .borderRadius(25)
                  .transition(TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms100 }))
                  .backgroundColor('#11000000')
                  .position({
                    bottom: 12,
                    right: 12
                  })
                  .onClick(() => {
                    const param: WriteReplyParam = {
                      defaultTransition: true,
                      tid: '',
                      subjectToReply: this.userSpace.username,
                      pmUid: this.userSpace.uid,
                      mode: WriteReplyMode.NEW_PM
                    }
                    openWriteReply(this.pathStack, param, () => {
                    })
                  })
                }
              }.width('100%')
            }.margin({ bottom: 24 })

            if (this.userSpace.uid) {
              Column({ space: 8 }) {
                Row() {
                  Column({ space: 12 }) {
                    Text(this.userSpace.friends).fontSize(FontSizeEnum[this.appState.fontSize].vp18)
                    Text('好友').fontColor(this.appTheme.fontSecondary)
                  }.flexGrow(1).flexBasis(1)
                  .onClick(() => {
                    if (parseInt(this.userSpace.friends) > 0) {
                      const param: SearchPageParam = {
                        targetUid: this.pageParam.uid,
                        type: SearchType.Friend
                      }
                      openSearchPage(this.pathStack, param)
                    }
                  }).clickEffect(HeavyClickEffect)

                  Divider().vertical(true).height(64)
                  Column({ space: 12 }) {
                    Text(this.userSpace.threads).fontSize(FontSizeEnum[this.appState.fontSize].vp18)
                    Text('主题').fontColor(this.appTheme.fontSecondary)

                  }.flexGrow(1).flexBasis(1)
                  .onClick(() => {
                    const param: UserThreadParam = {
                      uid: this.pageParam.uid,
                      username: this.pageParam.username,
                      threadNum: parseInt(this.userSpace.threads),
                      replyNum: parseInt(this.userSpace.replies),
                      typeReply: false
                    }
                    openUserThread(this.pathStack, param)
                  }).clickEffect(HeavyClickEffect)

                  Divider().vertical(true).height(64)
                  Column({ space: 12 }) {
                    Text(this.userSpace.replies).fontSize(FontSizeEnum[this.appState.fontSize].vp18)
                    Text('回帖')
                      .fontColor(this.appTheme.fontSecondary)
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                  }.flexGrow(1).flexBasis(1)
                  .onClick(() => {
                    const param: UserThreadParam = {
                      uid: this.pageParam.uid,
                      username: this.pageParam.username,
                      threadNum: parseInt(this.userSpace.threads),
                      replyNum: parseInt(this.userSpace.replies),
                      typeReply: true
                    }
                    openUserThread(this.pathStack, param)
                  }).clickEffect(HeavyClickEffect)

                }.attributeModifier(new RoundPanel(this.appTheme.backgroundSecondary))

                if (this.userSpace.sig.length > 0) {
                  Column({ space: 6 }) {
                    Column() {
                      Text('个人签名')
                        .fontColor(this.appTheme.fontSecondary)
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp14).alignSelf(ItemAlign.Start)
                      ForEach(this.userSpace.sig, (uiRoot: UIRootNode) => {
                        ThreadPostUINodeRender({
                          uiRoot,
                          appTheme: this.appTheme,
                          fontSize: this.appState.fontSize,
                          lineSpace: this.appState.contentLineSpace,
                          fontSizeOverride: this.appState.fontSizeOverride,
                          copyOption: CopyOptions.LocalDevice,
                          onLinkClick: (href: string): void => {
                            openS1LinkLike(href, this.pathStack, this.getUIContext().getHostContext() as common.UIAbilityContext)
                          },
                          onImgClick: (url: string, index: number): void => {

                          }
                        })
                      })
                    }.padding(4)
                  }.attributeModifier(new RoundPanel(this.appTheme.backgroundSecondary))
                }
                Row() {
                  GridRow({ gutter: 1 }) {
                    ForEach(this.userSpace.dates, (item: dateInfoVM) => {
                      GridCol({
                        span: {
                          xs: 12,
                          md: 6,
                        }
                      }) {
                        Column({ space: 4 }) {
                          Text(item.title)
                            .fontColor(this.appTheme.fontEmphasize)
                            .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                          Text(item.date).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                        }.padding(4).width('100%').alignItems(HorizontalAlign.Start)
                      }
                    })
                  }
                }.attributeModifier(new RoundPanel(this.appTheme.backgroundSecondary))
                .transition(TransitionEffect.translate({ y: -35 }).animation(Spring035s))

                Row() {
                  GridRow({ gutter: 1 }) {
                    ForEach(this.userSpace.extcredits, (item: ExtCreditVM) => {
                      GridCol({
                        span: {
                          xs: 12,
                          md: 6,
                        }
                      }) {
                        Column({ space: 4 }) {
                          Text(item.title)
                            .fontColor(this.appTheme.fontEmphasize)
                            .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                          Text(item.count + ' ' + item.unit).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                        }.padding(4).width('100%').alignItems(HorizontalAlign.Start)
                      }
                    })
                  }
                }.attributeModifier(new RoundPanel(this.appTheme.backgroundSecondary))
                .transition(TransitionEffect.translate({ y: -45 }).animation(Spring035s))
              }.transition(TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms300 }))
            } else {
              LoadingProgress()
                .width(64)
                .height(64)
                .color($r('sys.color.ohos_id_color_emphasize'))
            }
            BottomSafeArea()
          }.padding(6)
          .backgroundColor(this.appTheme.backgroundTertiary)
          .constraintSize({
            minHeight: '100%'
          })
        }.width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
      }
    }.hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.pageParam = context.pathInfo.param as UserSpaceParam
      this.requestUserSpace()
      this.buildActionMenu()
    }).onBackPressed(() => {
      this.popBack()
      return true
    }).bindContentCover($$this.imgViewerShow, this.ImageViewerBuilder, {
      modalTransition: ModalTransition.ALPHA,
      onWillDismiss: (() => {
        this.getUIContext().animateTo(Spring035s, () => {
          this.imgViewerShow = false
        })
      }),
    })
  }

  @Builder
  ImageViewerBuilder() {
    Stack() {
      ImageViewer({
        param: {
          startAt: 0,
          urls: this.avatarSrc ? [this.avatarSrc] : []
        },
        showUp: this.imgViewerShow
      })
    }.transition(TransitionEffect.opacity(.99).animation({ duration: AniSpeed.ms200 })) // 避免退出时没有转场动画就直接消失
  }
}


@Builder
export function RegisterBuilder() {
  UserSpace()
}

export function openUserSpace(param: UserSpaceParam, pathStack: NavPathStack) {
  animateTo(AvatarTransition, () => {
    openOrJumpTo(pathStack, PageNameEnum.UserSpace, param, false, (u: object) => {
      return (u as UserSpaceParam).uid == param.uid
    })
  })
}

export function openUserSpaceByLink(href: string, pathStack: NavPathStack, onFailed: () => void) {
  if (href.includes(URL.USER_SPACE_LINK)) {
    const uid = href.match(/uid=(\d+)/)
    if (uid) {
      const param: UserSpaceParam = {
        uid: uid[1],
        username: ''
      }
      openUserSpace(param, pathStack)
      return
    }
  } else if (href.includes(URL.WEB_BASE)) {
    const uid = href.match(/space-uid-(\d+).html/)
    if (uid) {
      const param: UserSpaceParam = {
        uid: uid[1],
        username: ''
      }
      openUserSpace(param, pathStack)
      return
    }
  }
  onFailed()
}