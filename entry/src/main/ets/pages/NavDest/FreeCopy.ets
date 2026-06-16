import { LengthUnit, SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { UIRootNode } from '../../common/component/ThreadPostContent'
import {
  bbCodeSerializer,
  markdownSerializer,
  plainTextSerializer
} from '../../common/ThreadPostContentSerializer'
import { CopyText } from '../../common/ShareKit'
import { HeavyClickEffect } from '../../common/Animation'

export interface FreeCopyParam {
  node: UIRootNode[]
}

enum FreeCopyMode {
  PlainText,
  Markdown,
  BBCode
}

const FreeCopyModeLabel: string[] = []
FreeCopyModeLabel[FreeCopyMode.PlainText] = '纯文本'
FreeCopyModeLabel[FreeCopyMode.Markdown] = 'Markdown'
FreeCopyModeLabel[FreeCopyMode.BBCode] = 'BB code'

@Component
export struct FreeCopy {
  pathStack: NavPathStack = new NavPathStack()
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @State pageParam: FreeCopyParam = {
    node: []
  }
  @State plainText: string = ''
  @State markdownText: string = ''
  @State bbCodeText: string = ''
  @State markdownReady: boolean = false
  @State bbCodeReady: boolean = false
  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: FreeCopyModeLabel.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('selectedChanged') selectedModes: FreeCopyMode[] = [FreeCopyMode.PlainText]

  selectedChanged() {
    this.ensureSelectedContent()
  }

  currentMode(): FreeCopyMode {
    return this.selectedModes.length > 0 ? this.selectedModes[0] : FreeCopyMode.PlainText
  }

  ensureSelectedContent() {
    if (this.currentMode() == FreeCopyMode.Markdown && !this.markdownReady) {
      this.markdownText = markdownSerializer.convert(this.pageParam.node)
      this.markdownReady = true
    } else if (this.currentMode() == FreeCopyMode.BBCode && !this.bbCodeReady) {
      this.bbCodeText = bbCodeSerializer.convert(this.pageParam.node)
      this.bbCodeReady = true
    }
  }

  currentContent(): string {
    if (this.currentMode() == FreeCopyMode.Markdown) {
      return this.markdownText
    } else if (this.currentMode() == FreeCopyMode.BBCode) {
      return this.bbCodeText
    }
    return this.plainText
  }

  popBack() {
    this.pathStack.pop()
  }

  build() {
    NavDestination() {
      OuterScroller() {
        Column() {
          TitleBar({
            titleContent: '自由复制',
            useRightMenu: false,
            clickLeftButton: () => {
              this.popBack()
            }
          }) {
            Stack() {
              Image($r('app.media.rectangle_on_rectangle'))
                .width(24)
                .height(24)
                .fillColor(this.appTheme.titleBarFont)
                .rotate({
                  angle: 90
                })
            }
            .width(50)
            .height(50)
            .clickEffect(HeavyClickEffect)
            .onClick(() => {
              CopyText(this.currentContent(), '全文已复制')
            })
          }

          Column({ space: 16 }) {
            SegmentButton({
              options: this.segmentOption,
              selectedIndexes: $selectedModes
            })

            Text(this.currentContent())
              .width('100%')
              .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              .fontColor(this.appTheme.fontPrimary)
              .textAlign(TextAlign.Start)
              .copyOption(CopyOptions.LocalDevice)
              .lineSpacing({
                value: this.appState.contentLineSpace,
                unit: LengthUnit.VP
              })
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
    }.hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.pageParam = context.pathInfo.param as FreeCopyParam
      this.plainText = plainTextSerializer.convert(this.pageParam.node)
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  FreeCopy()
}

export function openFreeCopy(pathStack: NavPathStack, param: FreeCopyParam) {
  openOrJumpTo(pathStack, PageNameEnum.FreeCopy, param)
}
