import { convertxml } from '@kit.ArkTS';

export const convXML: convertxml.ConvertXML = new convertxml.ConvertXML();

export enum XmlKeys {
  declaration = 'declaration',
  instruction = 'instruction',
  attributes = 'attributes',
  text = 'text',
  cdata = 'cdata',
  doctype = 'doctype',
  comment = 'comment',
  parent = 'parent',
  type = 'type',
  name = 'name',
  elements = 'elements'
}

export const convXMLOptions: convertxml.ConvertOptions = {
  trim: false,
  declarationKey: XmlKeys.declaration,
  instructionKey: XmlKeys.instruction,
  attributesKey: XmlKeys.attributes,
  textKey: XmlKeys.text,
  cdataKey: XmlKeys.cdata,
  doctypeKey: XmlKeys.doctype,
  commentKey: XmlKeys.comment,
  parentKey: XmlKeys.parent,
  typeKey: XmlKeys.type,
  nameKey: XmlKeys.name,
  elementsKey: XmlKeys.elements
}

export function unescapeXml(escapedXml: string) {
  return escapedXml
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
}

const controlChars = /[\x00-\x1F\x7F-\x9F]/g

export function unescapeHtmlToXml(escapedHTML: string) {
  escapedHTML = escapedHTML.replaceAll('&nbsp;', '&#160;').replace(controlChars, '')
  if (escapedHTML.includes('&amp;#x') || escapedHTML.includes('&#x')) {
    escapedHTML = replaceHexCodes(escapedHTML)
  }
  return escapedHTML
}

export function unescapeAll(str: string): string {
  return unescapeXml(unescapeHtmlToXml(str))
}

function replaceHexCodes(input: string): string { // 恢复繁简转换油猴
  const parts = input.split(/(<[^>]*>)/)
  for (let i = 0; i < parts.length; i += 2) {
    parts[i] = parts[i].replace(/(&amp;#x|&#x)([0-9A-Fa-f]+);/g, (_, prefix: string, hex: string): string => {
      const char = String.fromCharCode(parseInt(hex, 16))
      if (char === '<') {
        return '&lt;'
      } else if (char === '>') {
        return '&gt;'
      } else if (char === '&') {
        return '&amp;'
      } else if (char === '"') {
        return '&quot;'
      } else if (char === "'") {
        return '&apos;'
      } else {
        return char
      }
    })
  }

  return parts.join('')
}

export function colorizeReplyRedirect(input: string) {
  const regex = /<a href=".*?\?mod=redirect.*?"><font color="#999999">/g;
  return input.replace(regex, (match) => {
    return match.replace('color="#999999"', 'size="3"')
  })
}

interface TagInfo {
  name: string
  isClosing: boolean
  startIndex: number
  endIndex: number
  remove?: boolean
  prepend: string
}

export function fixUnmatchedTags(html: string): string {
  // 移除重复属性
  const startTagRegex = /<(?<!\/)([a-zA-Z]\w*)(?:[\s]*?|=|(?:[a-zA-Z]\w*)|"[^"]*?"|'[^']*?')*?\/?>/g
  let match: RegExpExecArray | null = null
  const htmlStrArr = html.split("")
  while ((match = startTagRegex.exec(html)) !== null) {
    const tag = match[0]
    const attributeRegex = /([a-zA-Z]\w*)\s*?=\s*?["'][^"']*["']/g
    const existingAttr = new Set<string>()
    const toRemove: number[] = []
    let attrMatch: RegExpExecArray | null
    while ((attrMatch = attributeRegex.exec(tag)) !== null) {
      const attrName = attrMatch[1]
      if (existingAttr.has(attrName)) {
        toRemove.push(match.index + attrMatch.index)
        toRemove.push(attrMatch[0].length)
      } else {
        existingAttr.add(attrName)
      }
    }

    for (let i = 0; i < toRemove.length; i += 2) {
      for (let pos = toRemove[i]; pos < toRemove[i] + toRemove[i + 1]; pos++) {
        htmlStrArr[pos] = ''
      }
    }
  }
  html = htmlStrArr.join('')

  // 确保标签被正确关闭
  const notSelfClosedTagRegex = /<\/?([a-zA-Z]\w*)(?:[\s]*?|\s[a-zA-Z]\w*|=|"[^"]*"|'[^']*')*?(?<!\/)>/g
  const tags: TagInfo[] = []
  while ((match = notSelfClosedTagRegex.exec(html)) !== null) {
    const fullTag = match[0]
    const tagName = match[1].toLowerCase()
    const isClosing = fullTag.startsWith("</")

    tags.push({
      name: tagName,
      isClosing,
      prepend: '',
      startIndex: match.index,
      endIndex: match.index + fullTag.length,
    })
  }

  const stack: TagInfo[] = []
  let result = html

  for (let i = 0; i < tags.length; i++) {
    const currentTag = tags[i]
    const fixingLi = !currentTag.isClosing && currentTag.name == 'li' && stack.length > 0 && stack[stack.length - 1].name != 'ol' && stack[stack.length - 1].name != 'ul'
    if (currentTag.isClosing || fixingLi) {
      let needPop = 0
      let depth = 1
      while (true) {
        const topTag = stack[stack.length - depth]

        if (topTag.name === currentTag.name) {
          needPop = depth
          break
        } else {
          const insertion = `</${topTag.name}>`
          currentTag.prepend += insertion
        }
        depth += 1
        if (depth > stack.length) {
          break
        }
      }
      if (needPop === 0) {
        currentTag.remove = true
      } else if (fixingLi) {
        currentTag.prepend += '</li>'
      }
      while (needPop > 0) {
        stack.pop()
        needPop -= 1
      }
    }
    if (!currentTag.isClosing) {
      stack.push(currentTag)
    }
  }

  for (let i = tags.length - 1; i >= 0; i--) {
    const currentTag = tags[i]
    if (currentTag.remove) {
      result = result.slice(0, currentTag.startIndex) + result.slice(currentTag.endIndex)
    } else if (currentTag.prepend) {
      result = result.slice(0, currentTag.startIndex) + currentTag.prepend + result.slice(currentTag.startIndex)
    }
  }

  while (stack.length > 0) {
    const unmatchedTag = stack.pop()!
    const insertion = `</${unmatchedTag.name}>`
    result += insertion
  }

  return result
}