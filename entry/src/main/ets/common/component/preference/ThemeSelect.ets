import { PreferenceManager } from '../../../config/UserConfig'
import { ThemeArray, ThemeName, themeFromIndex } from '../../theme/ThemeEnum'
import { common } from '@kit.AbilityKit'
import { Event } from '../../Events'
import { ThemeIndex } from '../../../config/v1/default'
import { FontSizeEnum } from '../../fontSize/FontSizeEnum'
import { PreferenceState } from '../../../pages/NavProvider/NavigationPage'
import { AppThemeColor } from '../../theme/basic/basic'
import { AniSpeed } from '../../Animation'
import { PropKey } from '../../Constants'
import { openCustomTheme } from '../../../pages/NavDest/CustomTheme'

@Component
export struct ThemeSelectPanel {
  @State themeColors: ColorGridPickerItem[] = []
  @State customPreview: ResourceColor | undefined = '#fff1f3f5'
  @State themeSelected: ThemeIndex = 0
  @Consume @Watch('onAppThemeChanged') appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @Consume(PropKey.pathStack) pathStack: NavPathStack
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
      this.customPreview = themeFromIndex(ThemeIndex.custom, conf.custom_theme_colours).titleBar
    })
  }

  // appTheme 被重新赋值（含自定义配色页内实时修改）时同步自定义主题预览色
  onAppThemeChanged() {
    PreferenceManager.readonly(conf => {
      this.customPreview = themeFromIndex(ThemeIndex.custom, conf.custom_theme_colours).titleBar
    })
  }

  selectTheme(index: ThemeIndex) {
    this.themeSelected = index
    PreferenceManager.modify(conf => {
      conf.theme = index
    }).then(() => this.context.eventHub.emit(Event.LightModeThemeSwitched))
  }

  build() {
    Column({ space: 8 }) {
      ColorGridPicker({
        colors: this.themeColors,
        appState: this.appState,
        selected: this.themeSelected,
        backgroundColor: this.appTheme.backgroundPrimary,
        selectedColor: this.appTheme.backgroundSecondary,
        onChange: (index: number): void => {
          this.selectTheme(index as ThemeIndex)
        }
      })

      Row({ space: 8 }) {
        Text('自定义配色')
          .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
          .fontWeight(this.themeSelected == ThemeIndex.custom ? FontWeight.Bold : FontWeight.Regular)
          .animation({ duration: AniSpeed.ms120 })
          .fontColor(this.themeSelected == ThemeIndex.custom ? $r('sys.color.font_emphasize') : undefined)
          .animation({ duration: AniSpeed.ms120 })
        Blank()
        Row() {
          Row()
            .height(32)
            .width(48)
            .borderRadius(12)
            .backgroundColor(this.customPreview)
          if (this.themeSelected == ThemeIndex.custom) {
            Button('修改')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              .fontColor($r('sys.color.font_emphasize'))
              .height(48)
              .buttonStyle(ButtonStyleMode.TEXTUAL)
              .borderRadius(12)
              .onClick(() => openCustomTheme(this.pathStack))
          }
        }
      }
      .width('100%')
      .height(48)
      .borderRadius(12)
      .backgroundColor(this.themeSelected == ThemeIndex.custom ? this.appTheme.backgroundSecondary :
        this.appTheme.backgroundPrimary)
      .animation({ duration: AniSpeed.ms120 })
      .padding({ left: 12, right: 12 })
      .onClick(() => this.selectTheme(ThemeIndex.custom))
    }
    .width('100%')
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
  GridRow({ gutter: 1, columns: 12 }) {
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
            .animation({ duration: AniSpeed.ms120 })
            .fontColor(index == param.selected ? $r('sys.color.font_emphasize') : undefined)
            .animation({ duration: AniSpeed.ms120 })
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
        .animation({ duration: AniSpeed.ms120 })
        .padding({ left: 12, right: 12 })
        .onClick(() => param.onChange(index))
      }
    })
  }
}