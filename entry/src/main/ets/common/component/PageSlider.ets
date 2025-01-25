import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { ClickDarkenEffect } from '../Animation'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { AppThemeColor } from '../theme/basic/basic'
import { SlideDialog } from './PageSliderDialog'

@Component
export struct PageSlider {
  @Prop pageIndex: number
  clickEffectModifier: AttributeModifier<CommonAttribute> = new ClickDarkenEffect()
  @Prop totalPage: number
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  hideTotal: boolean = false
  doJump: (page: number) => void = () => {
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
    .clickEffect({
      level: ClickEffectLevel.MIDDLE,
      scale: 0.9
    })
    .constraintSize({
      minWidth: 50
    })
    .borderRadius(10)
    .onClick(e => {
      this.sliderDialog.open()
    })
    .enabled(this.totalPage > 1)
  }
}