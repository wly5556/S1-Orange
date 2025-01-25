import { PreferenceManager } from '../../../config/UserConfig'
import { ThemeArray as ThemeArray, ThemeName } from '../../theme/ThemeEnum'
import { common } from '@kit.AbilityKit'
import { Event } from '../../Events'
import { ThemeIndex } from '../../../config/v1/default'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { AppThemeColor } from '../../theme/basic/basic'

@Component
export struct ThemeSelectPanel {
  @State themeColors: ColorGridPickerItem[] = []
  @State themeSelected: ThemeIndex = 0
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  context = getContext(this) as common.UIAbilityContext

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.themeSelected = conf.theme
      ThemeArray.forEach((theme, i) => {
        this.themeColors.push({
          colorName: ThemeName[i],
          colorValue: theme.titleBar
        })
      })
    })
  }

  build() {
    ColorGridPicker({
      colors: this.themeColors,
      appState: this.appState,
      selected: this.themeSelected,
      backgroundColor: this.appTheme.backgroundPrimary,
      selectedColor: this.appTheme.backgroundSecondary,
      onChange: (index: number): void => {
        this.themeSelected = index
        PreferenceManager.modify(conf => conf.theme = this.themeSelected)
          .then(() => this.context.eventHub.emit(Event.LightModeThemeSwitched))
      }
    })
  }
}

export interface ColorGridPickerItem {
  colorName: string
  colorValue: ResourceColor | undefined
}

export interface ColorGridPickerParam {
  colors: ColorGridPickerItem[],
  appState: PreferenceState
  selected: number,
  backgroundColor: ResourceColor | undefined,
  selectedColor: ResourceColor | undefined,
  onChange: (index: number) => void,
  compact?: boolean
}

@Builder
export function ColorGridPicker(param: ColorGridPickerParam) {
  GridRow({ gutter: 1 }) {
    ForEach(param.colors, (item: ColorGridPickerItem, index: number) => {
      GridCol({
        span: param.compact ? {
          xs: 4,
          md: 3,
          lg: 2
        } : {
          xs: 6,
          md: 4,
          lg: 3
        }
      }) {
        Row() {
          Text(item.colorName)
            .flexShrink(1)
            .flexGrow(1)
            .maxLines(1)
            .fontSize(FontSizeEnum[param.appState.fontSize].vp16)
            .fontWeight(index == param.selected ? FontWeight.Bold : FontWeight.Regular)
            .animation({ duration: 100 })
            .fontColor(index == param.selected ? $r('sys.color.font_emphasize') : undefined)
            .animation({ duration: 100 })
          Blank()
          Row()
            .height(32)
            .width(48)
            .borderRadius(12)
            .backgroundColor(item.colorValue)
        }
        .width('100%')
        .height(48)
        .borderRadius(12)
        .backgroundColor(index == param.selected ? param.selectedColor :
        param.backgroundColor)
        .animation({ duration: 100 })
        .padding({ left: 12, right: 12 })
        .onClick(() => param.onChange(index))
      }
    })
  }
}