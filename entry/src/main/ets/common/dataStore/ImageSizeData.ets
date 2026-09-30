import { PersistMap } from './PersistMap'

export interface ImageSize {
  w: number
  h: number
  hash?: string
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

export function queryImageHash(url: string): string | undefined {
  return sizeMap.get(url)?.hash
}

export function reportImageSize(url: string, w: number, h: number): void {
  if (url.length == 0 || w <= 0 || h <= 0) {
    return
  }
  const cached = sizeMap.get(url)
  if (cached && cached.w == w && cached.h == h) {
    return
  }
  const record: ImageSize = { w: w, h: h }
  if (cached?.hash !== undefined) {
    record.hash = cached.hash
  }
  sizeMap.set(url, record)
}

export function reportImageHash(url: string, w: number, h: number, hash: string): void {
  if (url.length == 0 || hash.length == 0) {
    return
  }
  const cached = sizeMap.get(url)
  if (cached && cached.w == w && cached.h == h && cached.hash == hash) {
    return
  }
  const record: ImageSize = { w: w, h: h, hash: hash }
  sizeMap.set(url, record)
}
