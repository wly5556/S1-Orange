import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import { LengthUnit, promptAction, window } from '@kit.ArkUI'
import { TitleBar } from '../../common/component/TitleBar'
import request from '../../api/request'
import { URL } from '../../api/base'
import { AniSpeed, ClickDarkenEffect, HeavyClickEffect, SpringCurve } from '../../common/Animation'
import { SmilyPicker } from '../../common/component/SmilyPicker'
import { extractReplyPageInfo, ReplyImagePicker } from '../../common/component/ReplyImagePicker'
import wrapper from '../../api/wrapper'
import Account from '../../api/model/account'
import { unescapeXml } from '../../common/XmlParser'
import { buildFontColorPicker, FontColorPickerSheetOption } from '../../common/component/FontColorPicker'
import {
  DraftDbSetUser,
  DraftItem,
  QueryDraftItem,
  RecordDraft,
  RemoveDraftIfExist
} from '../../common/dataStore/DraftData'
import { openThreadPost, ThreadPostParam } from './ThreadPostList'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PropKey, SafeArea } from '../../common/Constants'
import { PostSignature } from '../../common/PostSignature'

export enum WriteReplyMode {
  NEW_THREAD,
  EDIT,
  NEW_POST,
  NEW_POST_QUOTE,
  NEW_PM,
}

export const WriteReplyPageTitle: string[] = []

WriteReplyPageTitle[WriteReplyMode.NEW_THREAD] = '发布新帖'
WriteReplyPageTitle[WriteReplyMode.EDIT] = '编辑'
WriteReplyPageTitle[WriteReplyMode.NEW_POST] = '回复主题帖'
WriteReplyPageTitle[WriteReplyMode.NEW_POST_QUOTE] = '引用回帖'
WriteReplyPageTitle[WriteReplyMode.NEW_PM] = '发送私信'

export interface WriteReplyParam {
  defaultTransition: boolean
  tid: string
  subjectToReply: string
  fid?: string
  mode: WriteReplyMode
  editPid?: string
  quotePid?: string
  draft?: DraftItem
  pmUid?: string
}

class FieldToInput {
  content: string
  subject: string
  threadTypeIndex: number

  constructor(content: string = '', subject: string = '', threadTypeIndex: number = 0) {
    this.content = content
    this.subject = subject
    this.threadTypeIndex = threadTypeIndex
  }

  static from(other: FieldToInput) {
    const that = new FieldToInput()
    that.content = other.content
    that.subject = other.subject
    that.threadTypeIndex = other.threadTypeIndex
    return that
  }

  equalsTo(other: FieldToInput) {
    return this.content == other.content && this.subject == other.subject &&
      this.threadTypeIndex == other.threadTypeIndex
  }
}

export interface WriteReplyPopData {
  replied: boolean
}

export const TOOL_BAR_HEIGHT = 48

const REPLY_MIN_INTERVAL = 1000 // ms
const REPLY_NOTIFICATION_MAX_LENGTH = 100

interface PostFormatterBlock {
  img: ResourceStr
  name: string
  prefix: string
  suffix: string
}

interface ThreadType {
  name: string
  id: string
}

@Component
export struct WriteReply {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  context = getContext(this) as common.UIAbilityContext
  @State pageParam: WriteReplyParam = {
    defaultTransition: true,
    tid: '',
    subjectToReply: '',
    fid: '',
    mode: WriteReplyMode.NEW_POST
  }
  @State fieldToInput: FieldToInput = new FieldToInput()
  @State initialFieldToInput: FieldToInput = new FieldToInput()
  writeHandler: WriteHandler = new EmptyWriteHandler()
  @State threadTypeList: ThreadType[] = []
  @StorageProp(SafeArea.bottom) bottomRectHeight: number = 0
  @State keyboardAvoidHeight: number = 0
  @State keyboardHeight: number = 350
  @State showTools: boolean = false
  @StorageProp(PropKey.userId) @Watch('loadUser') uid?: string = undefined
  @State quote?: Quote = undefined
  @State essentialDataReady: boolean = false
  @State sendingReply: boolean = false
  @State fontColorPickerShow: boolean = false
  popData: WriteReplyPopData = {
    replied: false
  }
  cursorRePos?: number = undefined
  controller: TextAreaController = new TextAreaController()
  toolPanelController: SwiperController = new SwiperController()
  lastRequestReply: number = 0
  popped: boolean = false

  popBack() {
    if (!this.popped) {
      this.pathStack.pop(this.popData, this.pageParam.defaultTransition)
      this.popped = true // 未登录时会触发两次popBack，防止重复退出
    }
  }

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(currentWindow => {
      currentWindow.on('keyboardHeightChange', (data: number) => {
        if (data != 0) {
          this.keyboardHeight = px2vp(data)
        }
      })
      currentWindow.on('avoidAreaChange', data => {
        if (data.type !== window.AvoidAreaType.TYPE_KEYBOARD) {
          return
        }
        this.keyboardAvoidHeight = px2vp(data.area.bottomRect.height)
      })
    })
  }

  aboutToDisappear(): void {
    if (!this.popData.replied) {
      if (!this.fieldToInput.equalsTo(this.initialFieldToInput)) {
        if (this.fieldToInput.equalsTo(new FieldToInput())) {
          RemoveDraftIfExist(this.pageParam)
          this.getUIContext().getPromptAction().showToast({
            message: '已清除对应的草稿'
          })
        } else {
          RecordDraft(this.pageParam, this.fieldToInput.content, this.pageParam.subjectToReply,
            this.fieldToInput.subject,
            this.fieldToInput.threadTypeIndex)
          this.getUIContext().getPromptAction().showToast({
            message: '未发表内容已保存至草稿'
          })
        }
      }
    }
  }

  loadUser() {
    if (!this.uid || this.uid.length == 0) {
      this.criticalError()
    } else {
      DraftDbSetUser(this.uid)
    }
  }

  insertText(text: string) {
    const cursor = this.controller.getCaretOffset().index
    this.fieldToInput.content =
      this.fieldToInput.content.slice(0, cursor) + text + this.fieldToInput.content.slice(cursor)
    this.cursorRePos = cursor + text.length
  }

  wrapText(prefix: string, suffix: string) {
    const cursor = this.controller.getCaretOffset().index
    this.fieldToInput.content =
      this.fieldToInput.content.slice(0, cursor) + prefix + suffix + this.fieldToInput.content.slice(cursor)
    this.cursorRePos = cursor + prefix.length
  }

  @LocalBuilder
  toolBarButton(img: ResourceStr, index: number) {
    Stack() {
      Image(img)
        .width(FontSizeEnum[this.appState.fontSize].vp32)
        .height(FontSizeEnum[this.appState.fontSize].vp32)
        .fillColor(this.appTheme.fontSecondary)
        .draggable(false)
    }
    .width(TOOL_BAR_HEIGHT)
    .height(TOOL_BAR_HEIGHT)
    .opacity(0.6)
    .borderRadius(5)
    .attributeModifier(new ClickDarkenEffect)
    .clickEffect(HeavyClickEffect)
    .padding({ left: 40, right: 40 })
    .onClick(e => {
      this.toolPanelController.changeIndex(index, this.showTools ? true : false)
      this.showTools = true
      this.getUIContext().getFocusController().clearFocus()
    })
  }

  @LocalBuilder
  PostFormatterButton(item: PostFormatterBlock, action: () => void) {
    GridCol({
      span: {
        xs: 8,
        md: 5,
      }
    }) {

      Column() {
        Image(item.img)
          .width(40)
          .height(40)
          .opacity(0.7)
          .fillColor(this.appTheme.fontPrimary)
        Text(item.name)
          .width('100%')
          .textAlign(TextAlign.Center)
          .minFontSize(FontSizeEnum[this.appState.fontSize].vp14)
          .maxLines(1)
          .maxFontSize(FontSizeEnum[this.appState.fontSize].vp16)
          .margin({ top: 12 })
      }.width('100%')
    }.borderRadius(8)
    .clickEffect(HeavyClickEffect)
    .onClick(() => action())
  }

  @LocalBuilder
  quoteCard() {
    if (this.quote) {
      Text(this.quote.postInfo)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
        .opacity(0.7)
        .lineSpacing({
          value: 8,
          unit: LengthUnit.VP
        }).copyOption(CopyOptions.LocalDevice)
      Text(this.quote.message)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
        .lineSpacing({
          value: 8,
          unit: LengthUnit.VP
        }).copyOption(CopyOptions.LocalDevice)
    }
  }

  @LocalBuilder
  loadingCard() {
    Row() {
      LoadingProgress()
        .width(64)
        .height(64)
        .color($r('sys.color.font_emphasize'))
    }.width('100%')
    .justifyContent(FlexAlign.SpaceAround)
  }

  @LocalBuilder
  replyThreadCard() {
    Row() {
      Column() {
        Text('回复主题帖：')
          .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
          .opacity(0.7)
          .lineSpacing({
            value: 8,
            unit: LengthUnit.VP
          }).copyOption(CopyOptions.LocalDevice)
        Text(this.pageParam.subjectToReply)
          .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
          .lineSpacing({
            value: 8,
            unit: LengthUnit.VP
          }).copyOption(CopyOptions.LocalDevice)
      }.flexGrow(1)
      .flexShrink(1)
      .alignItems(HorizontalAlign.Start)

      Button('查看')
        .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .onClick(() => {
          this.popBack()
          const param: ThreadPostParam = {
            tid: this.pageParam.tid,
            subject: this.pageParam.subjectToReply
          }
          openThreadPost(param, this.pathStack, true, this.pageParam.defaultTransition)
        })
    }.width('100%')
  }

  build() {
    NavDestination() {
      Column() {
        TitleBar({
          titleContent: WriteReplyPageTitle[this.pageParam.mode],
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          },
        }) {
          Stack() {
            if (this.sendingReply) {
              LoadingProgress()
                .width(40)
                .height(40)
                .color($r('sys.color.ohos_id_color_emphasize'))
            } else {
              Image($r('app.media.paperplane_right_fill'))
                .width(28)
                .height(28)
                .fillColor(this.appTheme.titleBarFont)
                .rotate({
                  angle: -45
                })
            }
          }.width(50)
          .height(50)
          .clickEffect(HeavyClickEffect)
          .onClick(() => {
            if (this.sendingReply) {
              return
            }
            if (Date.now() - REPLY_MIN_INTERVAL < this.lastRequestReply) {
              this.getUIContext().getPromptAction().showToast({
                message: '发送间隔过短，请稍后再试'
              })
              return
            }
            if (this.fieldToInput.content.length == 0) {
              this.getUIContext().getPromptAction().showToast({
                message: '内容不应为空'
              })
              return
            }
            this.sendingReply = true
            this.writeHandler.send(this.pageParam, this.fieldToInput
              , (msg?: string): void => this.replySucceed(msg),
              (msg?: string): void => this.replyError(msg), this.initialFieldToInput)
          })
        }

        Scroll() {
          Column() {
            if (this.pageParam.mode == WriteReplyMode.NEW_PM) {
              Text(`向 ${this.pageParam.subjectToReply} 发送私信: `)
                .width('100%')
                .textAlign(TextAlign.Start)
                .opacity(.7)
              Divider().padding({
                top: 20,
                bottom: 20
              })
            } else if (this.pageParam.mode == WriteReplyMode.NEW_THREAD
              || (this.pageParam.mode == WriteReplyMode.EDIT && this.initialFieldToInput.subject) // 编辑主题帖
            ) {
              if (this.essentialDataReady) {
                Column({ space: 12 }) {
                  Row({ space: 12 }) {
                    Text('分类')
                    Select(this.threadTypeList.map((v): SelectOption => ({
                      value: v.name
                    }))).selected($$this.fieldToInput.threadTypeIndex)
                      .value(this.threadTypeList.length > 0 ?
                      this.threadTypeList[this.fieldToInput.threadTypeIndex].name :
                        '')
                      .flexGrow(1)
                  }.width('100%')

                  TextArea({
                    text: $$this.fieldToInput.subject,
                    placeholder: '填写标题'
                  }).maxLength(80).fontSize(FontSizeEnum[this.appState.fontSize].vp18)
                }.margin({ bottom: 20 })
              } else {
                this.loadingCard()
              }
            } else if (this.pageParam.mode == WriteReplyMode.NEW_POST_QUOTE || this.pageParam.subjectToReply) {
              Column() {
                if (this.pageParam.mode == WriteReplyMode.NEW_POST_QUOTE
                  && this.quote) {
                  this.quoteCard()
                } else if (this.pageParam.subjectToReply && this.essentialDataReady) {
                  this.replyThreadCard()
                } else {
                  this.loadingCard()
                }
              }
              .alignItems(HorizontalAlign.Start)
              .borderRadius(8)
              .padding(6)
              .opacity(0.9)
              .backgroundColor(this.appTheme.isDark ? '#1fffffff' : '#0f000000')
              .width('100%')
              .transition(TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms120 }))

              Divider().margin(12)
            }
            TextArea({
              text: $$this.fieldToInput.content,
              controller: this.controller,
              placeholder: '写点内容吧...',
            })
              .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              .onChange(() => {
                if (this.cursorRePos) {
                  this.controller.caretPosition(this.cursorRePos)
                  this.cursorRePos = undefined
                }
              })
              .lineSpacing({
                value: 8,
                unit: LengthUnit.VP
              })
              .constraintSize({
                minHeight: '100%'
              })
              .backgroundColor('#00000000')
              .padding(0)
              .borderRadius(0)
              .onFocus(() => {
                this.showTools = false
                this.toolPanelController.changeIndex(0)
              })
          }
        }
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
        .width('100%')
        .padding(16)
        .flexGrow(1)
        .flexShrink(1)
        .backgroundColor(this.appTheme.backgroundSecondary)

        Row() {
          this.toolBarButton($r('app.media.face_smiling'), 1)
          this.toolBarButton($r('app.media.picture'), 2)
          this.toolBarButton($r('app.media.textformat_size_square'), 3)
        }
        .width('100%')
        .backgroundColor(this.appTheme.backgroundTertiary)
        .height(TOOL_BAR_HEIGHT)
        .shadow(this.showTools ? ShadowStyle.OUTER_DEFAULT_XS : undefined)
        .animation({ duration: 100 })
        .zIndex(100)

        if (this.uid) {
          Row() {
            Swiper(this.toolPanelController) {
              Column() {
                // blank
              }.width('100%')
              .height('100%')

              SmilyPicker({
                onPicked: (text): void => this.insertText(text)
              })

              ReplyImagePicker({
                getWriteHandler: () => this.writeHandler,
                onPicked: (text): void => this.insertText(text),
                onRemoval: (text): void => {
                  this.fieldToInput.content = this.fieldToInput.content.replaceAll(text, '')
                },
                currentMode: this.pageParam.mode
              })

              Scroll() {
                Column() {
                  GridRow({
                    gutter: 12,
                    columns: 40
                  }) {
                    ForEach([
                      {
                        img: $r('app.media.bold'),
                        name: '加粗',
                        prefix: '[b]',
                        suffix: '[/b]'
                      },
                      {
                        img: $r('app.media.italic'),
                        name: '斜体',
                        prefix: '[i]',
                        suffix: '[/i]'
                      },
                      {
                        img: $r('app.media.underline'),
                        name: '下划线',
                        prefix: '[u]',
                        suffix: '[/u]'
                      },
                      {
                        img: $r('app.media.picture'),
                        name: '外链图片',
                        prefix: '[img]',
                        suffix: '[/img]'
                      },
                      {
                        img: $r('app.media.paperclip'),
                        name: '链接',
                        prefix: '[url=',
                        suffix: '][/url]'
                      },
                      {
                        img: $r('app.media.strikethrough'),
                        name: '删除线',
                        prefix: '[s]',
                        suffix: '[/s]'
                      },
                      {
                        img: $r('app.media.ellipsis_message_fill'),
                        name: '引用',
                        prefix: '[quote]',
                        suffix: '[/quote]'
                      }, {
                      img: $r('app.media.bold'),
                      name: '积分权限',
                      prefix: '[hide=积分数]',
                      suffix: '[/hide]'
                    }
                    ] as PostFormatterBlock[], (item: PostFormatterBlock) => {
                      this.PostFormatterButton(item, () => {
                        this.wrapText(item.prefix, item.suffix)
                      })
                    })
                    this.PostFormatterButton({
                      img: $r('app.media.paintpalette_fill'),
                      name: '文字颜色',
                      prefix: '',
                      suffix: ''
                    }, () => {
                      this.fontColorPickerShow = true
                    })
                  }
                }.padding({ top: 20 })
                .width('100%')
                .constraintSize({
                  minHeight: '100%'
                })
              }.scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.None)
              .width('100%')
              .height('100%')
            }
            .loop(false)
            .cachedCount(0)
            .indicator(false)
          }
          .backgroundColor(this.appTheme.backgroundTertiary)
          .expandSafeArea([SafeAreaType.KEYBOARD, SafeAreaType.SYSTEM])
          .height(Math.max(
            this.showTools ? this.keyboardHeight : this.keyboardAvoidHeight,
            px2vp(this.bottomRectHeight)))
          .animation(SpringCurve)
          .width('100%')
        }
      }.width('100%')
      .height('100%')
    }.hideTitleBar(true)
    .onReady(async (context: NavDestinationContext) => {
      this.pathStack = context.pathStack

      const pageParam = context.pathInfo.param as WriteReplyParam
      const draftData = await QueryDraftItem(pageParam)
      if (draftData) {
        pageParam.draft = draftData
        this.getUIContext().getPromptAction().showToast({
          message: '已还原未发表的内容'
        })
      }
      this.pageParam = pageParam
      this.loadUser()
      this.writeHandler = WriteHandlerFactory(this.pageParam.mode)
      this.fieldToInput = await this.writeHandler.onReady(this.pageParam, this.pageParam.draft, () => {
        this.criticalError()
      })
      this.initialFieldToInput = FieldToInput.from(this.fieldToInput)

      if (this.writeHandler.type == WriteReplyMode.NEW_POST_QUOTE) {
        this.quote = (this.writeHandler as NewPostQuote).quote
      }
      if (this.writeHandler.type == WriteReplyMode.NEW_THREAD || this.writeHandler.type == WriteReplyMode.EDIT) {
        const handler = this.writeHandler as NewThread
        if (handler.threadTypeList !== undefined) {
          this.threadTypeList = handler.threadTypeList
        }
      }

      this.essentialDataReady = true
    }).onBackPressed(() => {
      this.popBack()
      return true
    }).bindSheet($$this.fontColorPickerShow, buildFontColorPicker((colorValue) => {
      this.wrapText(`[color=${colorValue}]`, '[color]')
    }), FontColorPickerSheetOption)
  }

  replySucceed(msg: string = '已发表回帖') {
    this.getUIContext().getPromptAction().showToast({
      message: msg
    })
    this.popData.replied = true
    RemoveDraftIfExist(this.pageParam)
    this.popBack()
  }

  replyError(msg: string = '回帖时出现异常') {
    this.getUIContext().getPromptAction().showToast({
      message: msg
    })
  }

  criticalError() {
    this.getUIContext().getPromptAction().showToast({
      message: '当前未登录 / 获取用户信息出现异常，请稍后重试',
      duration: 5000
    })
    this.popBack()
  }
}

@Builder
export function RegisterBuilder() {
  WriteReply()
}

export function openWriteReply(pathStack: NavPathStack, param: WriteReplyParam, callback: (data: PopInfo) => void) {
  openOrJumpTo(pathStack, PageNameEnum.WriteReply, param, param.defaultTransition, undefined, (data) => callback(data))
}

interface EditPostInfo {
  content: string,
  subject: string | null,
  threadTypeList: ThreadType[],
  typeSelected: number | undefined
}

function extractEditPostInfo(html: string): EditPostInfo | null {
  const contentPattern = /<textarea[^>]*>([\s\S]*?)<\/textarea>/i
  const subjectPattern = /<input type="text" name="subject" id="subject"[\s\S]*?value="([\s\S]*?)"[\s\S]*?\/>/
  const content = html.match(contentPattern)
  const subject = html.match(subjectPattern)
  const types: ThreadType[] = []
  const threadTypeSelectPattern = /<select name="typeid" id="typeid"[\s\S]*?>([\s\S]*?)<\/select>/
  const threadTypePattern = /<option value="([\d]+)"[\s\S]*?>([\s\S]*?)<\/option>/g
  let typeMatch: RegExpExecArray | null
  let typeSelected: number | undefined = undefined
  const typeSelection = html.match(threadTypeSelectPattern)
  while ((typeMatch = threadTypePattern.exec(typeSelection ? typeSelection[1] : '')) != null) {
    const type: ThreadType = {
      id: typeMatch[1],
      name: typeMatch[2]
    }
    if (typeMatch[0].includes('selected="selected"')) {
      typeSelected = types.length
    }
    types.push(type)
  }
  return {
    content: content ? unescapeXml(content[1]) : '',
    subject: subject ? unescapeXml(subject[1]) : null,
    threadTypeList: types,
    typeSelected
  }
}

interface Quote {
  encodedUserId: string
  quoteMessage: string
  postInfo: string
  message: string
}

function extractQuoteInfo(xmlString: string): Quote | null {
  const encodedUserIdPattern = /name="noticeauthor"\svalue="(\p{ASCII}+)"\s\/>/u
  const encodedUserIdMatch = xmlString.match(encodedUserIdPattern)
  const encodedUserId = encodedUserIdMatch ? encodedUserIdMatch[1] : ''

  const quoteMessagePattern = /name="noticetrimstr"\svalue="(.+?)"\s\/>/s
  const quoteMessageMatch = xmlString.match(quoteMessagePattern)
  let quoteMessage = quoteMessageMatch ? quoteMessageMatch[1] : ''

  quoteMessage = unescapeXml(quoteMessage)

  const postInfoPattern = /\[color=#999999\](.+?)\[\/color\]/s
  const messagePattern = /\[\/size\]([\s\S]*)\[\/quote\]/

  const postInfoMatch = quoteMessage.match(postInfoPattern)
  const messageMatch = quoteMessage.match(messagePattern)

  const postInfo = postInfoMatch ? postInfoMatch[1] : ''
  const message = messageMatch ? messageMatch[1].trim() : ''

  if (!encodedUserId || !quoteMessage || !postInfo) {
    return null
  }

  return {
    encodedUserId,
    quoteMessage,
    postInfo,
    message
  }
}

function abbreviate(str: string, maxWidth: number, suffix = '...') {
  if (str.length <= maxWidth) {
    return str
  }
  return str.slice(0, maxWidth - suffix.length) + suffix
}

function addAttachImgFormData(data: Record<string, string | number | undefined>, msg: string, initialMsg: string) {
  const attachImgPattern = /\[attachimg\](\d+)\[\/attachimg\]/g
  let attachImg: RegExpExecArray | null = null
  const attachImgSet = new Set<string>()
  while (attachImg = attachImgPattern.exec(initialMsg)) {
    if (attachImg && attachImg.length == 2) {
      const id = attachImg[1]
      if (!attachImgSet.has(id)) {
        data[`attachupdate[${id}]`] = ''
        attachImgSet.add(id)
      }
    }
  }
  while (attachImg = attachImgPattern.exec(msg)) {
    if (attachImg && attachImg.length == 2) {
      const id = attachImg[1]
      if (!attachImgSet.has(id)) {
        data[`attachnew[${id}][description]`] = ''
        data[`attachnew[${id}][readperm]`] = ''
        attachImgSet.add(id)
      }
    }
  }
}

export interface WriteHandler {
  type?: WriteReplyMode
  onReady: (pageParam: WriteReplyParam, draft: DraftItem | undefined, onError: () => void) => Promise<FieldToInput>
  send: (pageParam: WriteReplyParam, input: FieldToInput, replySucceed: (msg?: string) => void,
    replyError: (msg?: string) => void, initialFieldToInput: FieldToInput) => Promise<void>
  getWebpage: () => Promise<string> // 获取对应操作的web页，用于图片附件相关操作
}

class NewThread implements WriteHandler {
  type = WriteReplyMode.NEW_THREAD
  threadTypeList?: ThreadType[]
  webpage?: string
  fid: string = ''

  async getWebpage() {
    if (!this.webpage) {
      this.webpage = await new request<string>(URL.NEW_THREAD_WEB, URL.WEB_BASE)
        .param('fid', this.fid)
        .toText()
        .get()
    }
    return this.webpage
  }

  async onReady(pageParam: WriteReplyParam, draft: DraftItem | undefined, onError: () => void) {
    this.fid = pageParam.fid || ''
    const postInfo = extractEditPostInfo(await this.getWebpage())
    if (postInfo) {
      this.threadTypeList = postInfo.threadTypeList
      if (draft) {
        return new FieldToInput(draft.content, draft.new_subject || '', draft.thread_type || 0)
      } else {
        return new FieldToInput(postInfo.content, postInfo.subject || '', postInfo.typeSelected || 0)
      }
    } else {
      onError()
      return new FieldToInput()
    }
  }

  async send(pageParam: WriteReplyParam, input: FieldToInput, replySucceed: (msg?: string) => void,
    replyError: (msg?: string) => void, initialFieldToInput: FieldToInput) {
    try {
      const payload: Record<string, string | number | undefined> = {
        'fid': pageParam.fid,
        'subject': input.subject,
        'typeid': this.threadTypeList && this.threadTypeList[input.threadTypeIndex].id || '0',
        'message': input.content,
        'posttime': Date.now(),
        'usesig': '1',
        'allownoticeauthor': 1,
      }
      addAttachImgFormData(payload, input.content, '')
      const resp = await new request<wrapper<Account>>(URL.NEW_THREAD_ACTION)
        .formHash()
        .post(payload)
      if (resp.Message.messageval.includes('succeed')) {
        replySucceed('已发布主题帖')
      } else {
        let msg = resp.Message.messageval
        if (msg == 'post_message_tooshort') {
          msg = '内容字数至少为5个字符'
        }
        replyError(msg)
      }
    } catch (e) {
      replyError()
    }
  }
}


class EditThreadOrPost extends NewThread {
  type = WriteReplyMode.EDIT
  editPid: string = ''
  tid: string = ''

  async onReady(pageParam: WriteReplyParam, draft: DraftItem | undefined, onError: () => void) {
    this.editPid = pageParam.editPid || '0'
    this.tid = pageParam.tid
    return await super.onReady(pageParam, draft, onError)
  }

  async getWebpage() {
    return await new request<string>(URL.POST_EDIT_WEB, URL.WEB_BASE)
      .param('pid', this.editPid)
      .param('tid', this.tid)
      .toText()
      .get()
  }

  async send(pageParam: WriteReplyParam, input: FieldToInput, replySucceed: (msg?: string) => void,
    replyError: (msg?: string) => void, initialFieldToInput: FieldToInput) {
    const postData: Record<string, string | number | undefined> = {
      'pid': pageParam.editPid || '0',
      'posttime': Date.now(),
      'tid': pageParam.tid,
      'usesig': '1',
      'allownoticeauthor': 1,
      'message': input.content
    }
    addAttachImgFormData(postData, input.content, initialFieldToInput.content)
    if (input.subject) {
      postData['subject'] = input.subject
      postData['typeid'] = this.threadTypeList && this.threadTypeList[input.threadTypeIndex].id || '0'
      postData['fid'] = pageParam.fid
    }
    try {
      const resp = await new request<string>(URL.POST_EDIT_ACTION, URL.WEB_BASE)
        .toText()
        .formHash()
        .post(postData)
      if (resp.includes('succeedhandle')) {
        replySucceed('已编辑回帖')
      } else {
        replyError('提交编辑内容时出现异常')
      }
    } catch (e) {
      replyError()
    }
  }
}

class NewPost implements WriteHandler {
  type = WriteReplyMode.NEW_POST
  tid: string = ''
  webpage?: string

  async getWebpage() {
    if (!this.webpage) {
      this.webpage = await new request<string>(URL.REPLY_WEB, URL.WEB_BASE)
        .param('tid', this.tid)
        .toText()
        .get()
    }
    return this.webpage
  }

  async onReady(pageParam: WriteReplyParam, draft: DraftItem | undefined, onError: () => void) {
    this.tid = pageParam.tid
    if (draft) {
      return new FieldToInput(draft.content)
    }
    return new FieldToInput()
  }

  getSendingData(pageParam: WriteReplyParam, input: FieldToInput): Record<string, string> | undefined {
    const data: Record<string, string> = {
      'tid': pageParam.tid,
      'message': input.content + PostSignature.text()
    }
    addAttachImgFormData(data, input.content, '')
    return data
  }

  async send(pageParam: WriteReplyParam, input: FieldToInput, replySucceed: (msg?: string) => void,
    replyError: (msg?: string) => void) {
    const data = this.getSendingData(pageParam, input)
    if (!data) {
      promptAction.showToast({
        message: '回帖组件未完成加载，请稍候'
      })
      return
    }
    try {
      const resp = await new request<wrapper<Account>>(URL.REPLY_ACTION)
        .formHash()
        .post(data)
      if (resp.Message.messageval.includes('succeed')) {
        replySucceed()
      } else {
        let msg = resp.Message.messageval
        if (msg == 'post_message_tooshort') {
          msg = '回帖字数至少为5个字符'
        }
        replyError(msg)
      }
    } catch (e) {
      replyError()
    }
  }
}

class NewPostQuote extends NewPost {
  type = WriteReplyMode.NEW_POST_QUOTE
  quote?: Quote
  quotePid: string = ''

  async getWebpage() {
    if (!this.webpage) {
      this.webpage = await new request<string>(URL.REPLY_WEB, URL.WEB_BASE)
        .param('tid', this.tid)
        .param('repquote', this.quotePid)
        .toText()
        .get()
    }
    return this.webpage
  }

  async onReady(pageParam: WriteReplyParam, draft: DraftItem | undefined, onError: () => void): Promise<FieldToInput> {
    const inputField = super.onReady(pageParam, draft, onError)
    this.quotePid = pageParam.quotePid || ''
    const html = await this.getWebpage()
    const uidhash = extractReplyPageInfo(html)
    if (uidhash.uid == null || uidhash.hash == null) {
      onError()
      return new FieldToInput()
    }
    const quote = extractQuoteInfo(html)
    if (quote == null) {
      onError()
      return new FieldToInput()
    }
    this.quote = quote
    return inputField
  }

  getSendingData(pageParam: WriteReplyParam, input: FieldToInput): Record<string, string> | undefined {
    const data = super.getSendingData(pageParam, input)
    if (data && this.quote) {
      data['noticeauthor'] = this.quote.encodedUserId
      data['noticetrimstr'] = this.quote.quoteMessage
      data['noticeauthormsg'] = abbreviate(input.content, REPLY_NOTIFICATION_MAX_LENGTH)
      return data
    } else {
      return
    }
  }
}

class NewPrivateMessage extends NewPost {
  type = WriteReplyMode.NEW_PM

  async send(pageParam: WriteReplyParam, input: FieldToInput, replySucceed: (msg?: string) => void,
    replyError: (msg?: string) => void) {
    if (pageParam.pmUid === undefined) {
      replyError()
      return
    }
    try {
      const resp = await new request<wrapper<Account>>(URL.NEW_PM_ACTION)
        .formHash()
        .post({
          'touid': pageParam.pmUid,
          'message': input.content,
        })

      if (resp.Message.messageval.includes('success')) {
        replySucceed('已发送')
      } else {
        let msg = resp.Message.messageval
        replyError(msg)
      }
    } catch (e) {
      replyError()
    }
  }
}

class EmptyWriteHandler implements WriteHandler {
  type?: WriteReplyMode | undefined

  async getWebpage() {
    return ''
  }

  async onReady(pageParam: WriteReplyParam, draft: DraftItem | undefined, WriteHandler: () => void) {
    return new FieldToInput()
  }

  async send(pageParam: WriteReplyParam, input: FieldToInput, replySucceed: (msg?: string | undefined) => void,
    replyError: (msg?: string | undefined) => void) {

  }
}

function WriteHandlerFactory(mode: WriteReplyMode) {
  switch (mode) {
    case WriteReplyMode.NEW_THREAD:
      return new NewThread()
    case WriteReplyMode.EDIT:
      return new EditThreadOrPost()
    case WriteReplyMode.NEW_POST:
      return new NewPost()
    case WriteReplyMode.NEW_POST_QUOTE:
      return new NewPostQuote()
    case WriteReplyMode.NEW_PM:
      return new NewPrivateMessage()
  }
}