import { OuterScroller } from '../../common/component/OuterScroller'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { TitleBar } from '../../common/component/TitleBar'
import { ArrayDataSource } from '../../common/BasicDataSource'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { openThreadPost, ThreadPostParam } from './ThreadPostList'
import { Avatar } from '../../common/component/Avatar'
import { openUserSpace, UserSpaceParam } from './UserSpace'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PropKey } from '../../common/Constants'
import { AniSpeed } from '../../common/Animation'
import { contentHighlight, highlightText, HIGHLIGHT_FONT_COLOR } from './SearchPage'
import { formatRelativeTime } from '../../common/TimeFormat'

export interface PostSearchItem {
  pid: string,
  uid: string,
  username: string,
  floor: string,
  dateline: number,
  plainText: string
}

export interface PageSearchParam {
  tid: string,
  fid?: string,
  subject?: string,
  replies?: string,
  page: number,
  posts: PostSearchItem[]
}

interface SearchResult {
  item: PostSearchItem
  snippet: string
  snippetVM: contentHighlight[]
}

const SNIPPET_RADIUS = 60

function makeSnippet(keywords: string[], text: string): string {
  if (text.length == 0) {
    return ''
  }
  let firstMatchIndex = -1
  let firstMatchLen = 0
  for (const kw of keywords) {
    if (kw.length == 0) {
      continue
    }
    const lower = text.toLowerCase()
    const idx = lower.indexOf(kw.toLowerCase())
    if (idx >= 0 && (firstMatchIndex < 0 || idx < firstMatchIndex)) {
      firstMatchIndex = idx
      firstMatchLen = kw.length
    }
  }
  if (firstMatchIndex < 0) {
    return text.length > SNIPPET_RADIUS * 2 ? text.slice(0, SNIPPET_RADIUS * 2) + '…' : text
  }
  const start = Math.max(0, firstMatchIndex - SNIPPET_RADIUS)
  const end = Math.min(text.length, firstMatchIndex + firstMatchLen + SNIPPET_RADIUS)
  return (start > 0 ? '…' : '') + text.slice(start, end) + (end < text.length ? '…' : '')
}

@Component
export struct PageSearchPage {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @State pageParam: PageSearchParam = {
    tid: '',
    page: 1,
    posts: []
  }
  @State keywordInput: string = ''
  resultDataSource: ArrayDataSource<SearchResult> = new ArrayDataSource<SearchResult>()
  @State nowDate: Date = new Date()
  @State noResult: boolean = false

  popBack() {
    this.pathStack.pop()
  }

  doSearch(raw: string) {
    const keywords = raw.trim().split(/\s+/).filter(k => k.length > 0)
    if (keywords.length == 0) {
      this.resultDataSource.reload([])
      this.noResult = false
      return
    }
    const lowerKeywords = keywords.map(k => k.toLowerCase())
    const results: SearchResult[] = []
    for (const item of this.pageParam.posts) {
      const lowerText = item.plainText.toLowerCase()
      if (!lowerKeywords.every(k => lowerText.includes(k))) {
        continue
      }
      const snippet = makeSnippet(keywords, item.plainText)
      results.push({
        item,
        snippet,
        snippetVM: highlightText(keywords, snippet)
      })
    }
    this.resultDataSource.reload(results)
    this.noResult = results.length == 0
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: '搜索本页',
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        })
        Row() {
          Search({
            value: $$this.keywordInput,
            placeholder: '用空格分隔关键词'
          }).margin(12)
            .searchButton('搜索')
            .defaultFocus(true)
            .onChange((value: string) => {
              this.doSearch(value)
            })
            .onSubmit(() => {
              this.doSearch(this.keywordInput)
            })
        }.backgroundColor(this.appTheme.backgroundSecondary)

        List() {
          if (this.noResult) {
            ListItem() {
              Text('搜索无结果')
                .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                .fontColor(this.appTheme.fontSecondary)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 40 })
            }
          }
          LazyForEach(this.resultDataSource, (result: SearchResult, index: number) => {
            ListItem() {
              Column() {
                Row({ space: 8 }) {
                  Avatar({
                    uid: result.item.uid,
                    avatarSize: 40,
                    transitionIndex: 'PageSearchAvatar' + result.item.pid
                  }).onClick(() => {
                    const userSpaceParam: UserSpaceParam = {
                      uid: result.item.uid,
                      username: result.item.username,
                      avatarTransitionIndex: 'PageSearchAvatar' + result.item.pid
                    }
                    openUserSpace(userSpaceParam, this.pathStack)
                  })

                  Column() {
                    Row() {
                      Text(result.item.username)
                        .fontColor(this.appTheme.fontPrimary)
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                        .layoutWeight(1)
                      Text('#' + result.item.floor)
                        .fontColor(this.appTheme.fontEmphasize)
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                      Text(formatRelativeTime(this.nowDate,
                        new Date(result.item.dateline)))
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                        .fontColor($r('sys.color.font_tertiary'))
                        .margin({ left: 8 })
                    }.width('100%')

                    Text() {
                      ForEach(result.snippetVM, (textItem: contentHighlight) => {
                        Span(textItem.text)
                          .fontColor(textItem.highlight ? HIGHLIGHT_FONT_COLOR : this.appTheme.fontPrimary)
                      })
                    }
                    .maxLines(4)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                    .margin({ top: 6 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
              }
              .padding(12)
              .backgroundColor(this.appTheme.backgroundSecondary)
              .onClick(() => {
                const param: ThreadPostParam = {
                  tid: this.pageParam.tid,
                  fid: this.pageParam.fid,
                  subject: this.pageParam.subject,
                  replies: this.pageParam.replies,
                  jumpToPage: this.pageParam.page,
                  jumpToPid: result.item.pid,
                  jumpToPidWithHighlight: true
                }
                openThreadPost(param, this.pathStack)
              })
              .transition(TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms120 }))
            }.padding({ bottom: 1 })
            .backgroundColor(this.appTheme.backgroundTertiary)
          }, (result: SearchResult) => result.item.pid)

          ListItem() {
            BottomSafeArea()
          }
        }
        .cachedCount(5)
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(this.appTheme.backgroundSecondary)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
        .edgeEffect(EdgeEffect.None)
      }
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.pageParam = context.pathInfo.param as PageSearchParam
      this.doSearch(this.keywordInput)
    })
    .onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  PageSearchPage()
}

export function openPageSearch(pathStack: NavPathStack, param: PageSearchParam) {
  openOrJumpTo(pathStack, PageNameEnum.PageSearch, param)
}
