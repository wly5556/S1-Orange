import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import request from '../../api/request'
import { common } from '@kit.AbilityKit'
import { PageIndexDataSource, SwipePageLoadingIcon, SwipePageViewer } from '../../common/component/SwipePageViewer'
import { PageSlider } from '../../common/component/PageSlider'
import wrapper from '../../api/wrapper'
import { URL } from '../../api/base'
import { PreferenceManager } from '../../config/UserConfig'
import { ErrorTips } from '../../common/component/ErrorTips'
import { Spring035s } from '../../common/Animation'
import { MyNote } from '../../api/model/note'
import { formatRelativeTime } from '../../common/TimeFormat'
import { Avatar } from '../../common/component/Avatar'
import { unescapeXml } from '../../common/XmlParser'
import { openThreadPostByLink } from './ThreadPostList'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { ReloadController } from '../../common/BasicDataSource'
import { PropKey } from '../../common/Constants'

@Component
export struct NoteList {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  dataSource: PageIndexDataSource = new PageIndexDataSource(0)
  context = getContext(this) as common.UIAbilityContext
  reloadCtrl: ReloadController = new ReloadController()
  @Provide totalPage: number = 1
  @State jumpToPage: number = -1
  @State currentPage: number = 1
  @State pullToRefreshEnabled: boolean = true
  @StorageProp(PropKey.userId) @Watch('onAccountUpdate') uid?: string = undefined

  onAccountUpdate() {
    this.reloadCtrl.reload()
  }

  popBack() {
    this.pathStack.pop()
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.uid = conf.user_uid
    })
  }

  @Builder
  contentBuilder(page: number, index: number, loadingIcon: SwipePageLoadingIcon) {
    SingleNotePage({
      pageToLoad: page,
      loadingIcon
    })
  }

  build() {
    NavDestination() {
      OuterScroller({
        onEnterAndLeaveTop: atTop => this.pullToRefreshEnabled = atTop
      }) {
        TitleBar({
          titleContent: `提醒`,
          clickLeftButton: () => {
            this.popBack()
          },
          menu: [{
            value: '刷新',
            action: () => this.reloadCtrl.reload()
          }]
        }) {
          PageSlider({
            pageIndex: this.currentPage,
            totalPage: this.totalPage,
            doJump: page => this.jumpToPage = page
          })
        }

        if (this.uid) {
          SwipePageViewer({
            enablePullToRefresh: this.pullToRefreshEnabled,
            currentPage: this.currentPage,
            contentBuilder: this.contentBuilder,
            reloadCtrl: this.reloadCtrl,
            jumpToPage: this.jumpToPage,
            maxPage: this.totalPage,
            cacheCount: 0
          }).backgroundColor(this.appTheme.backgroundSecondary)
        } else {
          Column() {
            ErrorTips('请先登录')
          }.backgroundColor(this.appTheme.backgroundSecondary)
          .width('100%')
          .height('100%')
        }
      }
    }.hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

interface NoteItemVM {
  id: string
  new: string
  author: string
  authorid: string
  reason: string
  subject: string
  url: string
  datetime: Date
}

@Component
struct SingleNotePage {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume @Watch('requestPostData') dataControlCounter: number
  pageToLoad: number = 1
  loadingIcon?: SwipePageLoadingIcon
  @Consume totalPage: number
  @Consume appState: PreferenceState
  @State noteItem: NoteItemVM[] = []
  @State datetime: Record<string, string> = {}
  updateDatetimeInterval: number = 0

  aboutToAppear(): void {
    this.requestPostData()
    this.updateDatetimeInterval = setInterval((): void => this.updateDatetime(), 60000)
  }

  aboutToDisappear(): void {
    clearInterval(this.updateDatetimeInterval)
  }

  updateDatetime() {
    this.datetime = {}
    const now = new Date()
    this.noteItem.forEach(note => {
      this.datetime[note.id] = formatRelativeTime(now, note.datetime)
    })
  }

  requestPostData() {
    this.loadingIcon?.show(this.pageToLoad)
    new request<wrapper<MyNote>>(URL.NOTELIST)
      .param('page', this.pageToLoad.toString())
      .get()
      .then(v => {
        if (v.Variables && v.Variables.list != null && v.Variables.count != null && v.Variables.perpage != null) {
          animateTo(Spring035s, () => {
            this.totalPage = Math.ceil(parseInt(v.Variables.count!) / parseInt(v.Variables.perpage!))
            this.noteItem = v.Variables.list!.map(note => {
              const item = extractNoteItem(note.note)

              const itemVM: NoteItemVM = {
                id: note.id,
                authorid: note.notevar.actoruid,
                author: note.notevar.actorusername,
                new: note.new,
                reason: item.reason,
                subject: item.subject,
                url: item.url,
                datetime: new Date(parseInt(note.dateline) * 1000)
              }
              return itemVM
            })
            this.updateDatetime()
          })
        } else {
          this.noteItem = []
          this.totalPage = 1
        }
        this.loadingIcon?.hide(this.pageToLoad)
      })
  }

  @Builder
  noteHeader(item: NoteItemVM) {
    Row({ space: 6 }) {
      Avatar({
        avatarSize: 24,
        uid: item.authorid
      })
      Text(item.author)
      Text(item.reason).opacity(.6)
    }.alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      ForEach(this.noteItem, (item: NoteItemVM, compIndex: number) => {
        Column() {
          if (item.new != '0') {
            Badge({
              style: {},
              value: 'New',
            }) {
              this.noteHeader(item)
            }.width('90%')
          } else {
            this.noteHeader(item)
          }

          Text(item.subject)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .padding(12)
          Text(this.datetime[item.id]).alignSelf(ItemAlign.End).opacity(.6)
        }.alignItems(HorizontalAlign.Start)
        .width("100%")
        .padding(12)
        .onClick(() => {
          openThreadPostByLink(URL.WEB_BASE + item.url, this.pathStack, () => {
          }, item.subject)
        })

        if (compIndex != this.noteItem.length - 1) {
          Divider()
        }

      }, (item: NoteItemVM, compIndex: number) => item.id)
      BottomSafeArea()
    }.constraintSize({
      minHeight: '100%'
    })
    .alignItems(HorizontalAlign.Start)
  }
}


@Builder
export function RegisterBuilder() {
  NoteList()
}

export function openNoteList(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.NoteList)
}

interface NoteItem {
  reason: string,
  subject: string,
  url: string
}

function extractNoteItem(html: string): NoteItem {
  const regex = /<a.*?>.*?<\/a>\s*([^<]+)\s*<a href="([^"]*)".*?>(.*?)<\/a>.*/;
  const match = regex.exec(html);
  if (match && match.length >= 4) {
    return {
      reason: match[1],
      url: match[2],
      subject: unescapeXml(match[3])
    };
  } else {
    return {
      reason: '',
      url: '',
      subject: ''
    };
  }
}