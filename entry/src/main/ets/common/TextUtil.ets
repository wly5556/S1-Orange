import { util } from '@kit.ArkTS';

export function stringToArray(str: string): Uint8Array {
  let textEncoder = new util.TextEncoder()
  return textEncoder.encodeInto(str)
}

export function arrayToString(arr: Uint8Array): string {
  let textDecoder = util.TextDecoder.create("utf-8", { ignoreBOM: true })
  let str = textDecoder.decodeToString(arr, { stream: false })
  return str
}

export function extractFileName(url: string): string | null {
  const match = url.match(/([^\/?#]+)(?=[?#]*$)/)
  return match ? match[0] : null
}

export function extractFileExtension(url: string): string | null {
  const match = url.match(/\.([a-zA-Z0-9]+)(?=[?#]*$)/)
  return match ? match[1] : null
}

interface TextRangeNonUndefined {
  start: number,
  end: number
}

export function dupTextRange(range?: TextRange): TextRangeNonUndefined {
  return {
    start: range?.start || 0,
    end: range?.end || 0
  }
}