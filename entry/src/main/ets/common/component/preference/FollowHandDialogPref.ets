import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { PreferenceManager } from '../../../config/UserConfig'
import { FollowHandDialogMode } from '../../../config/v1/default'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'

const FollowHandDialogModeText: string[] = []
FollowHandDialogModeText[FollowHandDialogMode.never] = '不使用'
FollowHandDialogModeText[FollowHandDialogMode.splitOnly] = '双栏时'
FollowHandDialogModeText[FollowHandDialogMode.always] = '总是'

@Component
export struct FollowHandDialogPref {
  @Consume @Watch('stateChanged') appState: PreferenceState
  stateChanged() {
    this.segmentOption.fontSize = this.segmentOption.selectedFontSize = FontSizeEnum[this.appState.fontSize].vp16
  }
  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: FollowHandDialogModeText.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('selectedChanged') followHandDialogSelected: FollowHandDialogMode[] = []

  selectedChanged() {
    PreferenceManager.modify(conf => {
      this.followHandDialogSelected.forEach(v => {
        conf.follow_hand_dialog = v
        this.appState.followHandDialog = v
      })
    })
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.followHandDialogSelected.push(conf.follow_hand_dialog)
    })
  }

  build() {
    SegmentButton({
      options: this.segmentOption,
      selectedIndexes: $followHandDialogSelected
    })
  }
}
