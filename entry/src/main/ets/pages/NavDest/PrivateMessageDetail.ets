import { ArrayDataSource } from '../../common/BasicDataSource'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import { PrivateMessage, PrivateMessageList } from '../../api/model/privateMessage'
import request from '../../api/request'
import wrapper from '../../api/wrapper'
import { URL } from '../../api/base'
import { Avatar } from '../../common/component/Avatar'
import {
  parseXML,
  PostContentParser,
  PostToParse,
  ThreadPostUINodeRender,
  UIRootNode
} from '../../common/component/ThreadPostContent'
import { openUserSpace, UserSpaceParam } from './UserSpace'
import { openS1LinkLike } from '../../common/WantUitl'
import { ImageViewer, ImageViewerParam } from '../../common/component/ImageViewer'
import { AniSpeed, HeavyClickEffect, Spring035s } from '../../common/Animation'
import { formatRelativeTime } from '../../common/TimeFormat'
import { openWriteReply, WriteReplyMode, WriteReplyParam, WriteReplyPopData } from './WriteReply'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PropKey } from '../../common/Constants'

interface PrivateMessageVM {
  authorid: string,
  timeStamp: Date,
  message: UIRootNode[],
  imgUrl: string[],
  placeholder?: boolean
}

class PmDataSource extends ArrayDataSource<PrivateMessageVM[]> {
  private onPageSizeChange: () => void

  constructor(onPageSizeChange: () => void) {
    super()
    this.data.push([])
    this.onPageSizeChange = onPageSizeChange
  }

  private touid: string = ''

  public setToUid(uid: string) {
    this.touid = uid
    this.notifyDataReload()
  }

  public reload() {
    this.data = this.data.map(() => [])
    this.notifyDataReload()
    return this
  }

  override getData(index: number): PrivateMessageVM[] {
    if (this.touid == '') {
      return []
    }
    if (this.data[index].length == 0) {
      new request<wrapper<PrivateMessageList>>(URL.PM_DETAIL)
        .param('page', (index + 1).toString())
        .param('touid', this.touid)
        .get()
        .then(v => {
          let totalPage = Math.ceil(parseInt(v.Variables.count) / parseInt(v.Variables.perpage))
          if (isNaN(totalPage)) {
            totalPage = 1
          }
          const padding = totalPage - this.data.length
          this.data[index] = v.Variables.list.map(pm => {
            const messageToParse: PostToParse[] = [{
              message: pm.message
            }]
            const parsedMsg = parseXML(messageToParse)
            const imgUrl: string[] = []
            const vm: PrivateMessageVM = {
              authorid: pm.authorid,
              timeStamp: new Date(parseInt(pm.dateline) * 1000),
              message: parsedMsg.length > 0 ? PostContentParser(parsedMsg[0], imgUrl).node : [],
              imgUrl
            }
            return vm
          })
          if (padding > 0) {
            const blankData: PrivateMessageVM[] = []
            const now = new Date()
            for (let i = 0; i < 5; i++) {
              blankData.push({
                placeholder: true,
                authorid: '',
                timeStamp: now,
                message: [],
                imgUrl: []
              })
            }
            for (let i = 0; i < padding; i++) {
              this.data.push([])
            }
            this.notifyDataReload()
            setTimeout(() => {
              this.onPageSizeChange()
            }, 100)
          } else {
            this.notifyDataChange(index)
          }
        })
      return []
    } else {
      return this.data[index]
    }
  }
}

export interface PmDetailParam {
  touid: string
  tousername: string
}

const SMALL_AVATAR_WIDTH = 54
const LARGE_AVATAR_WIDTH = 64

@Component
export struct PmDetail {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @State imgViewer: ImageViewerParam = { urls: [], startAt: 0 }
  @State nowDate: Date = new Date()
  dateInterval: number = 0
  scroller: ListScroller = new ListScroller()
  dataSource: PmDataSource = new PmDataSource(() => {
    this.scroller.scrollEdge(Edge.Bottom)
  })
  context = getContext(this) as common.UIAbilityContext
  @State pageParam: PmDetailParam = {
    touid: '',
    tousername: ''
  }
  @State imgViewerShow: boolean = false
  @StorageProp(PropKey.userId) @Watch('onAccountUpdate') uid?: string = undefined

  onAccountUpdate() {
    this.popBack()
  }


  aboutToAppear(): void {
    this.dateInterval = setInterval(() => {
      this.nowDate = new Date()
    }, 60000)
  }

  aboutToDisappear(): void {
    clearInterval(this.dateInterval)
  }

  @Builder
  ImageViewerBuilder() {
    Stack() {
      ImageViewer({
        param: this.imgViewer,
        showUp: this.imgViewerShow
      })
    }.transition(TransitionEffect.opacity(.99).animation({ duration: AniSpeed.ms200 })) // 避免退出时没有转场动画就直接消失
  }

  popBack() {
    this.pathStack.pop()
  }

  @LocalBuilder
  avatar(uid: string) {
    Avatar({
      uid: uid,
      transitionIndex: undefined
    }).onClick(() => {
      const param: UserSpaceParam = {
        uid: uid,
        username: '',
      }
      openUserSpace(param, this.pathStack)
    })
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: this.pageParam.tousername,
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        }) {
          Stack() {
            Image($r('app.media.square_and_pencil')).width(24).height(24)
              .fillColor(this.appTheme.titleBarFont)
          }
          .width(50)
          .height(50)
          .clickEffect(HeavyClickEffect)
          .transition(TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms100 }))
          .onClick(() => {
            const param: WriteReplyParam = {
              defaultTransition: true,
              tid: '',
              subjectToReply: this.pageParam.tousername,
              pmUid: this.pageParam.touid,
              mode: WriteReplyMode.NEW_PM
            }
            openWriteReply(this.pathStack, param, (data: PopInfo) => {
              if ((data.result as WriteReplyPopData).replied) {
                this.dataSource.reload()
                this.nowDate = new Date()
              }
            })
          })
        }

        List({ scroller: this.scroller, space: 12 }) {
          LazyForEach(this.dataSource, (item: PrivateMessageVM[]) => {
            ListItem() {
              Column({ space: 12 }) {
                ForEach(item, (pm: PrivateMessageVM) => {
                  if (pm.placeholder) {
                    Row().width('100%').height(72)
                  } else {
                    Row() {
                      Text(formatRelativeTime(this.nowDate, pm.timeStamp)).fontSize(FontSizeEnum[this.appState.fontSize].vp14).opacity(.6)
                    }.width('100%')
                    .justifyContent(FlexAlign.Center)

                    Row() {
                      Stack() {
                        if (pm.authorid == this.pageParam.touid) {
                          this.avatar(pm.authorid)
                        }
                      }.width(pm.authorid == this.pageParam.touid ? SMALL_AVATAR_WIDTH : LARGE_AVATAR_WIDTH)

                      Column() {
                        ForEach(pm.message, (uiRoot: UIRootNode) => {
                          ThreadPostUINodeRender({
                            uiRoot,
                            appTheme: this.appTheme,
                            fontSize: this.appState.fontSize,
                            lineSpace: this.appState.contentLineSpace,
                            fontSizeOverride: this.appState.fontSizeOverride,
                            copyOption: CopyOptions.LocalDevice,
                            onLinkClick: (href: string): void => {
                              openS1LinkLike(href, this.pathStack, this.context)
                            },
                            onImgClick: (url: string, index: number): void => {
                              this.imgViewer = {
                                urls: pm.imgUrl,
                                startAt: index
                              }
                              animateTo(Spring035s, () => this.imgViewerShow = true)
                            }
                          })
                        })
                      }
                      .transition(TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms100 }))
                      .flexGrow(1)
                      .flexShrink(1)
                      .padding(12)
                      .backgroundColor(pm.authorid == this.pageParam.touid ?
                        (this.appTheme.isDark ? '#33ffffff' : '#11000000') :
                        (this.appTheme.isDark ? '#4b6cdbff' : '#2200B0FF'))
                      .borderRadius(12)

                      Stack() {
                        if (pm.authorid != this.pageParam.touid) {
                          this.avatar(pm.authorid)
                        }
                      }.width(pm.authorid != this.pageParam.touid ? SMALL_AVATAR_WIDTH : LARGE_AVATAR_WIDTH)
                    }.width('100%')
                    .alignItems(VerticalAlign.Top)
                  }
                })
              }
            }
          }, (item: PrivateMessage[], index: number) => JSON.stringify(item) + index.toString())
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
      this.pageParam = context.pathInfo.param as PmDetailParam
      this.dataSource.setToUid(this.pageParam.touid)
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
    .bindContentCover($$this.imgViewerShow, this.ImageViewerBuilder, {
      modalTransition: ModalTransition.NONE,
      onWillDismiss: (() => {
        this.getUIContext().animateTo(Spring035s, () => {
          this.imgViewerShow = false
        })
      }),
    })
  }
}

@Builder
export function RegisterBuilder() {
  PmDetail()
}

export function openPmDetail(pathStack: NavPathStack, param: PmDetailParam) {
  openOrJumpTo(pathStack, PageNameEnum.PmDetail, param)
}