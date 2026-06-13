import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { PreferenceManager } from '../../../config/UserConfig'
import { UpdateCheckInterval } from '../../../config/v1/default'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'

const UpdateCheckIntervalText: string[] = []
UpdateCheckIntervalText[UpdateCheckInterval.monthly] = '每月'
UpdateCheckIntervalText[UpdateCheckInterval.weekly] = '每7天'
UpdateCheckIntervalText[UpdateCheckInterval.never] = '不检查'

export const UpdateCheckIntervalDesc: string[] = []

UpdateCheckIntervalDesc[UpdateCheckInterval.monthly] = '间隔30天检查新版本'
UpdateCheckIntervalDesc[UpdateCheckInterval.weekly] = '间隔7天检查新版本'
UpdateCheckIntervalDesc[UpdateCheckInterval.never] = '不自动检查应用更新'

@Component
export struct UpdateCheckPref {
  @Consume @Watch('stateChanged') appState: PreferenceState

  stateChanged() {
    this.segmentOption.fontSize = this.segmentOption.selectedFontSize = FontSizeEnum[this.appState.fontSize].vp16
  }

  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: UpdateCheckIntervalText.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('selectedChanged') updateCheckSelected: UpdateCheckInterval[] = []

  selectedChanged() {
    PreferenceManager.modify(conf => {
      this.updateCheckSelected.forEach(v => {
        conf.update_check_interval = v
        this.appState.updateCheckInterval = v
      })
    })
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.updateCheckSelected.push(conf.update_check_interval)
    })
  }

  build() {
    SegmentButton({
      options: this.segmentOption,
      selectedIndexes: $updateCheckSelected
    })
  }
}
