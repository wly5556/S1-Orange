/*
 * ThumbHash
 *
 * Source: https://github.com/evanw/thumbhash
 * npm: thumbhash@0.1.1
 * Author: Evan Wallace
 *
 * MIT License
 *
 * Copyright (c) Evan Wallace
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import { image } from '@kit.ImageKit'
import { util } from '@kit.ArkTS'

const MAX_ENCODE_SIZE = 100
const PLACEHOLDER_CACHE_MAX = 200

export interface ThumbHashImage {
  w: number
  h: number
  rgba: Uint8Array
}

interface DctChannel {
  dc: number
  ac: number[]
  scale: number
}

/**
 * Encodes an RGBA image to a ThumbHash. RGB should not be premultiplied by A.
 *
 * @param w The width of the input image. Must be ≤100px.
 * @param h The height of the input image. Must be ≤100px.
 * @param rgba The pixels in the input image, row-by-row. Must have w*h*4 elements.
 * @returns The ThumbHash as a Uint8Array.
 */
export function rgbaToThumbHash(w: number, h: number, rgba: Uint8Array): Uint8Array {
  // Encoding an image larger than 100x100 is slow with no benefit
  if (w > 100 || h > 100) {
    throw new Error(`${w}x${h} doesn't fit in 100x100`)
  }
  const PI = Math.PI
  // Determine the average color
  let avg_r = 0
  let avg_g = 0
  let avg_b = 0
  let avg_a = 0
  for (let i = 0, j = 0; i < w * h; i++, j += 4) {
    const alpha = rgba[j + 3] / 255
    avg_r += alpha / 255 * rgba[j]
    avg_g += alpha / 255 * rgba[j + 1]
    avg_b += alpha / 255 * rgba[j + 2]
    avg_a += alpha
  }
  if (avg_a) {
    avg_r /= avg_a
    avg_g /= avg_a
    avg_b /= avg_a
  }
  const hasAlpha = avg_a < w * h
  const l_limit = hasAlpha ? 5 : 7 // Use fewer luminance bits if there's alpha
  const lx = Math.max(1, Math.round(l_limit * w / Math.max(w, h)))
  const ly = Math.max(1, Math.round(l_limit * h / Math.max(w, h)))
  const l: number[] = [] // luminance
  const p: number[] = [] // yellow - blue
  const q: number[] = [] // red - green
  const a: number[] = [] // alpha
  // Convert the image from RGBA to LPQA (composite atop the average color)
  for (let i = 0, j = 0; i < w * h; i++, j += 4) {
    const alpha = rgba[j + 3] / 255
    const r = avg_r * (1 - alpha) + alpha / 255 * rgba[j]
    const g = avg_g * (1 - alpha) + alpha / 255 * rgba[j + 1]
    const b = avg_b * (1 - alpha) + alpha / 255 * rgba[j + 2]
    l.push((r + g + b) / 3)
    p.push((r + g) / 2 - b)
    q.push(r - g)
    a.push(alpha)
  }
  // Encode using the DCT into DC (constant) and normalized AC (varying) terms
  const encodeChannel = (channel: number[], nx: number, ny: number): DctChannel => {
    let dc = 0
    let scale = 0
    const ac: number[] = []
    const fx: number[] = []
    for (let cy = 0; cy < ny; cy++) {
      for (let cx = 0; cx * ny < nx * (ny - cy); cx++) {
        let f = 0
        for (let x = 0; x < w; x++) {
          fx[x] = Math.cos(PI / w * cx * (x + 0.5))
        }
        for (let y = 0; y < h; y++) {
          for (let x = 0, fy = Math.cos(PI / h * cy * (y + 0.5)); x < w; x++) {
            f += channel[x + y * w] * fx[x] * fy
          }
        }
        f /= w * h
        if (cx || cy) {
          ac.push(f)
          scale = Math.max(scale, Math.abs(f))
        } else {
          dc = f
        }
      }
    }
    if (scale) {
      for (let i = 0; i < ac.length; i++) {
        ac[i] = 0.5 + 0.5 / scale * ac[i]
      }
    }
    return { dc: dc, ac: ac, scale: scale }
  }
  const lChannel: DctChannel = encodeChannel(l, Math.max(3, lx), Math.max(3, ly))
  const pChannel: DctChannel = encodeChannel(p, 3, 3)
  const qChannel: DctChannel = encodeChannel(q, 3, 3)
  const aChannel: DctChannel = hasAlpha ? encodeChannel(a, 5, 5) : { dc: 0, ac: [], scale: 0 }
  // Write the constants
  const isLandscape = w > h
  const header24 = Math.round(63 * lChannel.dc)
    | (Math.round(31.5 + 31.5 * pChannel.dc) << 6)
    | (Math.round(31.5 + 31.5 * qChannel.dc) << 12)
    | (Math.round(31 * lChannel.scale) << 18)
    | ((hasAlpha ? 1 : 0) << 23)
  const header16 = (isLandscape ? ly : lx)
    | (Math.round(63 * pChannel.scale) << 3)
    | (Math.round(63 * qChannel.scale) << 9)
    | ((isLandscape ? 1 : 0) << 15)
  const hash: number[] = [header24 & 255, (header24 >> 8) & 255, header24 >> 16, header16 & 255, header16 >> 8]
  const acStart = hasAlpha ? 6 : 5
  if (hasAlpha) {
    hash.push(Math.round(15 * aChannel.dc) | (Math.round(15 * aChannel.scale) << 4))
  }
  const channels: number[][] = hasAlpha
    ? [lChannel.ac, pChannel.ac, qChannel.ac, aChannel.ac]
    : [lChannel.ac, pChannel.ac, qChannel.ac]
  let acCount = 0
  for (let ci = 0; ci < channels.length; ci++) {
    acCount += channels[ci].length
  }
  while (hash.length < acStart + Math.ceil(acCount / 2)) {
    hash.push(0)
  }
  // Write the varying factors
  let acIndex = 0
  for (let ci = 0; ci < channels.length; ci++) {
    const ac = channels[ci]
    for (let i = 0; i < ac.length; i++) {
      const index = acStart + (acIndex >> 1)
      const shift = (acIndex & 1) << 2
      acIndex++
      hash[index] = hash[index] | (Math.round(15 * ac[i]) << shift)
    }
  }
  return new Uint8Array(hash)
}

/**
 * Decodes a ThumbHash to an RGBA image. RGB is not be premultiplied by A.
 *
 * @param hash The bytes of the ThumbHash.
 * @returns The width, height, and pixels of the rendered placeholder image.
 */
export function thumbHashToRGBA(hash: Uint8Array): ThumbHashImage {
  const PI = Math.PI
  // Read the constants
  const header24 = hash[0] | (hash[1] << 8) | (hash[2] << 16)
  const header16 = hash[3] | (hash[4] << 8)
  const l_dc = (header24 & 63) / 63
  const p_dc = ((header24 >> 6) & 63) / 31.5 - 1
  const q_dc = ((header24 >> 12) & 63) / 31.5 - 1
  const l_scale = ((header24 >> 18) & 31) / 31
  const hasAlpha = (header24 >> 23) !== 0
  const p_scale = ((header16 >> 3) & 63) / 63
  const q_scale = ((header16 >> 9) & 63) / 63
  const isLandscape = (header16 >> 15) !== 0
  const lx = Math.max(3, isLandscape ? (hasAlpha ? 5 : 7) : header16 & 7)
  const ly = Math.max(3, isLandscape ? header16 & 7 : (hasAlpha ? 5 : 7))
  const a_dc = hasAlpha ? (hash[5] & 15) / 15 : 1
  const a_scale = (hash[5] >> 4) / 15
  // Read the varying factors (boost saturation by 1.25x to compensate for quantization)
  const acStart = hasAlpha ? 6 : 5
  let acIndex = 0
  const decodeChannel = (nx: number, ny: number, scale: number): number[] => {
    const ac: number[] = []
    for (let cy = 0; cy < ny; cy++) {
      for (let cx = cy ? 0 : 1; cx * ny < nx * (ny - cy); cx++) {
        const index = acStart + (acIndex >> 1)
        const shift = (acIndex & 1) << 2
        acIndex++
        ac.push((((hash[index] >> shift) & 15) / 7.5 - 1) * scale)
      }
    }
    return ac
  }
  const l_ac = decodeChannel(lx, ly, l_scale)
  const p_ac = decodeChannel(3, 3, p_scale * 1.25)
  const q_ac = decodeChannel(3, 3, q_scale * 1.25)
  const a_ac: number[] = hasAlpha ? decodeChannel(5, 5, a_scale) : []
  // Decode using the DCT into RGB
  const ratio = thumbHashToApproximateAspectRatio(hash)
  const w = Math.round(ratio > 1 ? 32 : 32 * ratio)
  const h = Math.round(ratio > 1 ? 32 / ratio : 32)
  const rgba = new Uint8Array(w * h * 4)
  const fx: number[] = []
  const fy: number[] = []
  for (let y = 0, i = 0; y < h; y++) {
    for (let x = 0; x < w; x++, i += 4) {
      let l = l_dc
      let p = p_dc
      let q = q_dc
      let a = a_dc
      // Precompute the coefficients
      for (let cx = 0, n = Math.max(lx, hasAlpha ? 5 : 3); cx < n; cx++) {
        fx[cx] = Math.cos(PI / w * (x + 0.5) * cx)
      }
      for (let cy = 0, n = Math.max(ly, hasAlpha ? 5 : 3); cy < n; cy++) {
        fy[cy] = Math.cos(PI / h * (y + 0.5) * cy)
      }
      // Decode L
      for (let cy = 0, j = 0; cy < ly; cy++) {
        for (let cx = cy ? 0 : 1, fy2 = fy[cy] * 2; cx * ly < lx * (ly - cy); cx++, j++) {
          l += l_ac[j] * fx[cx] * fy2
        }
      }
      // Decode P and Q
      for (let cy = 0, j = 0; cy < 3; cy++) {
        for (let cx = cy ? 0 : 1, fy2 = fy[cy] * 2; cx < 3 - cy; cx++, j++) {
          const f = fx[cx] * fy2
          p += p_ac[j] * f
          q += q_ac[j] * f
        }
      }
      // Decode A
      if (hasAlpha) {
        for (let cy = 0, j = 0; cy < 5; cy++) {
          for (let cx = cy ? 0 : 1, fy2 = fy[cy] * 2; cx < 5 - cy; cx++, j++) {
            a += a_ac[j] * fx[cx] * fy2
          }
        }
      }
      // Convert to RGB
      const b = l - 2 / 3 * p
      const r = (3 * l - b + q) / 2
      const g = r - q
      rgba[i] = Math.max(0, 255 * Math.min(1, r))
      rgba[i + 1] = Math.max(0, 255 * Math.min(1, g))
      rgba[i + 2] = Math.max(0, 255 * Math.min(1, b))
      rgba[i + 3] = Math.max(0, 255 * Math.min(1, a))
    }
  }
  return { w: w, h: h, rgba: rgba }
}

/**
 * Extracts the approximate aspect ratio of the original image.
 *
 * @param hash The bytes of the ThumbHash.
 * @returns The approximate aspect ratio (i.e. width / height).
 */
export function thumbHashToApproximateAspectRatio(hash: Uint8Array): number {
  const header = hash[3]
  const hasAlpha = (hash[2] & 0x80) !== 0
  const isLandscape = (hash[4] & 0x80) !== 0
  const lx = isLandscape ? (hasAlpha ? 5 : 7) : header & 7
  const ly = isLandscape ? header & 7 : (hasAlpha ? 5 : 7)
  return lx / ly
}

/**
 * 从本地图片文件解码一张长边不超过 MAX_ENCODE_SIZE 的缩略图并编码为 base64 的 ThumbHash。
 *
 * @param path 本地图片文件路径
 * @returns base64 的 ThumbHash，失败返回空字符串
 */
export async function encodeThumbHashFromFile(path: string): Promise<string> {
  if (path.length === 0) {
    return ''
  }
  let imageSource: image.ImageSource | undefined = undefined
  let pixelMap: image.PixelMap | undefined = undefined
  try {
    imageSource = image.createImageSource(path)
    const imageInfo = await imageSource.getImageInfo()
    const longSide = Math.max(imageInfo.size.width, imageInfo.size.height)
    if (longSide <= 0) {
      return ''
    }
    const scale = Math.min(1, MAX_ENCODE_SIZE / longSide)
    const options: image.DecodingOptions = {
      desiredSize: {
        width: Math.max(1, Math.round(imageInfo.size.width * scale)),
        height: Math.max(1, Math.round(imageInfo.size.height * scale))
      },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    }
    pixelMap = await imageSource.createPixelMap(options)
    const decodedSize = pixelMap.getImageInfoSync().size
    const w = decodedSize.width
    const h = decodedSize.height
    const area: image.PositionArea = {
      pixels: new ArrayBuffer(w * h * 4),
      offset: 0,
      stride: w * 4,
      region: {
        size: { width: w, height: h },
        x: 0,
        y: 0
      }
    }
    pixelMap.readPixelsSync(area)
    const hash = rgbaToThumbHash(w, h, new Uint8Array(area.pixels))
    return new util.Base64Helper().encodeToStringSync(hash)
  } catch (e) {
    return ''
  } finally {
    if (pixelMap !== undefined) {
      pixelMap.release()
    }
    if (imageSource !== undefined) {
      imageSource.release()
    }
  }
}

const placeholderCache: Map<string, image.PixelMap> = new Map()

/**
 * 把 base64 的 ThumbHash 还原成可直接用于 Image 组件的 PixelMap（带内存缓存）。
 * ThumbHash 的还原图长边固定 32px
 */
export function getPlaceholderPixelMap(url: string, hash: string): image.PixelMap | undefined {
  const cached = placeholderCache.get(url)
  if (cached !== undefined) {
    return cached
  }
  try {
    const decoded = thumbHashToRGBA(new util.Base64Helper().decodeSync(hash))
    const options: image.InitializationOptions = {
      editable: true,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.UNPREMUL,
      size: { width: decoded.w, height: decoded.h }
    }
    const pixelMap = image.createPixelMapSync(decoded.rgba.buffer as ArrayBuffer, options)
    if (placeholderCache.size >= PLACEHOLDER_CACHE_MAX) {
      const oldest = Array.from(placeholderCache.keys())[0]
      placeholderCache.delete(oldest)
    }
    placeholderCache.set(url, pixelMap)
    return pixelMap
  } catch (e) {
    return undefined
  }
}
