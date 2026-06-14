import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'

export async function savePixelMapToCache(context: common.UIAbilityContext,
  pixelMap: image.PixelMap): Promise<string> {
  const packer = image.createImagePacker()
  const pngData: ArrayBuffer = await packer.packing(pixelMap, {
    format: 'image/png',
    quality: 100
  })
  const path = `${context.cacheDir}/long_screenshot_${Date.now()}.png`
  const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
  fs.writeSync(file.fd, pngData)
  fs.closeSync(file)
  packer.release()
  return path
}
