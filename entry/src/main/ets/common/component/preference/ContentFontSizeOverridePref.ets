import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { PreferenceManager } from '../../../config/UserConfig'
import { FontSizeOverride } from '../../../config/v1/default'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'

const FontOverrideMode: string[] = []
FontOverrideMode[FontSizeOverride.none] = '按需缩放'
FontOverrideMode[FontSizeOverride.ignoreSmall] = '不缩小'
FontOverrideMode[FontSizeOverride.ignoreAll] = '统一大小'

export const FontOverrideModeDesc: string[] = []
FontOverrideModeDesc[FontSizeOverride.none] = '当帖文指定了字体大小，将会在上一项设置的字体大小基础上，跟随帖文指定的字体大小格式进行比例缩放。帖文显示效果接近网页端'
FontOverrideModeDesc[FontSizeOverride.ignoreSmall] = '当帖文指定了字体大小，且仅当指定的大小大于默认大小，将会根据应用内设置的基础字体大小，进行比例放大。可避免出现不便于阅读的小型文字'
FontOverrideModeDesc[FontSizeOverride.ignoreAll] = '完全忽略帖文的字体大小格式，统一按应用内设置的字体大小来显示帖文。体验类似于浏览器中的阅读模式'

@Component
export struct ContentFontSizeOverridePref {
  @Consume @Watch('stateChanged') appState: PreferenceState
  stateChanged() {
    this.segmentOption.fontSize = this.segmentOption.selectedFontSize = FontSizeEnum[this.appState.fontSize].vp16
  }
  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: FontOverrideMode.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('selectedChanged') fontSizeOverrideSelected: FontSizeOverride[] = []
  selectedChanged() {
    PreferenceManager.modify(conf => {
      this.fontSizeOverrideSelected.forEach(v => {
        conf.font_size_override = v
        this.appState.fontSizeOverride = v
      })
    })
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.fontSizeOverrideSelected.push(conf.font_size_override)
    })
  }

  build() {
    SegmentButton({
      options: this.segmentOption,
      selectedIndexes: $fontSizeOverrideSelected
    })
  }
}