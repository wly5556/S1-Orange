import { PersistMap } from './PersistMap'

export interface ImageSize {
  w: number
  h: number
}

const bucketName = 'imageSize'
const persistKey = 'all'

const sizeMap: PersistMap<ImageSize> = new PersistMap<ImageSize>(bucketName, persistKey)

export async function loadImageSizeData(): Promise<void> {
  await sizeMap.load()
}

export function queryImageSize(url: string): ImageSize | undefined {
  return sizeMap.get(url)
}

export function reportImageSize(url: string, w: number, h: number): void {
  if (url.length == 0 || w <= 0 || h <= 0) {
    return
  }
  const cached = sizeMap.get(url)
  if (cached && cached.w == w && cached.h == h) {
    return
  }
  sizeMap.set(url, { w: w, h: h })
}
