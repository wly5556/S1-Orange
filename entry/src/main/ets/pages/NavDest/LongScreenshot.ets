import { image } from '@kit.ImageKit'
import { common } from '@kit.AbilityKit'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { PropKey } from '../../common/Constants'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { formatRelativeTime } from '../../common/TimeFormat'
import { avatarPath } from '../../common/component/Avatar'
import { ImageKnifeComponent } from '@ohos/imageknife'
import {
  ThreadPostUINodeRender, UIRootNode
} from '../../common/component/ThreadPostContent'
import { LongScreenshotPollForShot, LongScreenshotPost } from './ThreadPostList'
import { PostRatingPanel, ThreadRatingInfo } from '../../common/component/PostRating'
import { savePixelMapToShareTempFile } from '../../common/PixelMapSaver'
import { ShareImage } from '../../common/ShareKit'
import { waitFor } from '../../common/AwaitUtil'
import { getSnapshotArea, mergeImage } from '../../common/LongScreenshotMerger'
import { promptAction } from '@kit.ArkUI'
import { getGroupName, getThreadTypeName } from '../../common/ForumUtil'
import { generateS1WebPostLink } from '../../common/WantUitl'
import { UserCreditText } from '../../common/component/UserCredit'
import { PollPanelComp } from '../../common/component/PollPanel'

export interface LongScreenshotPageParam {
  subject: string
  tid: string
  fid?: string
  typeid?: string
  poll?: LongScreenshotPollForShot
  posts: LongScreenshotPost[]
  ratingInfoMap: Map<string, ThreadRatingInfo>
  expandRating?: boolean
}

const LIST_ID = 'LongScreenshotList'
const PostContentVerticalPadding = 12
const PostContentHorizontalPadding = 16
const STABLE_DELAY = 300
const FIRST_RENDER_DELAY = 1000
const RESTART_DELAY_AFTER_HEIGHT_CHANGE = 500
const PerforationLineHeight = 18

@Component
export struct LongScreenshotPage {
  context = getContext(this) as common.UIAbilityContext
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @State pageParam: LongScreenshotPageParam = {
    subject: '',
    tid: '',
    posts: [],
    ratingInfoMap: new Map()
  }
  private scroller: Scroller = new Scroller()
  private listComponentWidth: number = 0
  private listComponentHeight: number = 0
  private curYOffset: number = 0
  private scrollHeight: number = 0
  private postContentHeightMap: Map<string, number> = new Map()
  private postContentHeightChangeVersion: number = 0
  private snapshotPostContentHeightChangeVersion: number = 0
  private scrollYOffsets: number[] = []
  private areaArray: image.PositionArea[] = []
  private topPerforationSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private topPerforationContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.topPerforationSettings)
  private bottomPerforationSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private bottomPerforationContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(this.bottomPerforationSettings)

  private updatePostContentHeight(key: string, height: number) {
    if (!this.postContentHeightMap.has(key)) {
      this.postContentHeightMap.set(key, height)
      return
    }
    const oldHeight = this.postContentHeightMap.get(key) || 0
    if (Math.abs(oldHeight - height) < 0.5) {
      return
    }
    this.postContentHeightMap.set(key, height)
    this.postContentHeightChangeVersion++
  }

  private isPostContentHeightChanged(): boolean {
    return this.postContentHeightChangeVersion !== this.snapshotPostContentHeightChangeVersion
  }

  private async restartScreenshotAfterHeightChange() {
    this.releaseAreas()
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
    this.curYOffset = 0
    await waitFor(RESTART_DELAY_AFTER_HEIGHT_CHANGE)
    this.snapshotPostContentHeightChangeVersion = this.postContentHeightChangeVersion
    await this.snapAndMerge()
  }

  private drawPerforationLine(ctx: CanvasRenderingContext2D, width: number, height: number, isTop: boolean) {
    if (width <= 0 || height <= 0) {
      return
    }
    const dashLength = 7.2
    const startX = -dashLength / 2
    const endX = width + dashLength / 2
    const centerY = height / 2
    const shadowOffset = 0.8
    const shadowColor = this.appTheme.isDark ? 'rgba(0, 0, 0, 0.42)' : 'rgba(0, 0, 0, 0.12)'
    const centerColor = this.appTheme.isDark ? 'rgba(255, 255, 255, 0.2)' : 'rgba(255, 255, 255, 1)'

    ctx.clearRect(0, 0, width, height)
    ctx.lineCap = 'round'
    ctx.setLineDash([dashLength, dashLength])

    ctx.beginPath()
    ctx.strokeStyle = shadowColor
    ctx.lineWidth = 3.4
    ctx.moveTo(startX + 0.5, centerY + shadowOffset)
    ctx.lineTo(endX + 0.5, centerY + shadowOffset)
    ctx.stroke()

    ctx.beginPath()
    ctx.strokeStyle = centerColor
    ctx.lineWidth = 2.5
    ctx.moveTo(startX, centerY)
    ctx.lineTo(endX, centerY)
    ctx.stroke()
    ctx.setLineDash([])
  }

  @Builder
  perforationLineBuilder(isTop: boolean) {
    Canvas(isTop ? this.topPerforationContext : this.bottomPerforationContext)
      .width('100%')
      .height(PerforationLineHeight)
      .onReady(() => {
        if (this.listComponentWidth <= 0) {
          return
        }
        this.drawPerforationLine(
          isTop ? this.topPerforationContext : this.bottomPerforationContext,
          this.listComponentWidth,
          PerforationLineHeight,
          isTop
        )
      })
      .onAreaChange((oldValue, newValue) => {
        this.drawPerforationLine(
          isTop ? this.topPerforationContext : this.bottomPerforationContext,
          newValue.width as number,
          newValue.height as number,
          isTop
        )
      })
  }

  @Builder
  postItemBuilder(item: LongScreenshotPost, index: number) {
    Column() {
      if (index !== 0) {
        Row()
          .alignSelf(ItemAlign.Center)
          .width('90%')
          .height(1)
          .border({
            width: {
              bottom: 2
            },
            style: {
              bottom: BorderStyle.Dotted
            },
            color: this.appTheme.isDark ? "#d5ffffff" : "#2a000000"
          })
          .margin({
            bottom: 16
          })
      }
      Row() {
        Stack() {
          Image($r('app.media.avatar_base'))
            .height(FontSizeEnum[this.appState.fontSize].vp40)
            .width(FontSizeEnum[this.appState.fontSize].vp40)
            .draggable(false)
            .borderRadius(FontSizeEnum[this.appState.fontSize].vp40 / 2)
          ImageKnifeComponent({
            imageKnifeOption: {
              loadSrc: avatarPath(item.post.uid),
              objectFit: ImageFit.Cover,
              border: {
                radius: FontSizeEnum[this.appState.fontSize].vp40 / 2
              }
            }
          })
            .height(FontSizeEnum[this.appState.fontSize].vp40)
            .width(FontSizeEnum[this.appState.fontSize].vp40)
            .draggable(false)
        }

        Column() {
          Row({ space: 8 }) {
            Text(item.post.username)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.appTheme.fontPrimary)
            if (this.appState.showCredit) {
              UserCreditText(item.post.userCredit, this.appTheme, this.appState.fontSize)
            }
          }
          .alignItems(VerticalAlign.Center)
          Text(formatRelativeTime(new Date(), item.post.timestamp))
            .fontSize(FontSizeEnum[this.appState.fontSize].vp13)
            .fontColor(this.appTheme.fontSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 12 })
        .layoutWeight(1)

        Text() {
          Span('#')
          Span(item.floorNumber)
        }
        .fontSize(FontSizeEnum[this.appState.fontSize].vp18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.appTheme.fontEmphasize)
        .fontFeature('"ss01" on')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 10 })

      Column() {
        ForEach(item.post.node, (uiRoot: UIRootNode, index: number) => {
          ThreadPostUINodeRender({
            uiRoot: uiRoot,
            appTheme: this.appTheme,
            fontSize: this.appState.fontSize,
            lineSpace: this.appState.contentLineSpace,
            fontSizeOverride: this.appState.fontSizeOverride,
            copyOption: CopyOptions.None,
            onLinkClick: (href: string): void => {
            },
            onImgClick: (url: string, index: number): void => {
            },
            getAttachInfo: (aid: string) => item.post.attachments?.[aid],
            lazyLoadImage: false,
            adjustColorForDarkMode: this.appTheme.isDark && this.appState.darkModeContentColorAdjust
          })
        }, (uiRoot: UIRootNode, index: number) => index.toString())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .onAreaChange((oldValue, newValue) => {
        this.updatePostContentHeight(`post-content-${index}`, newValue.height as number)
      })

      if (item.floorNumber == '1' && this.pageParam.poll !== undefined) {
        PollPanelComp({
          appTheme: this.appTheme,
          appState: this.appState,
          pollList: this.pageParam.poll.pollList,
          pollInfo: this.pageParam.poll.pollInfo,
          transitionIndex: `LongScreenshotPoll${item.post.pid}`,
          expired: this.pageParam.poll.pollInfo.expirations * 1000 < Date.now(),
          allowVote: true,
          onSelected: (index: number, e: ClickEvent) => {
          }
        })
      }

      if (this.pageParam.ratingInfoMap.has(item.post.pid) && this.pageParam.expandRating) {
        PostRatingPanel({
          appTheme: this.appTheme,
          appState: this.appState,
          userCount: this.pageParam.ratingInfoMap.get(item.post.pid)!.userCount,
          totalRating: this.pageParam.ratingInfoMap.get(item.post.pid)!.totalRating,
          rating: this.pageParam.ratingInfoMap.get(item.post.pid)!.rating,
          transitionIndex: `LongScreenshotPostRating${item.post.pid}`,
          seeMoreButton: false,
          context: this.getUIContext(),
          pathStack: this.pathStack
        })
      } else if (this.pageParam.ratingInfoMap.has(item.post.pid)) {
        Row() {
          Text() {
            Span(`战斗力 ${this.pageParam.ratingInfoMap.get(item.post.pid)!.totalRating >= 0 ? '+' : ''}${this.pageParam.ratingInfoMap.get(item.post.pid)!.totalRating}`)
            Span(' / ').opacity(0.7)
            Span(`${this.pageParam.ratingInfoMap.get(item.post.pid)!.userCount}人评价`)
          }.fontSize(FontSizeEnum[this.appState.fontSize].vp14)
          .fontColor(this.appTheme.fontSecondary)
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .borderRadius(12)
    .padding({
      left: PostContentHorizontalPadding,
      right: PostContentHorizontalPadding,
      top: PostContentVerticalPadding,
      bottom: 6
    })
  }

  private async snapAndMerge() {
    if (this.areaArray.length === 0 && this.scrollYOffsets.length === 0) {
      this.snapshotPostContentHeightChangeVersion = this.postContentHeightChangeVersion
    }
    if (this.isPostContentHeightChanged()) {
      await this.restartScreenshotAfterHeightChange()
      return
    }

    this.scrollYOffsets.push(this.curYOffset)
    const pixelMap = await this.getUIContext().getComponentSnapshot().get(LIST_ID, {
      waitUntilRenderFinished: true
    })
    const area = await getSnapshotArea(pixelMap, this.scrollYOffsets, this.listComponentWidth,
      this.listComponentHeight)
    this.areaArray.push(area)
    pixelMap.release()
    if (this.isPostContentHeightChanged()) {
      await this.restartScreenshotAfterHeightChange()
      return
    }

    if (!this.scroller.isAtEnd() && this.scrollHeight > 0) {
      const prevYOffset = this.curYOffset
      this.scroller.scrollTo({
        xOffset: 0,
        yOffset: prevYOffset + this.scrollHeight,
      })
      await waitFor(STABLE_DELAY)
      this.curYOffset = this.scroller.currentOffset().yOffset
      if (this.isPostContentHeightChanged()) {
        await this.restartScreenshotAfterHeightChange()
        return
      }
      if (this.curYOffset <= prevYOffset) {
        await this.mergeAndShare()
        return
      }
      await this.snapAndMerge()
    } else {
      await this.mergeAndShare()
    }
  }

  private async mergeAndShare() {
    const mergedPixelMap = mergeImage(this.areaArray)
    this.releaseAreas()
    const shareTempFilePath = await savePixelMapToShareTempFile(this.context, mergedPixelMap)
    mergedPixelMap.release()
    ShareImage(shareTempFilePath, 'png', this.context)
    this.pathStack.pop()
  }

  private releaseAreas() {
    this.areaArray = []
    this.scrollYOffsets = []
  }

  build() {
    NavDestination() {
      List({ scroller: this.scroller }) {
        ListItem() {
          this.perforationLineBuilder(true)
        }
        .padding({
          top: 12,
          bottom: 4
        })

        ListItem() {
          Column() {
            Text(this.pageParam.subject || '')
              .fontSize(FontSizeEnum[this.appState.fontSize].vp20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.appTheme.fontPrimary)
              .maxLines(99)
              .width('100%')
              .padding({
                left: PostContentHorizontalPadding,
                right: PostContentHorizontalPadding,
                top: PostContentVerticalPadding,
                bottom: PostContentVerticalPadding
              })
            Divider()
          }
        }

        ForEach(this.pageParam.posts, (item: LongScreenshotPost, index: number) => {
          ListItem() {
            this.postItemBuilder(item, index)
          }
          .margin({ bottom: 8 })
        }, (item: LongScreenshotPost, index: number) => index.toString())

        ListItem() {
          Column() {
            Divider()
            Row() {
              Column({ space: 4 }) {
                Text(
                  `Stage1st · ${getGroupName(this.pageParam.fid)} · ${getThreadTypeName(this.pageParam.fid,
                    this.pageParam.typeid)}`)
                  .fontSize(FontSizeEnum[this.appState.fontSize].vp13)
                  .fontColor(this.appTheme.fontSecondary)
                Text(`帖子 ${this.pageParam.tid}`)
                  .fontSize(FontSizeEnum[this.appState.fontSize].vp13)
                  .fontColor(this.appTheme.fontSecondary)
              }
              .alignItems(HorizontalAlign.Start)
              .flexShrink(1)
              QRCode(generateS1WebPostLink(this.pageParam.tid, 1)).width(36).height(36)
            }.justifyContent(FlexAlign.SpaceBetween)
            .alignItems(VerticalAlign.Center)
            .width('100%')
            .padding({
              left: PostContentHorizontalPadding,
              right: PostContentHorizontalPadding,
              top: PostContentVerticalPadding,
              bottom: PostContentVerticalPadding
            })
          }
        }

        ListItem() {
          this.perforationLineBuilder(false)
        }
        .padding({
          top: 4,
          bottom: 16
        })
      }
      .id(LIST_ID)
      .width('100%')
      .constraintSize({ maxHeight: '100%' })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .enableScrollInteraction(false)
      .backgroundColor(this.appTheme.backgroundSecondary)
      .onDidScroll(() => {
        this.curYOffset = this.scroller.currentOffset().yOffset
      })
      .onAreaChange((oldValue, newValue) => {
        this.listComponentWidth = newValue.width as number
        this.listComponentHeight = newValue.height as number
        this.scrollHeight = this.listComponentHeight
      })
    }
    .hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .onReady((context: NavDestinationContext) => {
      promptAction.showToast({
        message: "请等待截图完成"
      })
      this.pathStack = context.pathStack
      const param = context.pathInfo.param as LongScreenshotPageParam
      param.posts.sort((a, b) => Number(a.floorNumber) - Number(b.floorNumber))
      this.pageParam = context.pathInfo.param as LongScreenshotPageParam
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
      waitFor(FIRST_RENDER_DELAY).then((): Promise<void> => this.snapAndMerge())
    })
    .onBackPressed(() => {
      this.pathStack.pop()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  LongScreenshotPage()
}

export function openLongScreenshot(pathStack: NavPathStack, param: LongScreenshotPageParam) {
  openOrJumpTo(pathStack, PageNameEnum.LongScreenshot, param)
}
