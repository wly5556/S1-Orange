import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { AniSpeed, SpringCurve } from '../Animation'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { AppThemeColor } from '../theme/basic/basic'
import { BottomSafeArea } from './BottomSafeArea'
import { ColorGridPicker, ColorGridPickerItem } from './preference/ThemeSelect'

@Component
export struct FontColorPicker {
  @Consume appTheme: AppThemeColor
  @State pickedColor: number = 0
  @Consume appState: PreferenceState
  onFinish: (color: string) => void = () => {
  }

  aboutToDisappear(): void {
    this.onFinish(WEB_COLOR_PICKER[this.pickedColor].colorValue?.toString() || '')
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Row() {
          Text('当前选择: ' + WEB_COLOR_PICKER[this.pickedColor].colorName)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp18)
            .opacity(.8)
          Text('点击上方区域完成选择').opacity(.5).fontSize(FontSizeEnum[this.appState.fontSize].vp14)
        }.justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text('这是一条示例文字。 ')
          .fontColor(WEB_COLOR_PICKER[this.pickedColor].colorValue).fontSize(FontSizeEnum[this.appState.fontSize].vp20)
          .animation({ duration: AniSpeed.ms200 })
      }.padding(12)
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Scroll() {
        Column() {
          ColorGridPicker({
            compact: true,
            colors: WEB_COLOR_PICKER,
            appState: this.appState,
            selected: this.pickedColor,
            onChange: (index): void => {
              this.pickedColor = index
            },
            backgroundColor: undefined,
            selectedColor: $r('sys.color.background_tertiary')
          })
          BottomSafeArea()
        }
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .flexGrow(1)
      .flexShrink(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .borderRadius(24)
    .padding(8)
    .transition(TransitionEffect.translate({
      y: 600
    }).animation(SpringCurve))
  }
}

@Builder
export function buildFontColorPicker(onFinish: (color: string) => void) {
  FontColorPicker({
    onFinish
  })
}

export const FontColorPickerSheetOption: SheetOptions = {
  height: SheetSize.MEDIUM,
  detents: [SheetSize.MEDIUM, SheetSize.LARGE],
  dragBar: true,
  showClose: false,
  preferType: SheetType.BOTTOM,
  scrollSizeMode: ScrollSizeMode.CONTINUOUS
}

const WEB_COLOR_PICKER: ColorGridPickerItem[] =
  [{ "colorName": "纯黑", "colorValue": "#000000" }, { "colorName": "纯白", "colorValue": "#ffffff" },
    { "colorName": "赭", "colorValue": "#a0522d" },
    { "colorName": "暗橄榄", "colorValue": "#556b2f" }, { "colorName": "暗绿", "colorValue": "#006400" },
    { "colorName": "暗灰蓝", "colorValue": "#483d8b" }, { "colorName": "海军", "colorValue": "#000080" },
    { "colorName": "靛青", "colorValue": "#4b0082" }, { "colorName": "墨绿", "colorValue": "#2f4f4f" },
    { "colorName": "暗红", "colorValue": "#8b0000" }, { "colorName": "暗桔黄", "colorValue": "#ff8c00" },
    { "colorName": "橄榄", "colorValue": "#808000" }, { "colorName": "绿", "colorValue": "#008000" },
    { "colorName": "水鸭", "colorValue": "#008080" }, { "colorName": "蓝", "colorValue": "#0000ff" },
    { "colorName": "灰石", "colorValue": "#708090" }, { "colorName": "暗灰", "colorValue": "#696969" },
    { "colorName": "红", "colorValue": "#ff0000" }, { "colorName": "沙褐", "colorValue": "#f4a460" },
    { "colorName": "黄绿", "colorValue": "#9acd32" }, { "colorName": "海绿", "colorValue": "#2e8b57" },
    { "colorName": "绿宝石", "colorValue": "#48d1cc" }, { "colorName": "皇家蓝", "colorValue": "#4169e1" },
    { "colorName": "紫", "colorValue": "#800080" }, { "colorName": "灰", "colorValue": "#808080" },
    { "colorName": "红紫", "colorValue": "#ff00ff" }, { "colorName": "橙", "colorValue": "#ffa500" },
    { "colorName": "黄", "colorValue": "#ffff00" }, { "colorName": "酸橙", "colorValue": "#00ff00" },
    { "colorName": "青", "colorValue": "#00ffff" }, { "colorName": "深天蓝", "colorValue": "#00bfff" },
    { "colorName": "暗紫", "colorValue": "#9932cc" }, { "colorName": "银", "colorValue": "#c0c0c0" },
    { "colorName": "粉", "colorValue": "#ffc0cb" }, { "colorName": "浅黄", "colorValue": "#f5deb3" },
    { "colorName": "柠檬绸", "colorValue": "#fffacd" }, { "colorName": "苍绿", "colorValue": "#98fb98" },
    { "colorName": "苍宝石", "colorValue": "#afeeee" }, { "colorName": "亮蓝", "colorValue": "#add8e6" },
    { "colorName": "洋李", "colorValue": "#dda0dd" }]