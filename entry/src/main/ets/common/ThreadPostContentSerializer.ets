import { URL } from '../api/base'
import { GeneralNode, UINodeName, UIRootNode } from './component/ThreadPostContent'
import { mapColors } from './HTMLColorMap'

const TABLE_CELL_SEPARATOR = '    '
const SMILY_PATTERN = /\/(?:static\/)?image\/smiley\/([^\/?#]+)\/(\d+)\.(?:png|gif|jpg|jpeg|webp)(?:[?#].*)?$/i
const SMILY_GROUP_PREFIX: Map<string, string> = new Map()
SMILY_GROUP_PREFIX.set('face2017', 'f')
SMILY_GROUP_PREFIX.set('carton2017', 'c')
SMILY_GROUP_PREFIX.set('animal2017', 'a')
SMILY_GROUP_PREFIX.set('device2017', 'd')
SMILY_GROUP_PREFIX.set('goose2017', 'g')
SMILY_GROUP_PREFIX.set('bundam2017', 'b')

function reverseSmilyGroupPrefix(source: Map<string, string>): Map<string, string> {
  const result: Map<string, string> = new Map()
  source.forEach((prefix: string, group: string): void => {
    result.set(prefix, group)
  })
  return result
}

const SMILY_PREFIX_GROUP: Map<string, string> = reverseSmilyGroupPrefix(SMILY_GROUP_PREFIX)

export abstract class ContentSerializer {
  abstract convert(nodes: UIRootNode[]): string
}

export abstract class ContentParser {
  abstract convert(input: string): UIRootNode[]
}

export class PlainTextSerializer extends ContentSerializer {
  convert(nodes: UIRootNode[]): string {
    const parts: string[] = []
    for (const node of nodes) {
      const text = this.serializeRoot(node)
      if (text.length > 0) {
        parts.push(text)
      }
    }
    return parts.join('\n')
  }

  private serializeRoot(root: UIRootNode): string {
    if (root.type == UINodeName.Text) {
      return this.serializeInlineNodes(root.block)
    } else if (root.type == UINodeName.Code) {
      return this.serializeCodeInlineNodes(root.block)
    } else if (root.type == UINodeName.Quote) {
      const parts: string[] = []
      for (const node of root.block) {
        if (node.nestedRootNode) {
          parts.push(this.convert(node.nestedRootNode))
        }
      }
      return parts.join('\n')
    } else if (root.type == UINodeName.Div) {
      return ''
    } else if (root.type == UINodeName.Table) {
      const rows: string[] = []
      for (const node of root.block) {
        if (node.name == UINodeName.Tr && node.nestedGeneralNode) {
          const cells: string[] = []
          for (const cellNode of node.nestedGeneralNode) {
            if (cellNode.name == UINodeName.Td && cellNode.nestedRootNode) {
              const cellText = this.convert(cellNode.nestedRootNode)
              cells.push(cellText.replace(/\n/g, ' '))
            }
          }
          rows.push(cells.join(TABLE_CELL_SEPARATOR))
        }
      }
      return rows.join('\n')
    }
    return ''
  }

  private serializeInlineNodes(nodes: GeneralNode[]): string {
    return this.serializeInlineNodesWithOptions(nodes, false)
  }

  serializeCodeInlineNodes(nodes: GeneralNode[]): string {
    return this.serializeInlineNodesWithOptions(nodes, true)
  }

  private serializeInlineNodesWithOptions(nodes: GeneralNode[], excludeCodeLineNumber: boolean): string {
    let result = ''
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i]
      if (node.name == UINodeName.Text) {
        if (!excludeCodeLineNumber || !node.attribute) {
          result += node.content
        }
      } else if (node.name == UINodeName.A) {
        result += node.content
      } else if (node.name == UINodeName.Br) {
        if (i != 0) {
          result += '\n'
        }
      }
    }
    return result
  }
}

export const plainTextSerializer = new PlainTextSerializer()

interface ParserTextStyle {
  weight?: FontWeight
  italic?: FontStyle
  strike?: boolean
  href?: string
  fontSize?: number
}

type ParserRootType = UINodeName.Text | UINodeName.Quote | UINodeName.Code | UINodeName.Div

export class MarkdownParser extends ContentParser {
  private readonly headingSize: number[] = [7, 6, 5, 4, 3]

  convert(input: string): UIRootNode[] {
    const lines = input.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n')
    const roots: UIRootNode[] = []
    const paragraphLines: string[] = []
    let index = 0

    const flushParagraph = (): void => {
      if (paragraphLines.length == 0) {
        return
      }
      this.pushParagraph(roots, paragraphLines)
      paragraphLines.splice(0, paragraphLines.length)
    }

    while (index < lines.length) {
      const line = lines[index]
      if (line.trim().length == 0) {
        flushParagraph()
        index++
        continue
      }

      const fenceMatch = line.match(/^\s{0,3}(```+|~~~+)/)
      if (fenceMatch) {
        flushParagraph()
        const fence = fenceMatch[1]
        const codeLines: string[] = []
        index++
        while (index < lines.length && !lines[index].trim().startsWith(fence)) {
          codeLines.push(lines[index])
          index++
        }
        if (index < lines.length) {
          index++
        }
        roots.push(this.makeRoot(UINodeName.Code, this.textWithBreaks(codeLines.join('\n'), {})))
        continue
      }

      const quoteMatch = line.match(/^\s{0,3}>\s?(.*)$/)
      if (quoteMatch) {
        flushParagraph()
        const quoteLines: string[] = []
        while (index < lines.length) {
          const matched = lines[index].match(/^\s{0,3}>\s?(.*)$/)
          if (!matched) {
            break
          }
          quoteLines.push(matched[1])
          index++
        }
        const quoteNode = new GeneralNode(UINodeName.Quote, '')
        quoteNode.nestedRootNode = this.convert(quoteLines.join('\n'))
        roots.push(this.makeRoot(UINodeName.Quote, [quoteNode]))
        continue
      }

      const unorderedListMatch = line.match(/^\s{0,3}[-+*]\s+(.+)$/)
      const orderedListMatch = line.match(/^\s{0,3}\d+[.)]\s+(.+)$/)
      if (unorderedListMatch || orderedListMatch) {
        flushParagraph()
        const mode = unorderedListMatch ? UINodeName.Ul : UINodeName.Ol
        const items: string[] = []
        while (index < lines.length) {
          const itemMatch = mode == UINodeName.Ul ?
            lines[index].match(/^\s{0,3}[-+*]\s+(.+)$/) :
            lines[index].match(/^\s{0,3}\d+[.)]\s+(.+)$/)
          if (!itemMatch) {
            break
          }
          items.push(itemMatch[1])
          index++
        }
        roots.push(this.makeRoot(UINodeName.Text, this.listNodes(items, mode)))
        continue
      }

      const headingMatch = line.match(/^\s{0,3}(#{1,5})\s+(.+)$/)
      if (headingMatch) {
        flushParagraph()
        const level = headingMatch[1].length
        const style: ParserTextStyle = {
          fontSize: this.headingSize[level - 1]
        }
        roots.push(this.makeRoot(UINodeName.Text, this.parseInline(headingMatch[2], style)))
        index++
        continue
      }

      paragraphLines.push(line)
      index++
    }

    flushParagraph()
    return roots
  }

  private pushParagraph(roots: UIRootNode[], lines: string[]): void {
    const text = lines.join('\n')
    const imageUrl = this.standaloneImageUrl(text.trim())
    if (imageUrl.length > 0) {
      roots.push(this.makeRoot(UINodeName.Div, [new GeneralNode(UINodeName.Img, imageUrl)]))
      return
    }
    roots.push(this.makeRoot(UINodeName.Text, this.parseInline(text, {})))
  }

  private makeRoot(type: ParserRootType, block: GeneralNode[]): UIRootNode {
    return {
      type,
      block,
      textAlign: TextAlign.Start
    }
  }

  private textWithBreaks(text: string, style: ParserTextStyle): GeneralNode[] {
    const nodes: GeneralNode[] = []
    const parts = text.split('\n')
    for (let i = 0; i < parts.length; i++) {
      if (i > 0) {
        nodes.push(new GeneralNode(UINodeName.Br, ''))
      }
      if (parts[i].length > 0) {
        nodes.push(this.textNode(parts[i], style))
      }
    }
    return nodes
  }

  private listNodes(items: string[], mode: UINodeName.Ul | UINodeName.Ol): GeneralNode[] {
    const nodes: GeneralNode[] = []
    for (let i = 0; i < items.length; i++) {
      nodes.push(new GeneralNode(UINodeName.Text, mode == UINodeName.Ol ? `${i + 1} ` : '', mode))
      this.appendNodes(nodes, this.parseInline(items[i], {}))
      if (i + 1 < items.length) {
        nodes.push(new GeneralNode(UINodeName.Br, ''))
      }
    }
    return nodes
  }

  private parseInline(text: string, style: ParserTextStyle): GeneralNode[] {
    const nodes: GeneralNode[] = []
    let buffer = ''
    let index = 0

    const flushText = (): void => {
      if (buffer.length > 0) {
        nodes.push(this.textNode(buffer, style))
        buffer = ''
      }
    }

    while (index < text.length) {
      if (text[index] == '\\' && index + 1 < text.length) {
        buffer += text[index + 1]
        index += 2
        continue
      }

      if (text[index] == '\n') {
        flushText()
        nodes.push(new GeneralNode(UINodeName.Br, ''))
        index++
        continue
      }

      const image = this.inlineImage(text, index)
      if (image.nextIndex > index) {
        flushText()
        nodes.push(this.textNode(`[img]${image.url}[/img]`, style))
        index = image.nextIndex
        continue
      }

      const link = this.inlineLink(text, index)
      if (link.nextIndex > index) {
        flushText()
        this.appendNodes(nodes, this.parseInline(link.text, this.mergeStyle(style, {
          href: link.url
        })))
        index = link.nextIndex
        continue
      }

      const marker = this.inlineMarker(text, index)
      if (marker.length > 0) {
        const closeIndex = text.indexOf(marker, index + marker.length)
        if (closeIndex > index + marker.length) {
          flushText()
          this.appendNodes(nodes, this.parseInline(text.slice(index + marker.length, closeIndex),
            this.mergeStyle(style, this.styleForMarker(marker))))
          index = closeIndex + marker.length
          continue
        }
      }

      buffer += text[index]
      index++
    }

    flushText()
    return nodes
  }

  private appendNodes(target: GeneralNode[], source: GeneralNode[]): void {
    for (const node of source) {
      target.push(node)
    }
  }

  private inlineMarker(text: string, index: number): string {
    if (text.startsWith('**', index) || text.startsWith('__', index) || text.startsWith('~~', index)) {
      return text.slice(index, index + 2)
    }
    if (text[index] == '*' || text[index] == '_') {
      return text[index]
    }
    return ''
  }

  private styleForMarker(marker: string): ParserTextStyle {
    if (marker == '**' || marker == '__') {
      return {
        weight: FontWeight.Bold
      }
    } else if (marker == '~~') {
      return {
        strike: true
      }
    }
    return {
      italic: FontStyle.Italic
    }
  }

  private inlineImage(text: string, index: number): MarkdownInlineLink {
    if (!text.startsWith('![', index)) {
      return {
        text: '',
        url: '',
        nextIndex: index
      }
    }
    const link = this.inlineLinkBody(text, index + 1)
    if (link.nextIndex <= index + 1) {
      return {
        text: '',
        url: '',
        nextIndex: index
      }
    }
    return link
  }

  private inlineLink(text: string, index: number): MarkdownInlineLink {
    if (!text.startsWith('[', index)) {
      return {
        text: '',
        url: '',
        nextIndex: index
      }
    }
    return this.inlineLinkBody(text, index)
  }

  private inlineLinkBody(text: string, startIndex: number): MarkdownInlineLink {
    const labelEnd = text.indexOf(']', startIndex + 1)
    if (labelEnd < 0 || labelEnd + 1 >= text.length || text[labelEnd + 1] != '(') {
      return {
        text: '',
        url: '',
        nextIndex: startIndex
      }
    }
    const urlEnd = text.indexOf(')', labelEnd + 2)
    if (urlEnd < 0) {
      return {
        text: '',
        url: '',
        nextIndex: startIndex
      }
    }
    return {
      text: text.slice(startIndex + 1, labelEnd),
      url: text.slice(labelEnd + 2, urlEnd).trim(),
      nextIndex: urlEnd + 1
    }
  }

  private standaloneImageUrl(text: string): string {
    const image = this.inlineImage(text, 0)
    return image.nextIndex == text.length ? image.url : ''
  }

  private textNode(text: string, style: ParserTextStyle): GeneralNode {
    const node = new GeneralNode(UINodeName.Text, text)
    node.styleControl.weight = style.weight
    node.styleControl.italic = style.italic
    node.styleControl.strike = style.strike
    node.styleControl.href = style.href
    node.styleControl.fontSize = style.fontSize
    return node
  }

  private mergeStyle(base: ParserTextStyle, patch: ParserTextStyle): ParserTextStyle {
    const result = this.cloneStyle(base)
    result.weight = patch.weight !== undefined ? patch.weight : result.weight
    result.italic = patch.italic !== undefined ? patch.italic : result.italic
    result.strike = patch.strike !== undefined ? patch.strike : result.strike
    result.href = patch.href !== undefined ? patch.href : result.href
    result.fontSize = patch.fontSize !== undefined ? patch.fontSize : result.fontSize
    return result
  }

  private cloneStyle(style: ParserTextStyle): ParserTextStyle {
    return {
      weight: style.weight,
      italic: style.italic,
      strike: style.strike,
      href: style.href,
      fontSize: style.fontSize
    }
  }
}

interface MarkdownInlineLink {
  text: string
  url: string
  nextIndex: number
}

export const markdownParser = new MarkdownParser()

interface BBCodeTagToken {
  name: string
  value: string
  raw: string
  closing: boolean
  nextIndex: number
}

interface BBCodeParseResult {
  roots: UIRootNode[]
  nextIndex: number
  closed: boolean
}

interface BBCodeInlineParseResult {
  nodes: GeneralNode[]
  nextIndex: number
  closed: boolean
}

interface BBCodeContentRange {
  content: string
  nextIndex: number
  closed: boolean
}

interface BBCodeParserStyle {
  weight?: FontWeight
  italic?: FontStyle
  underline?: boolean
  strike?: boolean
  href?: string
  color?: ResourceColor
  fontSize?: number
  fontFamily?: string
  backgroundColor?: ResourceColor
}

export class BBCodeParser extends ContentParser {
  private imgUrl: string[] = []
  private attachImageSrc: Record<string, string> = {}

  convert(input: string, attachImageSrc: Record<string, string> = {}): UIRootNode[] {
    this.imgUrl = []
    this.attachImageSrc = attachImageSrc
    return this.parseRoots(input.replace(/\r\n/g, '\n').replace(/\r/g, '\n'), 0, '').roots
  }

  private parseRoots(text: string, startIndex: number, endTag: string): BBCodeParseResult {
    const roots: UIRootNode[] = []
    let inlineNodes: GeneralNode[] = []
    let index = startIndex

    const flushInline = (): void => {
      if (inlineNodes.length == 0) {
        return
      }
      roots.push(this.makeRoot(UINodeName.Text, inlineNodes))
      inlineNodes = []
    }

    while (index < text.length) {
      const tag = this.readTag(text, index)
      if (tag !== undefined) {
        if (tag.closing) {
          if (endTag.length > 0 && tag.name == endTag) {
            flushInline()
            return {
              roots,
              nextIndex: tag.nextIndex,
              closed: true
            }
          }
          this.appendText(inlineNodes, tag.raw, {})
          index = tag.nextIndex
          continue
        }

        if (this.isSmilyTag(tag)) {
          inlineNodes.push(new GeneralNode(UINodeName.ImgSmily, this.smilyUrl(tag.name, tag.value)))
          index = tag.nextIndex
          continue
        }

        if (this.isInlineTag(tag.name)) {
          const parsed = this.parseInlineTag(text, tag, {})
          if (parsed.closed) {
            this.appendNodes(inlineNodes, parsed.nodes)
            index = parsed.nextIndex
          } else {
            this.appendText(inlineNodes, tag.raw, {})
            index = tag.nextIndex
          }
          continue
        }

        if (tag.name == 'quote' || tag.name == 'indent') {
          flushInline()
          const parsed = this.parseRoots(text, tag.nextIndex, tag.name)
          const quoteNode = new GeneralNode(UINodeName.Quote, '')
          quoteNode.nestedRootNode = parsed.roots
          roots.push(this.makeRoot(UINodeName.Quote, [quoteNode]))
          index = parsed.nextIndex
          continue
        } else if (tag.name == 'code') {
          const range = this.readContentUntil(text, tag.nextIndex, 'code')
          if (range.closed) {
            flushInline()
            roots.push(this.makeRoot(UINodeName.Code, this.textWithBreaks(range.content, {})))
            index = range.nextIndex
          } else {
            this.appendText(inlineNodes, tag.raw, {})
            index = tag.nextIndex
          }
          continue
        } else if (tag.name == 'img') {
          const range = this.readContentUntil(text, tag.nextIndex, 'img')
          if (range.closed) {
            const url = range.content.trim()
            if (url.length > 0) {
              if (this.isSmilyUrl(url)) {
                inlineNodes.push(new GeneralNode(UINodeName.ImgSmily, url))
              } else {
                flushInline()
                roots.push(this.makeRoot(UINodeName.Div, [this.makeImageNode(url)]))
              }
            }
            index = range.nextIndex
          } else {
            this.appendText(inlineNodes, tag.raw, {})
            index = tag.nextIndex
          }
          continue
        } else if (tag.name == 'attach') {
          const range = this.readContentUntil(text, tag.nextIndex, 'attach')
          if (range.closed) {
            flushInline()
            roots.push(this.makeRoot(UINodeName.Div, [new GeneralNode(UINodeName.IEdit, `附件: ${range.content.trim()}`)]))
            index = range.nextIndex
          } else {
            this.appendText(inlineNodes, tag.raw, {})
            index = tag.nextIndex
          }
          continue
        } else if (tag.name == 'attachimg') {
          const range = this.readContentUntil(text, tag.nextIndex, 'attachimg')
          if (range.closed) {
            const aid = range.content.trim()
            const src = this.attachImageSrc[aid]
            flushInline()
            if (src && src.length > 0) {
              roots.push(this.makeRoot(UINodeName.Div, [this.makeImageNode(src)]))
            } else {
              roots.push(this.makeRoot(UINodeName.Div, [new GeneralNode(UINodeName.IEdit, `图片附件: ${aid}`)]))
            }
            index = range.nextIndex
          } else {
            this.appendText(inlineNodes, tag.raw, {})
            index = tag.nextIndex
          }
          continue
        } else if (tag.name == 'align') {
          flushInline()
          const parsed = this.parseRoots(text, tag.nextIndex, 'align')
          const align = this.textAlignOf(tag.value)
          for (const root of parsed.roots) {
            root.textAlign = align
            roots.push(root)
          }
          index = parsed.nextIndex
          continue
        } else if (tag.name == 'list') {
          const range = this.readContentUntil(text, tag.nextIndex, 'list')
          if (range.closed) {
            this.appendNodes(inlineNodes, this.parseList(range.content, tag.value == '1'))
            index = range.nextIndex
          } else {
            this.appendText(inlineNodes, tag.raw, {})
            index = tag.nextIndex
          }
          continue
        } else if (tag.name == 'table') {
          const range = this.readContentUntil(text, tag.nextIndex, 'table')
          if (range.closed) {
            flushInline()
            const tableRoot = this.parseTable(range.content)
            if (tableRoot !== undefined) {
              roots.push(tableRoot)
            }
            index = range.nextIndex
          } else {
            this.appendText(inlineNodes, tag.raw, {})
            index = tag.nextIndex
          }
          continue
        }

        this.appendText(inlineNodes, tag.raw, {})
        index = tag.nextIndex
      } else if (text[index] == '\n') {
        inlineNodes.push(new GeneralNode(UINodeName.Br, ''))
        index++
      } else {
        const nextIndex = this.nextSpecialIndex(text, index)
        this.appendText(inlineNodes, text.slice(index, nextIndex), {})
        index = nextIndex
      }
    }

    flushInline()
    return {
      roots,
      nextIndex: index,
      closed: false
    }
  }

  private parseInline(text: string, startIndex: number, endTag: string, style: BBCodeParserStyle): BBCodeInlineParseResult {
    const nodes: GeneralNode[] = []
    let index = startIndex
    while (index < text.length) {
      const tag = this.readTag(text, index)
      if (tag !== undefined) {
        if (tag.closing) {
          if (tag.name == endTag) {
            return {
              nodes,
              nextIndex: tag.nextIndex,
              closed: true
            }
          }
          this.appendText(nodes, tag.raw, style)
          index = tag.nextIndex
          continue
        }
        if (this.isSmilyTag(tag)) {
          nodes.push(new GeneralNode(UINodeName.ImgSmily, this.smilyUrl(tag.name, tag.value)))
          index = tag.nextIndex
          continue
        }
        if (this.isInlineTag(tag.name)) {
          const parsed = this.parseInlineTag(text, tag, style)
          if (parsed.closed) {
            this.appendNodes(nodes, parsed.nodes)
            index = parsed.nextIndex
          } else {
            this.appendText(nodes, tag.raw, style)
            index = tag.nextIndex
          }
          continue
        }
        this.appendText(nodes, tag.raw, style)
        index = tag.nextIndex
      } else if (text[index] == '\n') {
        nodes.push(new GeneralNode(UINodeName.Br, ''))
        index++
      } else {
        const nextIndex = this.nextSpecialIndex(text, index)
        this.appendText(nodes, text.slice(index, nextIndex), style)
        index = nextIndex
      }
    }
    return {
      nodes,
      nextIndex: index,
      closed: false
    }
  }

  private parseInlineTag(text: string, tag: BBCodeTagToken, style: BBCodeParserStyle): BBCodeInlineParseResult {
    const patched = this.cloneStyle(style)
    if (tag.name == 'b') {
      patched.weight = FontWeight.Bold
    } else if (tag.name == 'i') {
      patched.italic = FontStyle.Italic
    } else if (tag.name == 'u') {
      patched.underline = true
    } else if (tag.name == 's' || tag.name == 'strike') {
      patched.strike = true
    } else if (tag.name == 'color') {
      patched.color = mapColors(tag.value)
    } else if (tag.name == 'backcolor') {
      patched.backgroundColor = mapColors(tag.value)
    } else if (tag.name == 'size') {
      const fontSize = parseInt(tag.value)
      if (fontSize > 0) {
        patched.fontSize = fontSize
      }
    } else if (tag.name == 'font') {
      if (tag.value.length > 0) {
        patched.fontFamily = tag.value
      }
    } else if (tag.name == 'url') {
      if (tag.value.length > 0) {
        patched.href = tag.value
      } else {
        const range = this.readContentUntil(text, tag.nextIndex, tag.name)
        if (!range.closed) {
          return {
            nodes: [],
            nextIndex: tag.nextIndex,
            closed: false
          }
        }
        patched.href = range.content.trim()
        const parsed = this.parseInline(range.content, 0, '', patched)
        return {
          nodes: parsed.nodes,
          nextIndex: range.nextIndex,
          closed: true
        }
      }
    }
    return this.parseInline(text, tag.nextIndex, tag.name, patched)
  }

  private parseList(content: string, ordered: boolean): GeneralNode[] {
    const nodes: GeneralNode[] = []
    const parts = content.split('[*]')
    let itemIndex = 1
    for (const part of parts) {
      const item = part.trim()
      if (item.length == 0) {
        continue
      }
      if (nodes.length > 0) {
        nodes.push(new GeneralNode(UINodeName.Br, ''))
      }
      nodes.push(new GeneralNode(UINodeName.Text, ordered ? `${itemIndex} ` : '* ', ordered ? UINodeName.Ol : UINodeName.Ul))
      const parsed = this.parseInline(item, 0, '', {})
      this.appendNodes(nodes, parsed.nodes)
      itemIndex++
    }
    return nodes
  }

  private parseTable(content: string): UIRootNode | undefined {
    const tableNodes: GeneralNode[] = []
    const rowRegex = /\[tr(?:=[^\]]*)?\]([\s\S]*?)\[\/tr\]/gi
    let rowMatch: RegExpExecArray | null
    while ((rowMatch = rowRegex.exec(content)) !== null) {
      const rowNode = new GeneralNode(UINodeName.Tr, '')
      const cells: GeneralNode[] = []
      const cellRegex = /\[td(?:=[^\]]*)?\]([\s\S]*?)\[\/td\]/gi
      let cellMatch: RegExpExecArray | null
      while ((cellMatch = cellRegex.exec(rowMatch[1])) !== null) {
        const cellNode = new GeneralNode(UINodeName.Td, '')
        cellNode.nestedRootNode = this.parseRoots(cellMatch[1], 0, '').roots
        cells.push(cellNode)
      }
      if (cells.length > 0) {
        rowNode.nestedGeneralNode = cells
        tableNodes.push(rowNode)
      }
    }
    if (tableNodes.length == 0) {
      return undefined
    }
    return this.makeRoot(UINodeName.Table, tableNodes)
  }

  private readTag(text: string, index: number): BBCodeTagToken | undefined {
    if (text[index] != '[') {
      return undefined
    }
    const endIndex = text.indexOf(']', index + 1)
    if (endIndex < 0) {
      return undefined
    }
    const raw = text.slice(index, endIndex + 1)
    let body = text.slice(index + 1, endIndex).trim()
    if (body.length == 0) {
      return undefined
    }
    let closing = false
    if (body.startsWith('/')) {
      closing = true
      body = body.slice(1).trim()
    }
    let name = body
    let value = ''
    const equalIndex = body.indexOf('=')
    if (equalIndex > 0) {
      name = body.slice(0, equalIndex).trim()
      value = body.slice(equalIndex + 1).trim()
    } else {
      const colonIndex = body.indexOf(':')
      if (colonIndex > 0) {
        name = body.slice(0, colonIndex).trim()
        value = body.slice(colonIndex + 1).trim()
      }
    }
    return {
      name: name.toLowerCase(),
      value,
      raw,
      closing,
      nextIndex: endIndex + 1
    }
  }

  private readContentUntil(text: string, startIndex: number, tagName: string): BBCodeContentRange {
    const closeTag = `[/${tagName}]`
    const closeIndex = text.toLowerCase().indexOf(closeTag, startIndex)
    if (closeIndex < 0) {
      return {
        content: '',
        nextIndex: startIndex,
        closed: false
      }
    }
    return {
      content: text.slice(startIndex, closeIndex),
      nextIndex: closeIndex + closeTag.length,
      closed: true
    }
  }

  private appendText(nodes: GeneralNode[], text: string, style: BBCodeParserStyle): void {
    const parts = text.split('\n')
    for (let i = 0; i < parts.length; i++) {
      if (i > 0) {
        nodes.push(new GeneralNode(UINodeName.Br, ''))
      }
      if (parts[i].length > 0) {
        nodes.push(this.textNode(parts[i], style))
      }
    }
  }

  private textWithBreaks(text: string, style: BBCodeParserStyle): GeneralNode[] {
    const nodes: GeneralNode[] = []
    this.appendText(nodes, text, style)
    return nodes
  }

  private textNode(text: string, style: BBCodeParserStyle): GeneralNode {
    const node = new GeneralNode(UINodeName.Text, text)
    node.styleControl.weight = style.weight
    node.styleControl.italic = style.italic
    node.styleControl.underline = style.underline
    node.styleControl.strike = style.strike
    node.styleControl.href = style.href
    node.styleControl.color = style.color
    node.styleControl.fontSize = style.fontSize
    node.styleControl.fontFamily = style.fontFamily
    node.styleControl.backgroundColor = style.backgroundColor
    return node
  }

  private makeRoot(type: UINodeName.Text | UINodeName.Quote | UINodeName.Code | UINodeName.Div | UINodeName.Table,
    block: GeneralNode[]): UIRootNode {
    return {
      type,
      block,
      textAlign: TextAlign.Start
    }
  }

  private makeImageNode(url: string): GeneralNode {
    const node = new GeneralNode(UINodeName.Img, url, this.imgUrl.length.toString())
    this.imgUrl.push(url)
    return node
  }

  private appendNodes(target: GeneralNode[], source: GeneralNode[]): void {
    for (const node of source) {
      target.push(node)
    }
  }

  private cloneStyle(style: BBCodeParserStyle): BBCodeParserStyle {
    return {
      weight: style.weight,
      italic: style.italic,
      underline: style.underline,
      strike: style.strike,
      href: style.href,
      color: style.color,
      fontSize: style.fontSize,
      fontFamily: style.fontFamily,
      backgroundColor: style.backgroundColor
    }
  }

  private isInlineTag(name: string): boolean {
    return name == 'b' || name == 'i' || name == 'u' || name == 's' || name == 'strike' ||
      name == 'url' || name == 'color' || name == 'backcolor' || name == 'size' || name == 'font'
  }

  private isSmilyTag(tag: BBCodeTagToken): boolean {
    return SMILY_PREFIX_GROUP.has(tag.name) && tag.value.length > 0
  }

  private isSmilyUrl(url: string): boolean {
    return url.includes(URL.SMILY_HOST_A) || url.includes(URL.SMILY_HOST_B)
  }

  private smilyUrl(prefix: string, id: string): string {
    const group = SMILY_PREFIX_GROUP.get(prefix)
    if (group !== undefined) {
      return URL.SMILY_HOST_A + group + '/' + id + '.png'
    }
    return ''
  }

  private textAlignOf(value: string): TextAlign {
    const align = value.toLowerCase()
    if (align == 'center') {
      return TextAlign.Center
    } else if (align == 'right') {
      return TextAlign.End
    }
    return TextAlign.Start
  }

  private nextSpecialIndex(text: string, startIndex: number): number {
    const bracketIndex = text.indexOf('[', startIndex + 1)
    const breakIndex = text.indexOf('\n', startIndex + 1)
    if (bracketIndex < 0 && breakIndex < 0) {
      return text.length
    } else if (bracketIndex < 0) {
      return breakIndex
    } else if (breakIndex < 0) {
      return bracketIndex
    }
    return Math.min(bracketIndex, breakIndex)
  }
}

export const bbCodeParser = new BBCodeParser()

abstract class StyledContentSerializer extends ContentSerializer {
  convert(nodes: UIRootNode[]): string {
    const parts: string[] = []
    for (const node of nodes) {
      const text = this.serializeRoot(node)
      if (text.length > 0) {
        parts.push(text)
      }
    }
    return parts.join('\n\n')
  }

  protected abstract serializeRoot(root: UIRootNode): string

  protected serializeCodeInlineNodes(nodes: GeneralNode[]): string {
    return plainTextSerializer.serializeCodeInlineNodes(nodes)
  }

  protected colorOf(node: GeneralNode): string {
    const color = node.styleControl.color
    if (typeof color == 'string') {
      return color
    }
    return ''
  }
}

export class MarkdownSerializer extends StyledContentSerializer {
  protected serializeRoot(root: UIRootNode): string {
    if (root.type == UINodeName.Text) {
      return this.serializeInlineNodes(root.block)
    } else if (root.type == UINodeName.Code) {
      return '```\n' + this.serializeCodeInlineNodes(root.block) + '\n```'
    } else if (root.type == UINodeName.Quote) {
      const parts: string[] = []
      for (const node of root.block) {
        if (node.nestedRootNode) {
          parts.push(this.convert(node.nestedRootNode))
        }
      }
      return parts.join('\n\n').split('\n').map(line => '> ' + line).join('\n')
    } else if (root.type == UINodeName.Div) {
      return this.serializeDivNodes(root.block)
    } else if (root.type == UINodeName.Table) {
      return this.serializeTable(root.block)
    }
    return ''
  }

  private serializeDivNodes(nodes: GeneralNode[]): string {
    const parts: string[] = []
    for (const node of nodes) {
      if (node.name == UINodeName.Img || node.name == UINodeName.ImgSmily) {
        parts.push(`![](${node.content})`)
      } else if (node.name == UINodeName.Attach) {
        parts.push(`附件: ${node.content}`)
      } else if (node.name == UINodeName.IEdit) {
        parts.push(node.content)
      } else if (node.nestedRootNode) {
        parts.push(this.convert(node.nestedRootNode))
      }
    }
    return parts.join('\n')
  }

  private serializeTable(nodes: GeneralNode[]): string {
    const rows: string[][] = []
    for (const node of nodes) {
      if (node.name == UINodeName.Tr && node.nestedGeneralNode) {
        const cells: string[] = []
        for (const cellNode of node.nestedGeneralNode) {
          if (cellNode.name == UINodeName.Td && cellNode.nestedRootNode) {
            cells.push(this.convert(cellNode.nestedRootNode).replace(/\n/g, '<br>'))
          }
        }
        rows.push(cells)
      }
    }
    if (rows.length == 0) {
      return ''
    }
    let columnCount = 0
    for (const row of rows) {
      columnCount = Math.max(columnCount, row.length)
    }
    const normalizedRows = rows.map(row => {
      const result = row.slice()
      while (result.length < columnCount) {
        result.push('')
      }
      return result
    })
    const separator: string[] = []
    for (let i = 0; i < columnCount; i++) {
      separator.push('---')
    }
    return ['| ' + normalizedRows[0].join(' | ') + ' |', '| ' + separator.join(' | ') + ' |']
      .concat(normalizedRows.slice(1).map(row => '| ' + row.join(' | ') + ' |'))
      .join('\n')
  }

  private serializeInlineNodes(nodes: GeneralNode[]): string {
    let result = ''
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i]
      if (node.name == UINodeName.Text || node.name == UINodeName.A) {
        result += this.applyMarkdownStyle(node, node.content)
      } else if (node.name == UINodeName.ImgSmily) {
        result += `![](${node.content})`
      } else if (node.name == UINodeName.Br) {
        if (i != 0) {
          result += '\n'
        }
      }
    }
    return result
  }

  private applyMarkdownStyle(node: GeneralNode, text: string): string {
    if (node.attribute == UINodeName.Ul) {
      return '- '
    }
    if (node.styleControl.href) {
      text = `[${text}](${node.styleControl.href})`
    }
    if (node.styleControl.strike) {
      text = `~~${text}~~`
    }
    if (node.styleControl.italic) {
      text = `*${text}*`
    }
    if (node.styleControl.weight) {
      text = `**${text}**`
    }
    return text
  }
}

interface SerializedList {
  content: string
  nextIndex: number
}

export class BBCodeSerializer extends StyledContentSerializer {
  protected serializeRoot(root: UIRootNode): string {
    let result = ''
    if (root.type == UINodeName.Text) {
      result = this.serializeInlineNodes(root.block)
    } else if (root.type == UINodeName.Code) {
      result = '[code]' + this.serializeCodeInlineNodes(root.block) + '[/code]'
    } else if (root.type == UINodeName.Quote) {
      const parts: string[] = []
      for (const node of root.block) {
        if (node.nestedRootNode) {
          parts.push(this.convert(node.nestedRootNode))
        }
      }
      result = '[quote]' + parts.join('\n\n') + '[/quote]'
    } else if (root.type == UINodeName.Div) {
      result = this.serializeDivNodes(root.block)
    } else if (root.type == UINodeName.Table) {
      result = this.serializeTable(root.block)
    }
    const align = this.bbCodeAlignOf(root)
    if (result.length > 0 && align.length > 0) {
      return `[align=${align}]${result}[/align]`
    }
    return result
  }

  private bbCodeAlignOf(root: UIRootNode): string {
    if (root.textAlign == TextAlign.Center) {
      return 'center'
    } else if (root.textAlign == TextAlign.End) {
      return 'right'
    }
    return ''
  }

  private serializeDivNodes(nodes: GeneralNode[]): string {
    const parts: string[] = []
    for (const node of nodes) {
      if (node.name == UINodeName.Img) {
        parts.push(`[img]${node.content}[/img]`)
      } else if (node.name == UINodeName.ImgSmily) {
        parts.push(this.serializeSmily(node.content))
      } else if (node.name == UINodeName.Attach) {
        parts.push(`[attach]${node.content}[/attach]`)
      } else if (node.name == UINodeName.IEdit) {
        parts.push(node.content)
      } else if (node.nestedRootNode) {
        parts.push(this.convert(node.nestedRootNode))
      }
    }
    return parts.join('\n')
  }

  private serializeTable(nodes: GeneralNode[]): string {
    const rows: string[] = []
    for (const node of nodes) {
      if (node.name == UINodeName.Tr && node.nestedGeneralNode) {
        const cells: string[] = []
        for (const cellNode of node.nestedGeneralNode) {
          if (cellNode.name == UINodeName.Td && cellNode.nestedRootNode) {
            cells.push('[td]' + this.convert(cellNode.nestedRootNode) + '[/td]')
          }
        }
        rows.push('[tr]' + cells.join('') + '[/tr]')
      }
    }
    return rows.length > 0 ? '[table]' + rows.join('\n') + '[/table]' : ''
  }

  private serializeInlineNodes(nodes: GeneralNode[]): string {
    let result = ''
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i]
      if (this.isListMarker(node)) {
        const serialized = this.serializeList(nodes, i)
        result += serialized.content
        i = serialized.nextIndex - 1
      } else if (node.name == UINodeName.Text || node.name == UINodeName.A) {
        result += this.applyBBCodeStyle(node, node.content)
      } else if (node.name == UINodeName.ImgSmily) {
        result += this.serializeSmily(node.content)
      } else if (node.name == UINodeName.Br) {
        if (i != 0) {
          result += '\n'
        }
      }
    }
    return result
  }

  private isListMarker(node: GeneralNode): boolean {
    return node.name == UINodeName.Text && (node.attribute == UINodeName.Ul || node.attribute == UINodeName.Ol)
  }

  private serializeList(nodes: GeneralNode[], startIndex: number): SerializedList {
    const listMode = nodes[startIndex].attribute
    const items: string[] = []
    let i = startIndex
    while (i < nodes.length && this.isListMarker(nodes[i]) && nodes[i].attribute == listMode) {
      i++
      let item = ''
      while (i < nodes.length) {
        const node = nodes[i]
        if (this.isListMarker(node)) {
          break
        }
        if (node.name == UINodeName.Br && i + 1 < nodes.length && this.isListMarker(nodes[i + 1])) {
          i++
          break
        }
        item += this.serializeInlineNode(node, item.length == 0)
        i++
      }
      items.push('[*]' + item)
    }
    const listStart = listMode == UINodeName.Ol ? '[list=1]' : '[list]'
    return {
      content: listStart + '\n' + items.join('\n') + '\n[/list]',
      nextIndex: i
    }
  }

  private serializeInlineNode(node: GeneralNode, isFirst: boolean): string {
    if (node.name == UINodeName.Text || node.name == UINodeName.A) {
      return this.applyBBCodeStyle(node, node.content)
    } else if (node.name == UINodeName.ImgSmily) {
      return this.serializeSmily(node.content)
    } else if (node.name == UINodeName.Br) {
      return isFirst ? '' : '\n'
    }
    return ''
  }

  private applyBBCodeStyle(node: GeneralNode, text: string): string {
    if (node.attribute == UINodeName.Ul || node.attribute == UINodeName.Ol) {
      return '[*]'
    }
    if (node.styleControl.href) {
      text = `[url=${node.styleControl.href}]${text}[/url]`
    }
    const color = this.colorOf(node)
    if (color.length > 0) {
      text = `[color=${color}]${text}[/color]`
    }
    if (node.styleControl.fontSize) {
      text = `[size=${node.styleControl.fontSize}]${text}[/size]`
    }
    if (node.styleControl.strike) {
      text = `[s]${text}[/s]`
    }
    if (node.styleControl.underline && !node.styleControl.href) {
      text = `[u]${text}[/u]`
    }
    if (node.styleControl.italic) {
      text = `[i]${text}[/i]`
    }
    if (node.styleControl.weight) {
      text = `[b]${text}[/b]`
    }
    return text
  }

  private serializeSmily(src: string): string {
    const matched = src.match(SMILY_PATTERN)
    if (matched && matched.length == 3) {
      const prefix = SMILY_GROUP_PREFIX.get(matched[1])
      if (prefix) {
        return `[${prefix}:${matched[2]}]`
      }
    }
    return `[img]${src}[/img]`
  }
}

export const markdownSerializer = new MarkdownSerializer()

export const bbCodeSerializer = new BBCodeSerializer()
