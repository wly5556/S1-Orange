import { OuterScroller } from '../../common/component/OuterScroller'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import { TitleBar } from '../../common/component/TitleBar'
import { ArrayDataSource, ReloadController } from '../../common/BasicDataSource'
import { PageSlider } from '../../common/component/PageSlider'
import { SwipePageLoadingIcon, SwipePageViewer } from '../../common/component/SwipePageViewer'
import request from '../../api/request'
import { URL } from '../../api/base'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { openThreadPost, ThreadPostParam } from './ThreadPostList'
import { Avatar } from '../../common/component/Avatar'
import { openUserSpace, UserSpaceParam } from './UserSpace'
import { PreferenceManager } from '../../config/UserConfig'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PropKey } from '../../common/Constants'

export enum SearchType {
  Thread = 0,
  User = 1,
  Friend = 2
}

enum SearchTypeName {
  '帖子',
  '用户',
  '好友'
}

enum SearchTypeParam {
  'forum',
  'user'
}

const HIGHLIGHT_FONT_COLOR = '#edff3939'

@Component
export struct SearchPage {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  context = getContext(this) as common.UIAbilityContext
  @State searchTypeInput: SearchType = SearchType.Thread
  @Provide searchRequestType: SearchType = SearchType.Thread
  @State keywordInput: string = ''
  @State currentPage: number = 1
  @Provide totalPage: number = 1
  @Provide directSearchUrl?: string = undefined
  @State jumpToPage: number = -1
  @Provide searchRequestKeyword?: string = undefined
  reloadCtrl: ReloadController = new ReloadController()

  popBack() {
    this.pathStack.pop()
  }

  @Builder
  SearchContent(page: number, index: number, loadingIcon: SwipePageLoadingIcon) {
    SearchResultPage({
      pageToLoad: page,
      loadingIcon
    })
  }

  isSameSearch() {
    return this.keywordInput == this.searchRequestKeyword && this.searchRequestType == this.searchTypeInput
  }

  build() {
    NavDestination() {

      OuterScroller() {

        TitleBar({
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        }) {
          if (this.searchTypeInput != SearchType.Friend) {
            Select([{
              value: SearchTypeName[SearchType.Thread]
            }, {
              value: SearchTypeName[SearchType.User]
            }]).selected($$this.searchTypeInput)
              .value(SearchTypeName[this.searchTypeInput]).height(50)
          }
          Blank()
          PageSlider({
            pageIndex: this.currentPage,
            totalPage: this.totalPage,
            doJump: page => {
              this.jumpToPage = page
            },
          })
        }

        Scroll() {
          Column() {
            if (this.searchTypeInput != SearchType.Friend) {
              Search({
                value: $$this.keywordInput
              }).margin(12)
                .searchButton('搜索', {
                  fontColor: this.isSameSearch() ? '#22000000' : undefined
                })
                .defaultFocus(true)
                .onSubmit(() => {
                  if (this.isSameSearch()) {
                    return
                  }
                  if (this.keywordInput.length == 0) {
                    this.getUIContext().getPromptAction().showToast({
                      message: '请输入搜索内容'
                    })
                    return
                  }
                  this.searchRequestKeyword = this.keywordInput
                  const searchType = this.searchTypeInput
                  new request<string>(URL.SEARCH_WEB, URL.WEB_BASE)
                    .redirectLocation()
                    .formHash()
                    .toText()
                    .post({
                      'mod': SearchTypeParam[searchType],
                      'srchtxt': this.searchTypeInput == SearchType.Thread ? this.searchRequestKeyword :
                      encodeURIComponent(this.searchRequestKeyword)
                    })
                    .then(location => {
                      this.getSearchResult(URL.WEB_BASE + location, searchType)
                    })
                })
            }
            SwipePageViewer({
              enablePullToRefresh: false,
              currentPage: this.currentPage,
              contentBuilder: this.SearchContent,
              jumpToPage: this.jumpToPage,
              maxPage: this.totalPage,
              useList: true,
              reloadCtrl: this.reloadCtrl
            })
          }.width('100%')
          .constraintSize({
            minHeight: '100%'
          })
        }
        .scrollBar(BarState.Off)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
        .width('100%')
        .height('100%')
        .backgroundColor(this.appTheme.backgroundSecondary)
      }
    }.hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const param = (context.pathInfo.param as SearchPageParam)
      this.searchTypeInput = param.type || SearchType.Thread
      if (this.searchTypeInput == SearchType.Friend) {
        this.getSearchResult(URL.WEB_BASE + URL.FRIEND_WEB + `&uid=${param.targetUid || ''}`, this.searchTypeInput)
      }
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }

  getSearchResult(location: string, searchType: SearchType) {
    this.directSearchUrl = location
    this.searchRequestType = searchType
    this.reloadCtrl.reload()
  }
}

@Component
struct SearchResultPage {
  threadDataSource: ArrayDataSource<ThreadSearchResult> = new ArrayDataSource<ThreadSearchResult>()
  userDataSource: ArrayDataSource<UserSearchItem> = new ArrayDataSource<UserSearchItem>()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @Consume pathStack: NavPathStack
  @Prop pageToLoad: number
  @Consume searchRequestKeyword: string
  @Consume @Watch('requestPageData') dataControlCounter: number
  @Consume searchRequestType: SearchType
  @Consume directSearchUrl: string
  context = getContext(this) as common.UIAbilityContext
  @Consume totalPage: number
  loadingIcon?: SwipePageLoadingIcon

  aboutToAppear(): void {
    this.requestPageData()
  }

  requestPageData() {
    if (this.directSearchUrl && this.directSearchUrl != '') {
      this.loadingIcon?.show(this.pageToLoad)
      new request<string>(this.directSearchUrl, '')
        .param('page', this.pageToLoad.toString())
        .toText()
        .get()
        .then(htmlStr => {
          this.loadingIcon?.hide(this.pageToLoad)
          if (this.searchRequestType == SearchType.Thread) {
            const pageInfo = extractThreadSearchInfo(htmlStr)
            const kws = this.searchRequestKeyword.split(/\s+/)
            this.totalPage = pageInfo.totalPage
            const result = extractThreadSearchResult(htmlStr)
            for (let i = 0; i < result.length; i++) {
              result[i].contentVM = highlightText(kws, result[i].content)
              result[i].subjectVM = highlightText(kws, result[i].subject)
            }
            this.threadDataSource.reload(result)
          } else if (this.searchRequestType == SearchType.User || this.searchRequestType == SearchType.Friend) {
            PreferenceManager.readonly(conf => {
              let result: UserSearchResult
              if (this.searchRequestType == SearchType.Friend && this.directSearchUrl.includes(conf.user_uid)) {
                result = extractSelfFriendResult(htmlStr)
              } else {
                result = extractUserSearchResult(htmlStr)
              }
              this.totalPage = result.page
              this.userDataSource.reload(result.users)
              if (result.errorMsg) {
                this.getUIContext().getPromptAction().showToast({
                  message: result.errorMsg,
                  duration: 5000
                })
              }
            })
          }
        })
    } else {
      this.loadingIcon?.hide(this.pageToLoad)
    }
  }

  build() {
    Stack() {
      List() {
        if (this.searchRequestType == SearchType.Thread) {
          LazyForEach(this.threadDataSource, (item: ThreadSearchResult) => {
            ListItem() {
              Column() {
                Column({ space: 8 }) {
                  Column() {
                    Text() {
                      ForEach(item.subjectVM, (textItem: contentHighlight) => {
                        Span(textItem.text)
                          .fontColor(textItem.highlight ? HIGHLIGHT_FONT_COLOR : this.appTheme.fontEmphasize)
                      })
                    }.fontSize(FontSizeEnum[this.appState.fontSize].vp20)

                    Text(item.dateTime).opacity(.7).fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                      .padding({ bottom: 12 })
                    Text() {
                      ForEach(item.contentVM, (textItem: contentHighlight) => {
                        Span(textItem.text).fontColor(textItem.highlight ? HIGHLIGHT_FONT_COLOR : undefined)
                      })
                    }.opacity(.95).maxLines(4)
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                  }.onClick(e => {
                    const param: ThreadPostParam = {
                      tid: item.tid,
                      subject: item.subject
                    }
                    openThreadPost(param, this.pathStack)
                  }).alignItems(HorizontalAlign.Start)
                  .width('100%')

                  Text(item.views).fontSize(FontSizeEnum[this.appState.fontSize].vp15).opacity(.7)
                  Row({ space: 12 }) {
                    Text(item.username).fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                    Text(item.forumName).fontSize(FontSizeEnum[this.appState.fontSize].vp15)
                  }.opacity(.7)
                }.backgroundColor(this.appTheme.backgroundSecondary)
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding(12)
              }.padding({ bottom: 1 })
              .backgroundColor(this.appTheme.backgroundTertiary)
              .transition(TransitionEffect.OPACITY.animation({ duration: 100 }))
            }
          }, (item: ThreadSearchResult) => item.tid)
        } else if (this.searchRequestType == SearchType.User || this.searchRequestType == SearchType.Friend) {
          LazyForEach(this.userDataSource, (item: UserSearchItem) => {
            ListItem() {
              Column() {
                Row({ space: 8 }) {
                  Avatar({
                    uid: item.uid,
                    avatarSize: 40,
                    transitionIndex: 'SearchPageAvatar' + item.uid
                  })
                  Column() {
                    Text(item.username)
                    Text(item.credit)
                      .alignSelf(ItemAlign.End)
                      .opacity(.7)
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                  }.flexGrow(1)
                  .flexShrink(1)
                  .justifyContent(FlexAlign.SpaceBetween)
                  .alignItems(HorizontalAlign.Start)
                }.backgroundColor(this.appTheme.backgroundSecondary)
                .width('100%')
                .padding(12)
                .onClick(e => {
                  const param: UserSpaceParam = {
                    uid: item.uid,
                    username: item.username,
                    avatarTransitionIndex: 'SearchPageAvatar' + item.uid
                  }
                  openUserSpace(param, this.pathStack)
                })
              }.padding({ bottom: 1 })
              .backgroundColor(this.appTheme.backgroundTertiary)
              .transition(TransitionEffect.OPACITY.animation({ duration: 100 }))
            }
          }, (item: UserSearchItem) => item.uid)
        }
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
}

interface SearchInfo {
  totalItemText: string
  totalPage: number
}

export const pagePattern = /<span title="共 (\d+) 页">/

function extractThreadSearchInfo(html: string): SearchInfo {
  const totalItemPattern = /<em>[\s\S]*?(相关内容 (\d+) 个)[\s\S]*?<\/em>/
  const pageMatch = html.match(pagePattern)
  const totalPage = pageMatch ? parseInt(pageMatch[1]) : 1
  const itemMatch = html.match(totalItemPattern)
  const totalItemText = itemMatch ? itemMatch[1] : "相关内容 0 个"

  return {
    totalItemText,
    totalPage
  }
}

interface contentHighlight {
  text: string,
  highlight: boolean
}

interface ThreadSearchResult {
  tid: string
  subject: string
  subjectVM: contentHighlight[]
  views: string
  content: string
  contentVM: contentHighlight[]
  dateTime: string
  username: string
  forumName: string
}

function extractThreadSearchResult(html: string) {
  const regex = /<li class="pbw" id="([^"]+)">([\s\S]*?)<\/li>/g
  const subjectPattern = /<a href="forum\.php\?[^"]+" target="_blank" >([\s\S]*?)<\/a>/
  const viewsPattern = /<p class="xg1">([\s\S]*?)<\/p>/
  const contentPattern = /<\/p>[\s\S]*?<p>([\s\S]*?)<\/p>[\s\S]*?<p>[\s\S]*?<span>/
  const dateTimePattern = /<p>[\s]*?<span>([\s\S]*?)<\/span>[\s\S]*?-/
  const usernamePattern = /<a href="space-uid-[\s\S]*?>([\s\S]*?)<\/a>/
  const forumNamePattern = /<a href="forum-[\s\S]*?class="xi1"[\s\S]*?>([\s\S]*?)<\/a>/
  let match: RegExpExecArray | null = null
  const results: ThreadSearchResult[] = []

  while ((match = regex.exec(html)) !== null) {
    const tid = match[1]
    const htmlResult = match[2]

    const subjectMatch = subjectPattern.exec(htmlResult)
    const viewsMatch = viewsPattern.exec(htmlResult)
    const contentMatch = contentPattern.exec(htmlResult)
    const dateTimeMatch = dateTimePattern.exec(htmlResult)
    const usernameMatch = usernamePattern.exec(htmlResult)
    const forumNameMatch = forumNamePattern.exec(htmlResult)

    if (!subjectMatch || !viewsMatch || !contentMatch || !dateTimeMatch || !usernameMatch || !forumNameMatch) {
      continue
    }

    const result: ThreadSearchResult = {
      tid,
      subject: subjectMatch[1].trim().replace(/<([\s\S]*?)>/g, ''),
      views: viewsMatch[1].trim(),
      content: contentMatch[1].trim().replace(/<([\s\S]*?)>/g, ''),
      dateTime: dateTimeMatch[1].trim(),
      username: usernameMatch[1].trim(),
      forumName: forumNameMatch[1].trim(),
      contentVM: [],
      subjectVM: []
    }

    results.push(result)
  }
  return results
}

interface UserSearchResult {
  page: number
  users: UserSearchItem[]
  errorMsg?: string
}

interface UserSearchItem {
  uid: string
  username: string
  credit: string
}

function extractUserSearchResult(html: string): UserSearchResult {
  const regex = /<li class="bbda cl">([\s\S]*?)<\/li>/g
  const uidUnamePattern = /<h4>\s*<a href="space-uid-(\d+)\.html" title="([^"]+)" target="_blank">([^<]+)<\/a>\s*<\/h4>/
  const creditPattern = /<p class="maxh">([^"]+)<\/p>/
  const errorMsgPattern = /<h2 class="xs2">([\s\S]*?)<\/h2>/

  let match: RegExpExecArray | null = null
  const users: UserSearchItem[] = []
  const pageNum = pagePattern.exec(html)
  const errorMsg = errorMsgPattern.exec(html)

  while ((match = regex.exec(html)) !== null) {
    const htmlResult = match[1]
    const uidUname = uidUnamePattern.exec(htmlResult)
    const credit = creditPattern.exec(htmlResult)
    if (!uidUname || !credit) {
      continue
    }

    const result: UserSearchItem = {
      uid: uidUname[1],
      username: uidUname[2],
      credit: credit[1].replaceAll('&nbsp;', ' ')
    }

    users.push(result)
  }
  return {
    page: pageNum ? parseInt(pageNum[1]) : 1,
    users: users,
    errorMsg: errorMsg ? errorMsg[1] : undefined
  }
}

function extractSelfFriendResult(html: string): UserSearchResult {
  const regex = /<li id="friend_\d+_li">([\s\S]*?)<\/li>/g
  const uidUnamePattern = /<a href="space-uid-(\d+)\.html">([^<]+)<\/a>/

  let match: RegExpExecArray | null = null
  const users: UserSearchItem[] = []
  const pageNum = pagePattern.exec(html)

  while ((match = regex.exec(html)) !== null) {
    const htmlResult = match[1]
    const uidUname = uidUnamePattern.exec(htmlResult)
    if (!uidUname) {
      continue
    }

    const result: UserSearchItem = {
      uid: uidUname[1],
      username: uidUname[2],
      credit: ''
    }
    users.push(result)
  }
  return {
    page: pageNum ? parseInt(pageNum[1]) : 1,
    users: users,
  }
}

function highlightText(keywords: string[], str: string): contentHighlight[] {
  const keywordRegex = new RegExp(`(${keywords.join('|')})`, 'gi')
  const result: contentHighlight[] = [];
  let lastIndex = 0;
  str.replace(keywordRegex, (match, _: string, index: number) => {
    if (index > lastIndex) {
      result.push({
        text: str.slice(lastIndex, index),
        highlight: false,
      })
    }
    result.push({
      text: match,
      highlight: true,
    })
    lastIndex = index + match.length
    return match
  })
  if (lastIndex < str.length) {
    result.push({
      text: str.slice(lastIndex),
      highlight: false,
    })
  }
  return result
}


@Builder
export function RegisterBuilder() {
  SearchPage()
}

export interface SearchPageParam {
  type?: SearchType
  targetUid?: string
}

export function openSearchPage(pathStack: NavPathStack, param: SearchPageParam) {
  openOrJumpTo(pathStack, PageNameEnum.SearchPage, param)
}
