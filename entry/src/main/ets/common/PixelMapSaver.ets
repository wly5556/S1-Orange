import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'

export async function savePixelMapToShareTempFile(context: common.UIAbilityContext,
  pixelMap: image.PixelMap): Promise<string> {
  const shareTempFilePath = `${context.tempDir}/S1_Orange_Share_${Date.now()}.png`
  const shareTempFile = fs.openSync(shareTempFilePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
  const packer = image.createImagePacker()
  try {
    await packer.packToFile(pixelMap, shareTempFile.fd, {
      format: 'image/png',
      quality: 100
    })
    return shareTempFilePath
  } catch (e) {
    return ''
  } finally {
    packer.release()
  }
}
