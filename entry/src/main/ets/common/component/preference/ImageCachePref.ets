import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { PreferenceManager } from '../../../config/UserConfig'
import { ImageCacheSizeLevel } from '../../../config/v1/default'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'

export const ImageCacheSize: number[] = []
ImageCacheSize[ImageCacheSizeLevel.mb64] = 64
ImageCacheSize[ImageCacheSizeLevel.mb128] = 128
ImageCacheSize[ImageCacheSizeLevel.mb256] = 256
ImageCacheSize[ImageCacheSizeLevel.mb512] = 512

const ImageCacheSizeLevelText: string[] = []
ImageCacheSizeLevelText[ImageCacheSizeLevel.mb64] = '64 MB'
ImageCacheSizeLevelText[ImageCacheSizeLevel.mb128] = '128 MB'
ImageCacheSizeLevelText[ImageCacheSizeLevel.mb256] = '256 MB'
ImageCacheSizeLevelText[ImageCacheSizeLevel.mb512] = '512 MB'

@Component
export struct ImageCachePref {
  @Consume @Watch('stateChanged') appState: PreferenceState
  stateChanged() {
    this.segmentOption.fontSize = this.segmentOption.selectedFontSize = FontSizeEnum[this.appState.fontSize].vp16
  }
  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: ImageCacheSizeLevelText.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('selectedChanged') imageCacheSelected: ImageCacheSizeLevel[] = []

  selectedChanged() {
    PreferenceManager.modify(conf => {
      this.imageCacheSelected.forEach(v => conf.image_cache_size = v)
    })
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.imageCacheSelected.push(conf.image_cache_size)
    })
  }

  build() {
    SegmentButton({
      options: this.segmentOption,
      selectedIndexes: $imageCacheSelected
    })
  }
}