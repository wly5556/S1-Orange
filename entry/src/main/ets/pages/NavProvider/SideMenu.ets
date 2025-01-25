import { common } from '@kit.AbilityKit'
import { getUserNotice } from '../../api/request'
import { logout, removeAccount, switchAccount } from '../../common/account/AccountManager'
import { ClickDarkenEffect, HeavyClickEffect, MenuFlyDownAni, MenuFlyUpAni } from '../../common/Animation'
import { Avatar } from '../../common/component/Avatar'
import { LongPressDelete } from '../../common/component/LongPressDelete'
import { PropKey } from '../../common/Constants'
import { Event } from '../../common/Events'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceManager } from '../../config/UserConfig'
import { UserAccount } from '../../config/v1/default'
import { openAboutApp } from '../NavDest/AboutApp'
import { openBlockList } from '../NavDest/BlockList'
import { openDraftPage } from '../NavDest/DraftPage'
import { openFavoriteList } from '../NavDest/FavoriteList'
import { openNoteList } from '../NavDest/NoteList'
import { openPreferences } from '../NavDest/Preferences'
import { openPrivateMessage } from '../NavDest/PrivateMessage'
import { openUserSpace, UserSpaceParam } from '../NavDest/UserSpace'
import { openHistoryPage } from '../NavDest/ViewHistory'
import { PreferenceState } from './NavigationPage'

const avatarTransitionId = 'avatar_currentUser'

@Component
export struct SideMenu {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appState: PreferenceState
  context = getContext(this) as common.UIAbilityContext
  uidList: string[] = []
  @State account_list: Record<string, UserAccount> = {}
  @State currUsername: string = ''
  @StorageProp(PropKey.userId) @Watch('updateState') currUid?: string = undefined
  @State showAccounts: boolean = false
  @State clickEffectModifier: AttributeModifier<CommonAttribute> = new ClickDarkenEffect()
  @State switchingIntoAccount: string = ''
  @State newReply: number = 0

  aboutToAppear(): void {
    this.updateState()
  }

  updateState() {
    PreferenceManager.readonly(conf => {
      this.account_list = conf.account_list
      this.uidList = Object.keys(conf.account_list)
      this.currUsername = conf.user_name
    })
  }

  @Consume sideMenuShow: number

  @LocalBuilder
  MenuButton(icon: Resource, text: string, action: () => void) {
    Row() {
      Image(icon)
        .width(FontSizeEnum[this.appState.fontSize].vp24)
        .height(FontSizeEnum[this.appState.fontSize].vp24)
        .fillColor($r('sys.color.font_primary'))
      Text(text)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
        .fontWeight(FontWeight.Medium)
        .margin({ left: 30 })
        .fontColor($r('sys.color.font_primary'))
    }
    .height(FontSizeEnum[this.appState.fontSize].vp36)
    .width('100%')
    .clickEffect(HeavyClickEffect)
    .onClick(() => {
      this.sideMenuShow = 0
      action()
    })
  }

  @LocalBuilder
  UserAccount(username: string, uid: string) {
    Row() {
      Avatar({
        avatarSize: 32,
        uid,
        transitionIndex: username
      })
      Text(username)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .padding({ left: 20 })
        .flexGrow(1)
        .flexShrink(1)
      if (uid == this.switchingIntoAccount) {
        LoadingProgress()
          .width(32)
          .height(32)
          .margin({ right: 20 })
          .color($r('sys.color.ohos_id_color_emphasize'))
          .zIndex(100)
      } else if (uid == this.currUid) {
        Button('登出')
          .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .alignSelf(ItemAlign.End)
          .fontColor($r('sys.color.font_secondary'))
          .onClick(e => {
            this.getUIContext().showAlertDialog(
              {
                title: '确定要退出登录？',
                message: '',
                buttons: [
                  {
                    value: '取消',
                    action: () => {
                    }
                  },
                  {
                    value: '确定退出',
                    fontColor: Color.Red,
                    action: () => {
                      logout()
                    }
                  }]
              })
          })
      }
    }
    .height(FontSizeEnum[this.appState.fontSize].vp40)
    .width('100%')
    .padding({ left: 20, right: 20 })
    .clickEffect({ level: ClickEffectLevel.MIDDLE })
    .onClick(e => {
      if (username != this.currUsername && this.switchingIntoAccount == '') {
        this.switchingIntoAccount = uid
        switchAccount(uid).then(() => {
          setTimeout(() => this.switchingIntoAccount = '', 200) // 防操作过快
        })
      }
    })
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: 12 }) {
          Row()
          Avatar({
            avatarSize: 70,
            uid: this.currUid
          }).geometryTransition(avatarTransitionId)
            .onClick(v => {
              if (this.currUid) {
                const userSpaceParam: UserSpaceParam = {
                  uid: this.currUid,
                  username: this.currUsername,
                  avatarTransitionIndex: avatarTransitionId
                }
                openUserSpace(userSpaceParam, this.pathStack)
                this.sideMenuShow = 0
              } else {
                this.context.eventHub.emit(Event.OpenLoginDialog)
              }
            })
          Text(this.currUsername && this.currUsername.length > 0 ? this.currUsername : '未登录')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp18)
            .height(30)
            .fontWeight(FontWeight.Medium)
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .onClick(() => {
          this.showAccounts = !this.showAccounts
        })
        .width('100%')
        .padding({ left: 30, bottom: 20 })
        .height(150)
        .justifyContent(FlexAlign.End)
        .alignItems(HorizontalAlign.Start)

        Divider()
        if (this.showAccounts) {
          Column({ space: 16 }) {
            ForEach(Object.values(this.account_list), (account: UserAccount, index: number) => {
              if (this.uidList[index] != this.currUid) {
                LongPressDelete({
                  delete: () => {
                    this.getUIContext().showAlertDialog({
                      title: '二次确认',
                      message: '删除账号后，本地存储的历史记录、草稿等信息将一并被删除',
                      buttons: [
                        {
                          value: '取消',
                          action: () => {
                          }
                        },
                        {
                          value: '确定删除',
                          fontColor: Color.Red,
                          action: async () => {
                            await removeAccount(this.uidList[index])
                            this.updateState()
                          }
                        }]
                    })
                  }
                }) {
                  this.UserAccount(account.name, this.uidList[index])
                }
              } else {
                this.UserAccount(account.name, this.uidList[index])
              }
            })
            Stack() {
              this.MenuButton($r('app.media.plus'), '添加账户', () => {
                this.context.eventHub.emit(Event.OpenLoginDialog)
              })
            }.padding({ left: 20, right: 20 })

          }.transition(MenuFlyDownAni)
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 20, bottom: 20 })
        } else {
          Column({ space: 16 }) {
            this.MenuButton($r('app.media.house'), '首页', () => {
              this.context.eventHub.emit(Event.ReturnToHomePage)
            })
            this.MenuButton($r('app.media.star_fill'), '收藏', () => {
              openFavoriteList(this.pathStack)
            })
            this.MenuButton($r('app.media.arrow_counterclockwise_clock'), '历史记录', () => {
              openHistoryPage(this.pathStack)
            })
            Divider()
            Badge({
              style: {},
              position: BadgePosition.Right,
              count: this.newReply
            }) {
              this.MenuButton($r('app.media.message'), '提醒', () => {
                openNoteList(this.pathStack)
              })
            }

            this.MenuButton($r('app.media.square_and_pencil'), '草稿', () => {
              openDraftPage(this.pathStack)
            })
            this.MenuButton($r("app.media.envelope"), '私信', () => {
              openPrivateMessage(this.pathStack)
            })
            this.MenuButton($r("app.media.nosign"), '黑名单', () => {
              openBlockList(this.pathStack)
            })
            Divider()
            this.MenuButton($r('app.media.gearshape'), '设置', () => {
              openPreferences(this.pathStack)
            })
            this.MenuButton($r('app.media.questionmark_circle'), '关于', () => {
              openAboutApp(this.pathStack)
            })
          }.transition(MenuFlyUpAni)
          .padding(20)
        }
        if (this.currUsername.length == 0) {
          Row() {
            Text('部分论坛图片/版面要求登录查看').opacity(0.6)
          }
          .width('100%')
          .padding(12)
          .justifyContent(FlexAlign.Center)
        }
      }.constraintSize({
        minHeight: '100%'
      })
      .onVisibleAreaChange([0, 1], (isVisible: boolean, currentRatio: number) => {
        if (currentRatio == 0) {
          this.showAccounts = false
        }
        if (currentRatio == 1) {
          const notice = getUserNotice()
          this.newReply = parseInt(notice.newmypost)
        }
      })
    }.scrollBar(BarState.Off)

  }
}