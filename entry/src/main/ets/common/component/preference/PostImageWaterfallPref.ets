import { PreferenceManager } from '../../../config/UserConfig'
import { PostImageWaterfall } from '../../../config/v1/default'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'
import { PropKey } from '../../Constants'

const WaterfallOptionText: string[] = []
WaterfallOptionText[PostImageWaterfall.off] = '不使用'
WaterfallOptionText[PostImageWaterfall.twoColumns] = '2列'
WaterfallOptionText[PostImageWaterfall.threeColumns] = '3列'
WaterfallOptionText[PostImageWaterfall.fourColumns] = '4列'

const WaterfallOptions: SelectOption[] = [
  { value: WaterfallOptionText[PostImageWaterfall.off] } as SelectOption,
  { value: WaterfallOptionText[PostImageWaterfall.twoColumns] } as SelectOption,
  { value: WaterfallOptionText[PostImageWaterfall.threeColumns] } as SelectOption,
  { value: WaterfallOptionText[PostImageWaterfall.fourColumns] } as SelectOption
]

@Component
export struct PostImageWaterfallPref {
  @Consume appState: PreferenceState
  @StorageProp(PropKey.windowIsLandscape) isLandscape: boolean = false
  @State portraitSelected: number = PostImageWaterfall.off
  @State landscapeSelected: number = PostImageWaterfall.off

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.portraitSelected = conf.post_image_waterfall_portrait
      this.landscapeSelected = conf.post_image_waterfall_landscape
    })
  }

  build() {
    Row() {
      Row({ space: 8 }) {
        Text('竖屏时')
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Medium)
          .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
        Select(WaterfallOptions)
          .selected(this.portraitSelected)
          .value(WaterfallOptionText[this.portraitSelected])
          .font({ size: FontSizeEnum[this.appState.fontSize].vp16 })
          .optionFont({ size: FontSizeEnum[this.appState.fontSize].vp16 })
          .onSelect((index: number) => {
            const mode = index as PostImageWaterfall
            PreferenceManager.modify(conf => {
              conf.post_image_waterfall_portrait = mode
              this.portraitSelected = mode
            })
            if (!this.isLandscape) {
              this.appState.postImageWaterfall = mode
            }
          })
      }.layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      Row({ space: 8 }) {
        Text('横屏时')
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Medium)
          .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
        Select(WaterfallOptions)
          .selected(this.landscapeSelected)
          .value(WaterfallOptionText[this.landscapeSelected])
          .font({ size: FontSizeEnum[this.appState.fontSize].vp16 })
          .optionFont({ size: FontSizeEnum[this.appState.fontSize].vp16 })
          .onSelect((index: number) => {
            const mode = index as PostImageWaterfall
            PreferenceManager.modify(conf => {
              conf.post_image_waterfall_landscape = mode
              this.landscapeSelected = mode
            })
            if (this.isLandscape) {
              this.appState.postImageWaterfall = mode
            }
          })
      }.layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
  }
}