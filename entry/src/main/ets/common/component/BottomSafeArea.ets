import { SafeArea } from '../Constants'

@Component
export struct BottomSafeArea {
  @StorageProp(SafeArea.bottom) bottomRectHeight: number = 0

  build() {
    Row() {
    }
    .width('100%')
    .constraintSize({
      minHeight: px2vp(this.bottomRectHeight)
    })
  }
}
