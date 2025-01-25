import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { PreferenceManager } from '../../../config/UserConfig'
import { FontSizeIndex } from '../../../config/v1/default'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'

const FontSizeName: string[] = []
FontSizeName[FontSizeIndex.xs] = '更小'
FontSizeName[FontSizeIndex.small] = '小'
FontSizeName[FontSizeIndex.medium] = '标准'
FontSizeName[FontSizeIndex.large] = '大'
FontSizeName[FontSizeIndex.xl] = '更大'

@Component
export struct FontSizePref {
  @Consume appState: PreferenceState
  @State fontSizeOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: FontSizeName.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('selectedChanged') fontSizeSelected: FontSizeIndex[] = []

  selectedChanged() {
    PreferenceManager.modify(conf => {
      this.fontSizeSelected.forEach(v => {
        conf.font_size = v
        this.appState.fontSize = v
        this.fontSizeOption.fontSize = this.fontSizeOption.selectedFontSize = FontSizeEnum[this.appState.fontSize].vp16
      })
    })
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.fontSizeSelected.push(conf.font_size)
    })
  }

  build() {
    SegmentButton({
      options: this.fontSizeOption,
      selectedIndexes: $fontSizeSelected
    })
  }
}