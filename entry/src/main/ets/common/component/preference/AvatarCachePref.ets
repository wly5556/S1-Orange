import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { PreferenceManager } from '../../../config/UserConfig'
import { AvatarTtlLevel } from '../../../config/v1/default'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'

export const AvatarTtlDay: number[] = []
AvatarTtlDay[AvatarTtlLevel.perDay] = 1
AvatarTtlDay[AvatarTtlLevel.perWeek] = 7
AvatarTtlDay[AvatarTtlLevel.perMonth] = 30

const AvatarTtlLevelText: string[] = []
AvatarTtlLevelText[AvatarTtlLevel.perDay] = '每日'
AvatarTtlLevelText[AvatarTtlLevel.perWeek] = '每周'
AvatarTtlLevelText[AvatarTtlLevel.perMonth] = '每30天'

@Component
export struct AvatarCachePref {
  @Consume @Watch('stateChanged') appState: PreferenceState
  stateChanged() {
    this.segmentOption.fontSize = this.segmentOption.selectedFontSize = FontSizeEnum[this.appState.fontSize].vp16
  }
  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: AvatarTtlLevelText.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('selectedChanged') avatarCacheLevelSelected: AvatarTtlLevel[] = []

  selectedChanged() {
    PreferenceManager.modify(conf => {
      this.avatarCacheLevelSelected.forEach(v => conf.avatar_cache_ttl = v)
    })
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.avatarCacheLevelSelected.push(conf.avatar_cache_ttl)
    })
  }

  build() {
    SegmentButton({
      options: this.segmentOption,
      selectedIndexes: $avatarCacheLevelSelected
    })
  }
}