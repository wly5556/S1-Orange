import { common } from '@kit.AbilityKit'
import { Attachment } from '../../api/model/postList'
import { AniSpeed, SpringCurve } from '../../common/Animation'
import { ImageViewer, ImageViewerParam } from '../../common/component/ImageViewer'
import { OuterScroller } from '../../common/component/OuterScroller'
import { ThreadPostUINodeRender, GeneralNode, UINodeName, UIRootNode } from '../../common/component/ThreadPostContent'
import { TitleBar } from '../../common/component/TitleBar'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { bbCodeParser } from '../../common/ThreadPostContentSerializer'
import { openS1LinkLike } from '../../common/WantUitl'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'

export interface WriteReplyPreviewParam {
  content: string
  subject?: string
  attachmentImagePreview?: Record<string, string>
}

@Component
export struct WriteReplyPreview {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  context = getContext(this) as common.UIAbilityContext
  @State pageParam: WriteReplyPreviewParam = {
    content: ''
  }
  @State uiRoots: UIRootNode[] = []
  @State imgUrl: string[] = []
  @State imgViewer: ImageViewerParam = {
    urls: [],
    startAt: 0
  }
  @State imgViewerShow: boolean = false

  popBack() {
    this.pathStack.pop()
  }

  collectImageUrls(roots: UIRootNode[]): string[] {
    const urls: string[] = []
    for (const root of roots) {
      this.collectImageUrlsFromRoot(root, urls)
    }
    return urls
  }

  collectImageUrlsFromRoot(root: UIRootNode, urls: string[]): void {
    if (root.type == UINodeName.Div) {
      for (const node of root.block) {
        if (node.name == UINodeName.Img) {
          urls.push(node.content)
        }
      }
    } else if (root.type == UINodeName.Quote || root.type == UINodeName.Table) {
      for (const node of root.block) {
        this.collectImageUrlsFromNode(node, urls)
      }
    }
  }

  collectImageUrlsFromNode(node: GeneralNode, urls: string[]): void {
    if (node.nestedRootNode) {
      for (const root of node.nestedRootNode) {
        this.collectImageUrlsFromRoot(root, urls)
      }
    }
    if (node.nestedGeneralNode) {
      for (const nested of node.nestedGeneralNode) {
        this.collectImageUrlsFromNode(nested, urls)
      }
    }
  }

  @Builder
  ImageViewerBuilder() {
    Stack() {
      ImageViewer({
        param: this.imgViewer,
        showUp: this.imgViewerShow
      })
    }.transition(TransitionEffect.opacity(.99).animation({ duration: AniSpeed.ms200 }))
  }

  build() {
    NavDestination() {
      OuterScroller() {
        Column() {
          TitleBar({
            titleContent: '预览',
            useRightMenu: false,
            clickLeftButton: () => {
              this.popBack()
            }
          })

          Column({ space: 12 }) {
            if (this.uiRoots.length == 0) {
              Text('暂无可预览内容')
                .width('100%')
                .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                .fontColor(this.appTheme.fontSecondary)
                .textAlign(TextAlign.Center)
                .padding({ top: 48 })
            } else {
              ForEach(this.uiRoots, (uiRoot: UIRootNode) => {
                ThreadPostUINodeRender({
                  uiRoot,
                  appTheme: this.appTheme,
                  fontSize: this.appState.fontSize,
                  lineSpace: this.appState.contentLineSpace,
                  fontSizeOverride: this.appState.fontSizeOverride,
                  copyOption: CopyOptions.LocalDevice,
                  onLinkClick: (href: string): void => {
                    openS1LinkLike(href, this.pathStack, this.context, this.pageParam.subject || '')
                  },
                  onImgClick: (url: string, index: number): void => {
                    this.imgViewer = {
                      urls: this.imgUrl,
                      startAt: index
                    }
                    animateTo(SpringCurve, () => this.imgViewerShow = true)
                  },
                  getAttachInfo: (aid: string): Attachment | undefined => undefined,
                  lazyLoadImage: true,
                  adjustColorForDarkMode: this.appTheme.isDark && this.appState.darkModeContentColorAdjust
                })
              }, (uiRoot: UIRootNode, index: number) => index.toString() + this.appState.fontSize +
                this.appState.fontSizeOverride + this.appState.darkModeContentColorAdjust + this.appTheme.isDark)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
        }
        .width('100%')
        .constraintSize({
          minHeight: '100%'
        })
        .backgroundColor(this.appTheme.backgroundSecondary)
      }
    }
    .hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.pageParam = context.pathInfo.param as WriteReplyPreviewParam
      this.uiRoots = bbCodeParser.convert(this.pageParam.content, this.pageParam.attachmentImagePreview || {})
      this.imgUrl = this.collectImageUrls(this.uiRoots)
      this.getUIContext().getPromptAction().showToast({
        message: '预览效果仅供参考'
      })
    })
    .onBackPressed(() => {
      this.popBack()
      return true
    })
    .bindContentCover($$this.imgViewerShow, this.ImageViewerBuilder, {
      modalTransition: ModalTransition.NONE,
      onWillDismiss: (() => {
        this.getUIContext().animateTo(SpringCurve, () => {
          this.imgViewerShow = false
        })
      }),
    })
  }
}

@Builder
export function RegisterBuilder() {
  WriteReplyPreview()
}

export function openWriteReplyPreview(pathStack: NavPathStack, param: WriteReplyPreviewParam, animated: boolean = true) {
  openOrJumpTo(pathStack, PageNameEnum.WriteReplyPreview, param, animated)
}
