import { ConfigurationConstant } from '@kit.AbilityKit'

export enum ImageCacheSizeLevel {
  mb64 = 0,
  mb128 = 1,
  mb256 = 2,
  mb512 = 3
}

export enum AvatarTtlLevel {
  perDay = 0,
  perWeek = 1,
  perMonth = 2
}

export enum ThemeIndex {
  light = 0,
  tea = 1,
  amber = 2,
  blue = 3,
  green = 4,
  purple = 5
}

export enum FontSizeIndex {
  xs = 0,
  small = 1,
  medium = 2,
  large = 3,
  xl = 4
}

export enum FontSizeOverride {
  none = 0,
  ignoreSmall = 1,
  ignoreAll = 2
}

export enum HiddenPostDisplay {
  hidden = 0,
  visible = 1,
  visibleWithoutHiddenReason = 2
}

export interface UserAccount {
  name: string
  lastSign: number
}

export class ApplicationConfig {
  version = '1'
  account_list: Record<string, UserAccount> = {}
  user_name: string = ''
  user_uid: string = ''
  image_cache_size: ImageCacheSizeLevel = ImageCacheSizeLevel.mb256
  avatar_cache_ttl: AvatarTtlLevel = AvatarTtlLevel.perWeek
  theme: ThemeIndex = ThemeIndex.tea
  dark_mode_follow_system: boolean = true
  light_dark_mode_prefer: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
  post_copyable: boolean = true
  post_alphabet_indexer: boolean = true
  show_top_thread: boolean = true
  readaccess: number = 0
  show_credit: boolean = false
  font_size: FontSizeIndex = FontSizeIndex.medium
  font_size_override: FontSizeOverride = FontSizeOverride.none
  hidden_post_display: HiddenPostDisplay = HiddenPostDisplay.hidden
  image_upload_service: number = 0
  split_mode: boolean = true
  first_run: boolean = true
  post_signature: boolean = false
  post_signature_device_info: boolean = false
  thread_item_gap: number = 9
  content_line_space: number = 8
  ani_speed_ratio: number = 1
}

export const defaultApplicationConfig = new ApplicationConfig()
