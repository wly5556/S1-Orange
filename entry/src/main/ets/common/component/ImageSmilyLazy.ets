import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { ImageSmily } from './ImageSmily'

@Component
export struct ImageSmilyLazy {
  @State show: boolean = false
  src = ''
  @Consume appState: PreferenceState
  build() {
    Stack() {
      if (this.show) {
        ImageSmily({
          src: this.src
        })
      }
    }.constraintSize({
      minWidth: FontSizeEnum[this.appState.fontSize].vp36
    })
    .height(FontSizeEnum[this.appState.fontSize].vp36).onVisibleAreaChange([0.01, 1], () => {
      if (!this.show) {
        this.show = true
      }
    })
  }
}