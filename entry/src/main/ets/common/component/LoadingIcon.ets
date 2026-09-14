import { common } from '@kit.AbilityKit'

import { Event } from '../Events'
import { getCustomLoadingIconPath, isAnimatedLoadingIcon } from '../dataStore/CustomLoadingIcon'
import { PreferenceManager } from '../../config/UserConfig'

const STATIC_ICON_ROTATE_DURATION_MS = 1000

/**
 * 统一的"加载中"图标：
 * 未在设置中自定义时，渲染系统 LoadingProgress；
 * 已自定义时，渲染用户选择的图片（静态图默认附加无限旋转动画，可在设置中关闭；gif/webp 由 Image 组件自行播放）。
 * top 为 true 时表示顶部（下拉刷新）位置，应用"顶部图标缩放"配置，其余位置应用"其余位置图标缩放"配置。
 */
@Component
export struct LoadingIcon {
  iconSize: Length = 64
  top: boolean = false
  color: ResourceColor = $r('sys.color.ohos_id_color_emphasize')
  @State private iconPath: string = ''
  @State private rotateAngle: number = 0
  @State private iconScale: number = 1
  private eventHub?: common.EventHub
  private readonly onIconChanged: () => void = (): void => {
    this.refreshIcon()
  }

  aboutToAppear(): void {
    const uiAbilityContext = getContext(this) as common.UIAbilityContext
    this.eventHub = uiAbilityContext.eventHub
    this.eventHub.on(Event.CustomLoadingIconChanged, this.onIconChanged)
    this.refreshIcon()
  }

  aboutToDisappear(): void {
    this.eventHub?.off(Event.CustomLoadingIconChanged, this.onIconChanged)
  }

  private refreshIcon(): void {
    const path = getCustomLoadingIconPath()
    this.iconPath = path
    this.rotateAngle = 0
    let rotateStaticIcon = true
    let iconScale = 1
    PreferenceManager.readonly(conf => {
      rotateStaticIcon = conf.custom_loading_icon_rotate
      iconScale = this.top ? conf.custom_loading_icon_scale_top : conf.custom_loading_icon_scale_other
    })
    this.iconScale = iconScale
    if (path.length > 0 && !isAnimatedLoadingIcon(path) && rotateStaticIcon) {
      this.getUIContext().animateTo({
        duration: STATIC_ICON_ROTATE_DURATION_MS,
        curve: Curve.Linear,
        iterations: -1
      }, () => {
        this.rotateAngle = 360
      })
    }
  }

  build() {
    if (this.iconPath.length > 0) {
      Image(`file://${this.iconPath}`)
        .draggable(false)
        .objectFit(ImageFit.Contain)
        .width(this.iconSize)
        .height(this.iconSize)
        .rotate({ angle: this.rotateAngle })
        .scale({ x: this.iconScale, y: this.iconScale })
    } else {
      LoadingProgress()
        .width(this.iconSize)
        .height(this.iconSize)
        .color(this.color)
        .scale({ x: this.iconScale, y: this.iconScale })
    }
  }
}
