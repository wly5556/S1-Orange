import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { PreferenceManager } from '../../../config/UserConfig'
import { HiddenPostDisplay } from '../../../config/v1/default'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'

const HiddenPostDisplayMode: string[] = []
HiddenPostDisplayMode[HiddenPostDisplay.hidden] = '点击查看'
HiddenPostDisplayMode[HiddenPostDisplay.visible] = '总是显示'
HiddenPostDisplayMode[HiddenPostDisplay.visibleWithoutHiddenReason] = '总是显示+'

export const HiddenPostDisplayModeDesc: string[] = []
HiddenPostDisplayModeDesc[HiddenPostDisplay.hidden] = '不可见内容下方提供按钮，点击后展示从论坛app接口获取到的内容。须知：从app接口也可能无法获取到其实际内容'
HiddenPostDisplayModeDesc[HiddenPostDisplay.visible] = '不可见内容下方，默认附带从论坛app接口获取到的内容。须知：从app接口也可能无法获取到其实际内容'
HiddenPostDisplayModeDesc[HiddenPostDisplay.visibleWithoutHiddenReason] = '若内容不可见，也仅展示从论坛app接口获取到的内容，而不显示“内容被隐藏”的提示，外观与其它正常状态的回帖没有区别。须知：从app接口也可能无法获取到其实际内容'

@Component
export struct HiddenPostPref {
  @Consume @Watch('stateChanged') appState: PreferenceState
  stateChanged() {
    this.segmentOption.fontSize = this.segmentOption.selectedFontSize = FontSizeEnum[this.appState.fontSize].vp16
  }
  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: HiddenPostDisplayMode.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('selectedChanged') hiddenPostDisplaySelected: HiddenPostDisplay[] = []
  selectedChanged() {
    PreferenceManager.modify(conf => {
      this.hiddenPostDisplaySelected.forEach(v => {
        conf.hidden_post_display = v
        this.appState.hiddenPostDisplay = v
      })
    })
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.hiddenPostDisplaySelected.push(conf.hidden_post_display)
    })
  }

  build() {
    SegmentButton({
      options: this.segmentOption,
      selectedIndexes: $hiddenPostDisplaySelected
    })
  }
}