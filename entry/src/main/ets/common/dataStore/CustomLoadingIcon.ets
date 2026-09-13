import { common } from '@kit.AbilityKit'
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit'
import { Event } from '../Events'
import { storeBaseDir } from './JsonPersist'

const LOADING_ICON_DIR = 'custom_loading_icon'
const LOADING_ICON_BASE_NAME = 'loading_icon'
// 与设置页可选择的后缀保持一致
const LOADING_ICON_EXTENSIONS = ['jpg', 'png', 'webp', 'gif']
// Image 组件可自动播放的动图格式，这类图标不需要附加旋转动画
const ANIMATED_EXTENSIONS = ['gif', 'webp']

export function customLoadingIconDir(): string {
  return `${storeBaseDir}/${LOADING_ICON_DIR}`
}

function listIconFiles(): string[] {
  try {
    return fs.listFileSync(customLoadingIconDir())
      .filter((name: string): boolean => name.startsWith(LOADING_ICON_BASE_NAME))
      .sort()
  } catch (e) {
    return []
  }
}

export function hasCustomLoadingIcon(): boolean {
  return listIconFiles().length > 0
}

export function getCustomLoadingIconPath(): string {
  const files = listIconFiles()
  if (files.length == 0) {
    return ''
  }
  return `${customLoadingIconDir()}/${files[files.length - 1]}`
}

export function isAnimatedLoadingIcon(path: string): boolean {
  const lowerCasePath = path.toLowerCase()
  for (const ext of ANIMATED_EXTENSIONS) {
    if (lowerCasePath.endsWith(`.${ext}`)) {
      return true
    }
  }
  return false
}

function removeAllIconFiles(): void {
  listIconFiles().forEach((name: string) => {
    try {
      fs.unlinkSync(`${customLoadingIconDir()}/${name}`)
    } catch (e) {
    }
  })
}

function extensionOfSelectedFile(uri: string): string {
  const decoded = decodeURI(uri)
  const dotIndex = decoded.lastIndexOf('.')
  if (dotIndex < 0) {
    return ''
  }
  const ext = decoded.substring(dotIndex + 1).toLowerCase()
  return LOADING_ICON_EXTENSIONS.includes(ext) ? ext : 'png'
}

export async function setCustomLoadingIcon(uri: string): Promise<void> {
  const dir = customLoadingIconDir()
  if (!fs.accessSync(dir)) {
    await fs.mkdir(dir)
  }
  removeAllIconFiles()
  const ext = extensionOfSelectedFile(uri)
  // 文件名带时间戳，保证路径变化时 Image 组件会重新加载新图
  const targetPath = `${dir}/${LOADING_ICON_BASE_NAME}_${Date.now()}.${ext}`
  await fs.copyFile(uri, targetPath)
  getContext().eventHub.emit(Event.CustomLoadingIconChanged)
}

export function resetCustomLoadingIcon(): void {
  removeAllIconFiles()
  getContext().eventHub.emit(Event.CustomLoadingIconChanged)
}

export async function pickAndSetCustomLoadingIcon(context: common.UIAbilityContext): Promise<boolean> {
  const documentViewPicker = new picker.DocumentViewPicker(context)
  const selectOptions = new picker.DocumentSelectOptions()
  selectOptions.maxSelectNumber = 1
  selectOptions.fileSuffixFilters = ['.jpg', '.png', '.webp', '.gif']
  const result: string[] = await documentViewPicker.select(selectOptions)
  if (result.length == 0) {
    return false
  }
  const filePath = new fileUri.FileUri(result[0]).path
  await setCustomLoadingIcon(filePath)
  return true
}
