import { SafeArea } from '../Constants'

@Component
export struct BottomSafeArea {
  @StorageProp(SafeArea.bottom) bottomRectHeight: number = 0

  @Builder
  blankBuilder() {
  }

  @BuilderParam contentBuilder: () => void = this.blankBuilder

  build() {
    Row() {
      this.contentBuilder()
    }
    .width('100%')
    .constraintSize({
      minHeight: px2vp(this.bottomRectHeight)
    })
  }
}
