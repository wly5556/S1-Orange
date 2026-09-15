import { PopoverDialog, PopoverOptions } from '@kit.ArkUI'
import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { ClickDarkenEffect } from '../Animation'
import { followHandDialogActive } from '../FollowHandDialogHelper'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { AppThemeColor } from '../theme/basic/basic'
import { SlideDialog, SlideDialogContent } from './PageSliderDialog'

@Component
export struct PageSlider {
  @Prop pageIndex: number
  clickEffectModifier: AttributeModifier<CommonAttribute> = new ClickDarkenEffect()
  @Prop totalPage: number
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  hideTotal: boolean = false
  clickable: boolean = true
  doJump: (page: number) => void = () => {
  }
  @State followHandShow: boolean = false
  @State followHandPopover: PopoverOptions = {
    builder: () => {
      this.buildSlideContent()
    },
    width: 320,
    enableArrow: false,
    keyboardAvoidMode: KeyboardAvoidMode.DEFAULT
  }
  sliderDialog: CustomDialogController = new CustomDialogController({
    alignment: DialogAlignment.Top,
    offset: {
      dx: 0,
      dy: 72
    },
    builder: SlideDialog({
      pageIndex: this.pageIndex,
      totalPage: this.totalPage,
      jump: page => this.doJump(page)
    }),
  })

  build() {
    if (followHandDialogActive(this.appState)) {
      PopoverDialog({
        visible: this.followHandShow,
        popover: this.followHandPopover,
        targetBuilder: () => {
          this.buildTarget()
        }
      }).enabled(this.clickable && this.totalPage > 1)
    } else {
      this.buildTarget()
    }
  }

  @Builder
  buildTarget() {
    Stack() {
      Text() {
        Span(this.pageIndex.toString() + '/').fontSize(FontSizeEnum[this.appState.fontSize].vp24)
        if (this.hideTotal) {
          Span('...')
        } else {
          Span(this.totalPage.toString())
        }
      }.fontColor(this.appTheme.titleBarFont)
    }
    .height(50)
    .attributeModifier(this.clickEffectModifier)
    .clickEffect(this.clickable ? {
      level: ClickEffectLevel.MIDDLE,
      scale: 0.9
    } : undefined)
    .constraintSize({
      minWidth: 50
    })
    .borderRadius(10)
    .onClick(() => {
      if (followHandDialogActive(this.appState)) {
        this.followHandShow = true
      } else if (this.clickable) {
        this.sliderDialog.open()
      }
    })
    .enabled(this.clickable && this.totalPage > 1)
  }

  @Builder
  buildSlideContent() {
    SlideDialogContent({
      pageIndex: this.pageIndex,
      totalPage: this.totalPage,
      jump: (page: number) => {
        this.followHandShow = false
        this.doJump(page)
      },
      close: () => {
        this.followHandShow = false
      }
    })
  }
}
