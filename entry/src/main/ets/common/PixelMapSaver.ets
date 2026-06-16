import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'

export async function savePixelMapToShareTempFile(context: common.UIAbilityContext,
  pixelMap: image.PixelMap): Promise<string> {
  const packer = image.createImagePacker()
  const pngData: ArrayBuffer = await packer.packing(pixelMap, {
    format: 'image/png',
    quality: 100
  })
  const shareTempFilePath = `${context.tempDir}/S1_Orange_Share_${Date.now()}.png`
  const shareTempFile = fs.openSync(shareTempFilePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
  fs.writeSync(shareTempFile.fd, pngData)
  fs.closeSync(shareTempFile)
  packer.release()
  return shareTempFilePath
}
