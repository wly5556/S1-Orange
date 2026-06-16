import { image } from '@kit.ImageKit'

export async function getSnapshotArea(pixelMap: image.PixelMap, scrollYOffsets: number[],
  listWidth: number, listHeight: number): Promise<image.PositionArea> {
  const stride = pixelMap.getBytesNumberPerRow()
  const len = scrollYOffsets.length
  if (len >= 2) {
    const realScrollHeight = scrollYOffsets[len - 1] - scrollYOffsets[len - 2]
    if (realScrollHeight > 0 && listHeight - realScrollHeight > 0) {
      const cropRegion: image.Region = {
        x: 0,
        y: vp2px(listHeight - realScrollHeight),
        size: {
          height: vp2px(realScrollHeight),
          width: vp2px(listWidth)
        }
      }
      await pixelMap.crop(cropRegion)
    }
  }
  const imgInfo = pixelMap.getImageInfoSync()
  const bytesNumber = pixelMap.getPixelBytesNumber()
  const buffer: ArrayBuffer = new ArrayBuffer(bytesNumber)
  const area: image.PositionArea = {
    pixels: buffer,
    offset: 0,
    stride: stride,
    region: {
      size: {
        width: imgInfo.size.width,
        height: imgInfo.size.height
      },
      x: 0,
      y: 0
    }
  }
  pixelMap.readPixelsSync(area)
  return area
}

export function mergeImage(areaArray: image.PositionArea[]): image.PixelMap {
  let imageHeight = 0
  for (let i = 0; i < areaArray.length; i++) {
    imageHeight += areaArray[i].region.size.height
  }
  const opts: image.InitializationOptions = {
    editable: true,
    pixelFormat: 4,
    size: {
      width: areaArray[0].region.size.width,
      height: imageHeight
    }
  }
  const longPixelMap = image.createPixelMapSync(opts)
  let imgPosition: number = 0
  for (let i = 0; i < areaArray.length; i++) {
    const readArea = areaArray[i]
    const area: image.PositionArea = {
      pixels: readArea.pixels,
      offset: 0,
      stride: readArea.stride,
      region: {
        size: {
          width: readArea.region.size.width,
          height: readArea.region.size.height
        },
        x: 0,
        y: imgPosition
      }
    }
    imgPosition += readArea.region.size.height
    longPixelMap.writePixelsSync(area)
  }
  return longPixelMap
}
