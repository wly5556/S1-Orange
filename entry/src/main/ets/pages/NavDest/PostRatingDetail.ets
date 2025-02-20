import { BottomSafeArea } from '../../common/component/BottomSafeArea'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { common } from '@kit.AbilityKit'
import { PostRatingPanel, POST_RATING_SLICE_SIZE, Rating, requestRating } from '../../common/component/PostRating'
import { HeavyClickEffect, Spring035s } from '../../common/Animation'
import { RoundPanel } from './Preferences'
import request from '../../api/request'
import { URL } from '../../api/base'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { waitFor } from '../../common/AwaitUtil'
import { promptAction } from '@kit.ArkUI'


export interface PostRatingPopData {
  ratingChanged: boolean
}

export interface PostRatingDetailParam {
  rating: Rating[],
  pid: string,
  tid: string,
  userCount: number,
  totalRating: number,
  transitionId: string,
  reload?: boolean,
  showPanel?: boolean
}

@Component
export struct PostRatingDetail {
  @State pageParam: PostRatingDetailParam = {
    rating: [],
    pid: '',
    tid: '',
    userCount: 0,
    totalRating: 0,
    transitionId: ''
  }
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @State addRatingShow: boolean = false
  @State ratingListLoading: boolean = false
  @State displayRating: Rating[] = []
  context = getContext(this) as common.UIAbilityContext
  popData: PostRatingPopData = {
    ratingChanged: false
  }

  async updateDisplayRating() {
    let sliceOffset = 0
    while (true) {
      const start = sliceOffset * POST_RATING_SLICE_SIZE
      const slice = this.pageParam.rating.slice(start, start + POST_RATING_SLICE_SIZE)
      sliceOffset += 1
      if (slice.length === 0) {
        this.ratingListLoading = false
        break
      } else {
        this.displayRating = this.displayRating.concat(slice)
        if (sliceOffset > 1 && this.ratingListLoading === false) {
          this.ratingListLoading = true
        }
        await waitFor(300)
      }
    }
  }

  reload() {
    requestRating(this.pageParam.pid, this.pageParam.tid).then(data => {
      this.pageParam.rating = data.rating
      this.updateDisplayRating()
      this.pageParam.totalRating = data.totalRating
      this.pageParam.userCount = data.userCount
    })
    this.popData.ratingChanged = true
  }

  popBack() {
    animateTo(Spring035s, () => {
      this.pathStack.pop(this.popData, false)
    })
  }

  @State ratingOptionErr?: string = ''
  @State ratingQuota: string = ''
  @State ratingRangeText: string = ''
  @State ratingInput: number = 0
  @State minRating: number = 0
  @State maxRating: number = 0
  @State ratingReason: string = ''
  formData: Record<string, string> = {}

  async loadRatingQuota() {
    this.formData = {}
    const htmlStr = await new request<string>(URL.RATING_QUOTA, URL.WEB_BASE)
      .param('pid', this.pageParam.pid)
      .param('tid', this.pageParam.tid)
      .param('t', Date.now().toString())
      .toText()
      .get()
    const errorMsg = extractErrorMsg(htmlStr)
    if (errorMsg != null) {
      this.ratingOptionErr = errorMsg
      return
    }
    const quota = extractRangeAndQuota(htmlStr)
    const formData = extractFormData(htmlStr)
    if (quota == null || formData == null) {
      this.ratingOptionErr = '载入评分功能时出现异常'
      return
    }
    animateTo(Spring035s, () => this.ratingOptionErr = undefined)
    this.formData = formData
    this.ratingQuota = quota.quota
    this.ratingRangeText = quota.range
    const range = quota.range.split('~')
    if (range.length == 2) {
      this.minRating = parseInt(range[0])
      this.maxRating = parseInt(range[1])
    }
  }

  setRatingInput(input: string) {
    const num = parseInt(input)
    if (isNaN(num)) {
      this.ratingInput = 0
    } else {
      this.ratingInput = Math.max(this.minRating, Math.min(this.maxRating, num))
    }
  }

  showRatingPanel() {
    this.loadRatingQuota()
    animateTo(Spring035s, () => this.addRatingShow = true)
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: `评分详情`,
          useRightMenu: false,
          clickLeftButton: () => {
            this.popBack()
          }
        })
        Scroll() {
          Column() {
            if (!this.addRatingShow) {
              Button('添加评分')
                .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                .width('100%')
                .buttonStyle(ButtonStyleMode.NORMAL)
                .margin({ top: 12 })
                .geometryTransition(this.pageParam.transitionId + 'addrating')
                .backgroundColor(this.appTheme.backgroundTertiary)
                .onClick(() => {
                  this.showRatingPanel()
                })
            } else {
              Column({ space: 8 }) {
                if (this.ratingOptionErr !== undefined) {
                  Text(this.ratingOptionErr).height(60)
                } else {
                  Row() {
                    Text('评分区间 ' + this.ratingRangeText).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    Text('今日剩余 ' + this.ratingQuota).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                  }.width('100%').padding(12)
                  .justifyContent(FlexAlign.SpaceBetween)

                  TextInput({ text: `${this.ratingInput.toString()}` })
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp28)
                    .width('auto')
                    .onChange(newVal => this.setRatingInput(newVal))
                  Slider({
                    value: $$this.ratingInput,
                    min: this.minRating,
                    max: this.maxRating,
                    style: SliderStyle.OutSet,
                  }).showSteps(true)
                    .selectedColor('#00000000')
                  TextInput({
                    placeholder: '评分理由',
                    text: $$this.ratingReason
                  }).maxLength(50)
                    .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    .width('100%')
                  Row() {
                    ForEach(['好评加鹅', '欢乐多', '思路广'], (reason: string) => {
                      Button(reason)
                        .buttonStyle(ButtonStyleMode.NORMAL)
                        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
                        .fontColor(this.appTheme.fontEmphasize)
                        .clickEffect(HeavyClickEffect)
                        .onClick(() => {
                          this.ratingReason = reason
                        })
                    })
                  }.width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)

                  Row() {
                    Button('取消', { buttonStyle: ButtonStyleMode.TEXTUAL }).onClick(() => {
                      animateTo(Spring035s, () => this.addRatingShow = false)
                    }).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      .margin({ right: 10 })
                      .layoutWeight(1)
                    Button('评分', { buttonStyle: ButtonStyleMode.TEXTUAL })
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      .margin({ left: 10 })
                      .layoutWeight(1)
                      .enabled(this.ratingInput != 0)
                      .opacity(this.ratingInput != 0 ? 1 : 0.6)
                      .onClick(e => {
                        this.formData['score1'] = this.ratingInput.toString()
                        this.formData['reason'] = this.ratingReason
                        new request<string>(URL.RATING_ACTION, URL.WEB_BASE)
                          .toText()
                          .post(this.formData).then(htmlStr => {
                          if (htmlStr.includes('succeedhandle_rate')) {
                            promptAction.showToast({
                              message: '评分成功'
                            })
                          } else {
                            promptAction.showToast({
                              message: '评分时出现异常'
                            })
                          }
                          this.reload()
                          animateTo(Spring035s, () => this.addRatingShow = false)
                        })
                      })
                  }.width('100%')
                }
              }.width('100%')
              .margin({ top: 6 })
              .geometryTransition(this.pageParam.transitionId + 'addrating')
              .attributeModifier(new RoundPanel(this.appTheme.backgroundTertiary))
            }

            PostRatingPanel({
              appTheme: this.appTheme,
              appState: this.appState,
              userCount: this.pageParam.userCount,
              totalRating: this.pageParam.totalRating,
              rating: this.displayRating,
              transitionIndex: this.pageParam.transitionId || '',
              context: this.getUIContext(),
              pathStack: this.pathStack
            })
            if (this.ratingListLoading) {
              LoadingProgress()
                .width(32)
                .height(32)
            }
            BottomSafeArea()
          }.constraintSize({
            minHeight: '100%'
          }).justifyContent(FlexAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .padding({ left: 6, right: 6 })
        .backgroundColor(this.appTheme.backgroundSecondary)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
      }
    }.hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.pageParam = context.pathInfo.param as PostRatingDetailParam
      if (this.pageParam.showPanel) {
        this.showRatingPanel()
      }
      if (this.pageParam.reload) {
        this.reload()
      }
      this.updateDisplayRating()
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  PostRatingDetail()
}

export function openPostRatingDetail(pathStack: NavPathStack, param: PostRatingDetailParam,
  popCallback: Callback<PopInfo>) {
  animateTo(Spring035s, () => {
    openOrJumpTo(pathStack, PageNameEnum.PostRatingDetail, param, false,
      e => JSON.stringify(e) == JSON.stringify(param),
      popCallback)
  })
}

interface RatingRange {
  range: string,
  quota: string
}

function extractRangeAndQuota(html: string): RatingRange | null {
  const pattern = /<td>(-?\d+ ~ -?\d+)<\/td>\s*<td>(\d+)<\/td>\s*<\/tr>\s*<\/table>/
  const match = html.match(pattern)
  if (match && match.length == 3) {
    return {
      range: match[1],
      quota: match[2]
    }
  }
  return null
}

function extractErrorMsg(input: string): string | null {
  const pattern = /errorhandle_rate\('([^']*)',/
  const match = input.match(pattern)
  if (match && match[1]) {
    return match[1]
  } else {
    return null
  }
}


function extractFormData(input: string): Record<string, string> | null {
  const startIndex = input.indexOf(';">')
  const endIndex = input.indexOf('<div class="c">')
  if (startIndex === -1 || endIndex === -1 || startIndex >= endIndex) {
    return null;
  }
  input = input.substring(startIndex + 3, endIndex)
  const regex = /name="([^"]+)"\s+value="([^"]+)"/g
  const result: Record<string, string> = {}
  let match: RegExpExecArray | null = null;
  while ((match = regex.exec(input)) !== null) {
    const name = match[1]
    const value = match[2]
    result[name] = value
  }
  return result
}