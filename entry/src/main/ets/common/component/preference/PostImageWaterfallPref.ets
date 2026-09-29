import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { PreferenceManager } from '../../../config/UserConfig'
import { PostImageWaterfall } from '../../../config/v1/default'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'

const PostImageWaterfallText: string[] = []
PostImageWaterfallText[PostImageWaterfall.off] = '不使用'
PostImageWaterfallText[PostImageWaterfall.twoColumns] = '2列'
PostImageWaterfallText[PostImageWaterfall.threeColumns] = '3列'
PostImageWaterfallText[PostImageWaterfall.fourColumns] = '4列'

export const PostImageWaterfallDesc: string[] = []
PostImageWaterfallDesc[PostImageWaterfall.off] = '帖子内的图片保持原样依次纵向排列'
PostImageWaterfallDesc[PostImageWaterfall.twoColumns] = '帖子详情与长截图中的图片，以 2 列瀑布流错落排列'
PostImageWaterfallDesc[PostImageWaterfall.threeColumns] = '帖子详情与长截图中的图片，以 3 列瀑布流错落排列'
PostImageWaterfallDesc[PostImageWaterfall.fourColumns] = '帖子详情与长截图中的图片，以 4 列瀑布流错落排列'

@Component
export struct PostImageWaterfallPref {
  @Consume @Watch('stateChanged') appState: PreferenceState
  stateChanged() {
    this.segmentOption.fontSize = this.segmentOption.selectedFontSize = FontSizeEnum[this.appState.fontSize].vp16
  }
  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: PostImageWaterfallText.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('selectedChanged') postImageWaterfallSelected: PostImageWaterfall[] = []
  selectedChanged() {
    PreferenceManager.modify(conf => {
      this.postImageWaterfallSelected.forEach(v => {
        conf.post_image_waterfall = v
        this.appState.postImageWaterfall = v
      })
    })
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.postImageWaterfallSelected.push(conf.post_image_waterfall)
    })
  }

  build() {
    SegmentButton({
      options: this.segmentOption,
      selectedIndexes: $postImageWaterfallSelected
    })
  }
}
