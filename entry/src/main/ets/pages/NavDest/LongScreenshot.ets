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
import { LongScreenshotPost } from './ThreadPostList'
import { ThreadRatingInfo } from '../../common/component/PostRating'
import { savePixelMapToCache } from '../../common/PixelMapSaver'
import { ShareImage } from '../../common/ShareKit'
import { waitFor } from '../../common/AwaitUtil'
import { getSnapshotArea, mergeImage } from '../../common/LongScreenshotMerger'
import { promptAction } from '@kit.ArkUI'
import { getGroupName, getThreadTypeName } from '../../common/ForumUtil'

export interface LongScreenshotPageParam {
  subject: string
  tid: string
  fid?: string
  typeid?: string
  posts: LongScreenshotPost[]
  ratingInfoMap: Map<string, ThreadRatingInfo>
}

const LIST_ID = 'LongScreenshotList'
const PostContentVerticalPadding = 12
const PostContentHorizontalPadding = 16
const STABLE_DELAY = 300
const FIRST_RENDER_DELAY = 1000

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
  private scrollYOffsets: number[] = []
  private areaArray: image.PositionArea[] = []

  private formatRating(total: number): string {
    return `${total >= 0 ? '+' : ''}${total}`
  }

  @Builder
  postItemBuilder(item: LongScreenshotPost) {
    Column() {
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
          Text(item.post.username)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.appTheme.fontPrimary)
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
          lazyLoadImage: false
        })
      }, (uiRoot: UIRootNode, index: number) => index.toString())

      if (this.pageParam.ratingInfoMap.has(item.post.pid)) {
        Row() {
          Text() {
            Span(`战斗力 ${this.formatRating(this.pageParam.ratingInfoMap.get(item.post.pid)!.totalRating)}`)
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
      bottom: PostContentVerticalPadding
    })
  }

  private async snapAndMerge() {
    this.scrollYOffsets.push(this.curYOffset)
    const pixelMap = await this.getUIContext().getComponentSnapshot().get(LIST_ID, {
      waitUntilRenderFinished: true
    })
    const area = await getSnapshotArea(pixelMap, this.scrollYOffsets, this.listComponentWidth,
      this.listComponentHeight)
    this.areaArray.push(area)
    pixelMap.release()

    if (!this.scroller.isAtEnd()) {
      this.scroller.scrollTo({
        xOffset: 0,
        yOffset: this.curYOffset + this.scrollHeight,
      })
      await waitFor(STABLE_DELAY)
      await this.snapAndMerge()
    } else {
      const merged = mergeImage(this.areaArray, this.scrollYOffsets[this.scrollYOffsets.length - 1],
        this.listComponentWidth, this.listComponentHeight)
      this.releaseAreas()
      const path = await savePixelMapToCache(this.context, merged)
      merged.release()
      ShareImage(path, 'png', this.context)
      this.pathStack.pop()
    }
  }

  private releaseAreas() {
    this.areaArray = []
    this.scrollYOffsets = []
  }

  build() {
    NavDestination() {
      List({ scroller: this.scroller }) {
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
          }.padding({
            top: 16
          })
        }

        ForEach(this.pageParam.posts, (item: LongScreenshotPost, index: number) => {
          ListItem() {
            this.postItemBuilder(item)
          }
          .margin({ bottom: 8 })
        }, (item: LongScreenshotPost, index: number) => index.toString())
        ListItem() {
          Column({ space: 4 }) {
            Text(`帖子 ${this.pageParam.tid}`)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp13)
              .fontColor(this.appTheme.fontSecondary)
              .width('100%')
            Text(`${getGroupName(this.pageParam.fid)} · ${getThreadTypeName(this.pageParam.fid, this.pageParam.typeid)}`)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp13)
              .fontColor(this.appTheme.fontSecondary)
              .width('100%')
          }
          .width('100%')
          .padding({
            left: PostContentHorizontalPadding,
            right: PostContentHorizontalPadding,
            top: 8,
            bottom: PostContentVerticalPadding
          })
        }
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
