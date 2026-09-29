import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { ImageContainer, RectSize } from './ImageContainer'

export interface GridImage {
  url: string
  index: number
}

const GRID_GAP = 4
const PLACEHOLDER_HEIGHT_BASE = 100

/**
 * 帖子内连续图片段以 WaterFlow 错落模式渲染。
 * WaterFlow 没有内容自适应高度，需要自行按列高贪心算法推算总高。
 * 单元高度与 ImageContainer 实际渲染高度保持一致：
 * 加载前为该组件的默认占位高度，加载后为图片实际显示高度。
 */
@Component
export struct PostImageGrid {
  @Consume appState: PreferenceState
  @State gridHeight: number = 0
  @State gridWidth: number = 0
  images: GridImage[] = []
  columns: number = 2
  lazyLoad: boolean = true
  onImgClick: (url: string, index: number) => void = () => {
  }
  private cellHeights: number[] = []

  private cellWidth(): number | undefined {
    if (this.gridWidth <= 0 || this.columns <= 0) {
      return undefined
    }
    return (this.gridWidth - GRID_GAP * (this.columns - 1)) / this.columns
  }

  aboutToAppear(): void {
    const placeholderHeight = PLACEHOLDER_HEIGHT_BASE * FontSizeEnum[this.appState.fontSize].ratio
    for (let i = 0; i < this.images.length; i++) {
      this.cellHeights.push(placeholderHeight)
    }
    this.gridHeight = this.computeHeight()
  }

  private computeHeight(): number {
    const cols = this.columns
    if (cols <= 0 || this.cellHeights.length == 0) {
      return 0
    }
    const columnHeights: number[] = []
    for (let c = 0; c < cols; c++) {
      columnHeights.push(0)
    }
    for (let i = 0; i < this.cellHeights.length; i++) {
      let target = 0
      for (let c = 1; c < cols; c++) {
        if (columnHeights[c] < columnHeights[target]) {
          target = c
        }
      }
      columnHeights[target] += (columnHeights[target] > 0 ? GRID_GAP : 0) + this.cellHeights[i]
    }
    let total = 0
    for (let c = 0; c < cols; c++) {
      if (columnHeights[c] > total) {
        total = columnHeights[c]
      }
    }
    return total
  }

  build() {
    WaterFlow() {
      ForEach(this.images, (image: GridImage, index: number) => {
        FlowItem() {
          ImageContainer({
            src: image.url,
            lazyLoad: this.lazyLoad,
            fitWidth: this.cellWidth(),
            afterResize: (size: RectSize) => {
              const height = px2vp(size.h)
              if (Math.abs(this.cellHeights[index] - height) < 0.5) {
                return
              }
              this.cellHeights[index] = height
              this.gridHeight = this.computeHeight()
            },
            onImgClick: () => this.onImgClick(image.url, image.index)
          })
        }.width('100%')
      }, (image: GridImage, index: number) => index.toString())
    }
    .columnsTemplate('1fr '.repeat(this.columns).trim())
    .columnsGap(GRID_GAP)
    .rowsGap(GRID_GAP)
    .width('100%')
    .height(this.gridHeight)
    .enableScrollInteraction(false)
    .scrollBar(BarState.Off)
    .onAreaChange((oldValue, newValue) => {
      const width = newValue.width as number
      if (Math.abs(width - this.gridWidth) >= 0.5) {
        this.gridWidth = width
      }
    })
  }
}
