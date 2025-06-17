import { Attachment } from '../../api/model/postList'
import { AppThemeColor } from '../theme/basic/basic'
import { colorizeReplyRedirect, convXML, convXMLOptions, fixUnmatchedTags, unescapeHtmlToXml } from '../XmlParser'
import { Stack as Stack_t } from '@kit.ArkTS'
import { URL } from '../../api/base'
import { mapColors } from '../HTMLColorMap'
import { LengthUnit } from '@kit.ArkUI'
import { ImageContainer } from './ImageContainer'
import { ImageSmily } from './ImageSmily'
import { blockKeywordList } from '../dataStore/BlockKeyword'
import { FontSize, FontSizeEnum } from '../fontSize/FontSizeEnum'
import { FontSizeIndex, FontSizeOverride } from '../../config/v1/default'
import { generateImageViewerTransitionKey } from './ImageViewer'

enum XMLNodeType {
  element = 'element',
  text = 'text',
}

enum UINodeName {
  Root = 'root',
  Br = 'br',
  Img = 'img',
  Div = 'div',
  A = 'a',
  P = 'p',
  Font = 'font',
  Text = 'text',
  Em = 'em',
  ImgSmily = 'imgface',
  Strong = 'strong',
  I = "i",
  U = 'u',
  IEdit = 'iedit',
  Strike = 'strike',
  Quote = 'blockquote',
  Ul = 'ul',
  Ol = 'ol',
  Li = 'li',
  Code = 'code',
  Table = 'table',
  Tr = 'tr',
  Td = 'td'
}


const UINodeParentType: Record<string, UINodeName.Div | UINodeName.Text> = {
  [UINodeName.Img]: UINodeName.Div,
  [UINodeName.IEdit]: UINodeName.Div,
  [UINodeName.Br]: UINodeName.Text,
  [UINodeName.ImgSmily]: UINodeName.Text,
  [UINodeName.Text]: UINodeName.Text,
}

interface TextNode {
  type: XMLNodeType.text
  text: string
}

interface ElementNode {
  type: XMLNodeType.element
  name: string | UINodeName
  attributes?: Record<string, string>
  elements?: (ElementNode | TextNode)[]
}

interface XMLParsed {
  elements: (TextNode | ElementNode)[]
}

function trimBr(root: TextNode | ElementNode) {
  if (root.type == XMLNodeType.element && root.elements) {
    for (let i = root.elements.length - 1; i >= 0; i--) {
      const node = root.elements[i]
      if (node.type == XMLNodeType.element) {
        if (node.name == UINodeName.Br) {
          root.elements.splice(i, 1)
        } else {
          break
        }
      } else {
        break
      }
    }
  }
}

export interface PostToParse {
  message: string,
  attachments?: Record<string, Attachment>
}

function getRootNodeFromXML(xml: string) {
  try {
    const xmlObject = convXML.convertToJSObject(xml, convXMLOptions) as XMLParsed
    const rootNode = xmlObject.elements[0]
    trimBr(rootNode)
    return rootNode
  } catch (err) {
    return null
  }
}

export function parseXML(input: PostToParse[]): XMLParsed[] {
  return input.map((p): (TextNode | ElementNode) => {
    let xmlWrapped = `<root>${unescapeHtmlToXml(p.message)}</root>`
    let blankNode: ElementNode = {
      type: XMLNodeType.element,
      name: UINodeName.Div,
      elements: [{
        type: XMLNodeType.element,
        name: UINodeName.I,
        attributes: { 'class': 'pstatus' },
        elements: [{
          type: XMLNodeType.text,
          text: '未正确渲染的回帖'
        }]
      }, {
        type: XMLNodeType.text,
        text: xmlWrapped
      }]
    }
    if (p.message === undefined) {
      return blankNode
    }

    if (blockKeywordList.some(regex => regex.test(xmlWrapped))) {
      xmlWrapped = '<root>[关键词屏蔽]</root>'
    }

    const attachmentRegex = /\[attach\](\d+)\[\/attach\]/g
    let match: RegExpExecArray | null
    while ((match = attachmentRegex.exec(xmlWrapped)) !== null) {
      const aId = parseInt(match[1], 10);
      if (p.attachments && p.attachments[aId] != undefined) {
        let attachment = p.attachments[aId]
        xmlWrapped = xmlWrapped.replace(match[0], `<img src="${attachment.url + attachment.attachment}"/>`)
      }
    }
    xmlWrapped = colorizeReplyRedirect(xmlWrapped)
    let rootNode = getRootNodeFromXML(xmlWrapped)
    if (rootNode == null) {
      rootNode = getRootNodeFromXML(fixUnmatchedTags(xmlWrapped))
    }
    if (rootNode == null) {
      return blankNode
    }
    return rootNode
  }) as XMLParsed[]
}

interface TextStyleControl {
  color?: ResourceColor
  weight?: FontWeight
  italic?: FontStyle
  underline?: boolean
  strike?: boolean
  href?: string
  fontSize?: number
  fontSizeStyle?: number
  backgroundColor?: ResourceColor
}

interface ThreadPostUINodeRenderParam {
  uiRoot: UIRootNode
  appTheme: AppThemeColor
  fontSize: FontSizeIndex
  fontSizeOverride: FontSizeOverride
  copyOption: CopyOptions
  onLinkClick: (href: string) => void
  onImgClick: (url: string, index: number) => void
  lineSpace: number
}


class TextStyle {
  private static styleStack: Stack_t<TextStyleControl> = new Stack_t()
  static {
    TextStyle.styleStack.push({})
  }
  private static combineStyle(target: TextStyleControl, src: TextStyleControl): void {
    target.color = src.color !== undefined ? src.color : target.color
    target.weight = src.weight !== undefined ? src.weight : target.weight
    target.italic = src.italic !== undefined ? src.italic : target.italic
    target.underline = src.underline !== undefined ? src.underline : target.underline
    target.strike = src.strike !== undefined ? src.strike : target.strike
    target.href = src.href !== undefined ? src.href : target.href
    target.fontSize = src.fontSize !== undefined ? src.fontSize : target.fontSize
    target.fontSizeStyle = src.fontSizeStyle !== undefined ? src.fontSizeStyle : target.fontSizeStyle
    target.backgroundColor = src.backgroundColor !== undefined ? src.backgroundColor : target.backgroundColor
  }

  static combine(style: TextStyleControl, cb: (style: TextStyleControl) => void) {
    const newStyle: TextStyleControl = {}
    TextStyle.combineStyle(newStyle, TextStyle.styleStack.peek())
    TextStyle.combineStyle(newStyle, style)
    TextStyle.styleStack.push(newStyle)
    cb(TextStyle.styleStack.peek())
    TextStyle.styleStack.pop()
  }

  static combineCssStyle(styleString: string, cb: (style: TextStyleControl) => void) {
    const newStyle: TextStyleControl = {}
    const fontSizeMatch = styleString.match(/(?:^|[\s;])font-size:\s*([^;]+)/)
    const colorMatch = styleString.match(/(?:^|[\s;])color:\s*([^;]+)/)
    const backgroundColorMatch = styleString.match(/(?:^|[\s;])background-color:\s*([^;]+)/)
    if (fontSizeMatch) {
      const fontSizeVal = fontSizeMatch[1].trim()
      if (fontSizeVal.endsWith('px')) {
        newStyle.fontSizeStyle = parseInt(fontSizeVal.replace('px', '')) || 16
      }
    }
    if (colorMatch) {
      newStyle.color = mapColors(colorMatch[1])
    }
    if (backgroundColorMatch) {
      newStyle.backgroundColor = mapColors(backgroundColorMatch[1])
    }
    TextStyle.combine(newStyle, cb)
  }

  static peek() {
    return TextStyle.styleStack.peek()
  }
}


class GeneralNode {
  name: UINodeName
  content: string
  attribute: string
  styleControl: TextStyleControl = {}
  nestedRootNode?: UIRootNode[] // 用于tr和quote
  nestedGeneralNode?: GeneralNode[] // 用于td

  constructor(name: UINodeName, content: string, attribute = '') {
    this.name = name
    this.content = content
    this.attribute = attribute
  }

  style(style: TextStyleControl) {
    this.styleControl = style
    return this
  }
}

type RootLevelNode = UINodeName.Text | UINodeName.Quote | UINodeName.Code | UINodeName.Table | UINodeName.Div

class UINodeFactory {
  private blockList: UIRootNode[] = []
  private currentBlock: GeneralNode[] = []
  private alignment: TextAlign = TextAlign.Start
  currentBlockType: RootLevelNode = UINodeName.Text

  peek() {
    if (this.currentBlock.length > 0) {
      return this.currentBlock[this.currentBlock.length - 1]
    }
    return undefined
  }

  push(node: GeneralNode) {
    this.ensureBlockType(UINodeParentType[node.name])
    this.currentBlock.push(node)
  }

  private ensureBlockType(type: UINodeName.Text | UINodeName.Div | undefined) {
    if (type == undefined) {
      return
    }
    if (this.currentBlockType == null) {
      this.newBlock(type)
    } else {
      const currentType = this.currentBlockType != UINodeName.Div ? UINodeName.Text : UINodeName.Div
      if (currentType != type) {
        this.newBlock(type)
      }
    }
  }

  inherit() {
    const n = new UINodeFactory()
    n.alignment = this.alignment
    return n
  }

  withAlign(align: TextAlign, cb: () => void) {
    const restore = this.alignment
    this.newBlock()
    this.alignment = align
    cb()
    this.newBlock()
    this.alignment = restore
  }

  newBlock(type?: RootLevelNode) {
    if (this.currentBlock.length > 0) {
      this.blockList.push({
        type: this.currentBlockType,
        block: this.currentBlock,
        textAlign: this.alignment
      })
      this.currentBlock = []
    }
    this.currentBlockType = type || this.currentBlockType
  }

  finish() {
    this.newBlock()
    return this.blockList
  }
}

interface PostContent {
  node: UIRootNode[]
  imgUrl: string[]
}

export function PostContentParser(root: XMLParsed, imgUrl: string[]): PostContent {
  const rootPost: UINodeFactory = new UINodeFactory() // post = [node[], node[], ...]
  const italicStyle: TextStyleControl = {
    italic: FontStyle.Italic
  }
  const underlineStyle: TextStyleControl = {
    underline: true
  }
  const strikeStyle: TextStyleControl = {
    strike: true
  }
  const strongStyle: TextStyleControl = {
    weight: FontWeight.Bold
  }
  const ContentParser = (node: ElementNode | TextNode, post: UINodeFactory, listRowCounter: number = 1,
    listMode?: UINodeName.Ul | UINodeName.Ol) => {
    if (node.type == XMLNodeType.text) {
      post.push(new GeneralNode(UINodeName.Text, node.text).style(TextStyle.peek()))
      return
    }
    if (node.attributes && node.attributes['style']) {
      TextStyle.combineCssStyle(node.attributes['style'], () => {
        node.attributes!['style'] = ''
        ContentParser(node, post)
      })
      return
    }
    if (node.name == UINodeName.Div) {
      const divClass = node.attributes && node.attributes['class']
      const divId = node.attributes && node.attributes['id']
      if (divClass == 'quote') {
        node.elements?.forEach((n): void => ContentParser(n, post))
      } else if (divId?.startsWith('code_')) {
        post.newBlock(UINodeName.Code)
        node.elements?.forEach((n): void => ContentParser(n, post))
        post.newBlock(UINodeName.Text)
      } else {
        const align = node.attributes && node.attributes['align']
        if (align) {
          let alignment: TextAlign = TextAlign.Start
          if (align == 'left') {
            alignment = TextAlign.Start
          } else if (align == 'right') {
            alignment = TextAlign.End
          } else if (align == 'center') {
            alignment = TextAlign.Center
          } else if (align == 'justify') {
            alignment = TextAlign.JUSTIFY
          }
          post.withAlign(alignment, () => node.elements?.forEach((n): void => ContentParser(n, post)))
        } else {
          node.elements?.forEach((n): void => ContentParser(n, post))
        }
      }
    } else if (node.name == UINodeName.Quote) {
      post.newBlock(UINodeName.Quote)
      const quoteBuilder = post.inherit()
      node.elements?.forEach((n): void => ContentParser(n, quoteBuilder))
      const quoteNode = new GeneralNode(UINodeName.Quote, '')
      quoteNode.nestedRootNode = quoteBuilder.finish()
      post.push(quoteNode)
      post.newBlock(UINodeName.Text)
    } else if (node.name == UINodeName.Img) {
      if (node.attributes && node.attributes['src'] != undefined && node.attributes['src'].length > 0) {
        const imgSrc = node.attributes['src']
        if (imgSrc.includes(URL.SMILY_HOST_A) || imgSrc.includes(URL.SMILY_HOST_B)) {
          post.push(new GeneralNode(UINodeName.ImgSmily, imgSrc))
        } else {
          post.push(new GeneralNode(UINodeName.Img, imgSrc, imgUrl.length.toString()))
          imgUrl.push(imgSrc)
        }
      }
    } else if (node.name == UINodeName.P) {
      post.push(new GeneralNode(UINodeName.Br, ''))
      node.elements?.forEach((n): void => ContentParser(n, post))
      post.push(new GeneralNode(UINodeName.Br, ''))
    } else if (node.name == UINodeName.Br) {
      post.push(new GeneralNode(UINodeName.Br, ''))
    } else if (node.name == UINodeName.A) {
      let href = ''
      if (node.attributes && node.attributes['href']) {
        href = node.attributes['href']
      }
      if (href.length > 0) {
        const linkStyle: TextStyleControl = {
          href: href,
          underline: true
        }
        TextStyle.combine(linkStyle, () => {
          if (node.elements?.length == 0) {
            post.push(new GeneralNode(UINodeName.A, href, href).style(TextStyle.peek()))
          } else {
            node.elements?.forEach((n): void => ContentParser(n, post))
          }
        })
      }
    } else if (node.name == UINodeName.I) {
      if (node.attributes && node.attributes['class'] == 'pstatus') {
        if (node.elements && node.elements.length > 0 && node.elements[0].type == XMLNodeType.text) {
          post.push(new GeneralNode(UINodeName.IEdit, node.elements[0].text))
        }
      } else {
        TextStyle.combine(italicStyle, () => node.elements?.forEach((n): void => ContentParser(n, post)))
      }
    } else if (node.name == UINodeName.Em) {
      if (node.attributes && node.attributes['onclick']?.includes('copycode')) {

      } else {
        TextStyle.combine(italicStyle, () => node.elements?.forEach((n): void => ContentParser(n, post)))
      }
    } else if (node.name == UINodeName.Strong) {
      TextStyle.combine(strongStyle, () => node.elements?.forEach((n): void => ContentParser(n, post)))
    } else if (node.name == UINodeName.U) {
      TextStyle.combine(underlineStyle, () => node.elements?.forEach((n): void => ContentParser(n, post)))
    } else if (node.name == UINodeName.Strike) {
      TextStyle.combine(strikeStyle, () => node.elements?.forEach((n): void => ContentParser(n, post)))
    } else if (node.name == UINodeName.Font) {
      let color: string | undefined = undefined
      let fontSize: number | undefined = undefined
      if (node.attributes) {
        if (node.attributes['color']) {
          color = mapColors(node.attributes['color'])
        }
        if (node.attributes['size']) {
          fontSize = parseInt(node.attributes['size'])
        }
      }
      const fontStyle: TextStyleControl = {
        color, fontSize
      }
      TextStyle.combine(fontStyle, () => node.elements?.forEach((n): void => ContentParser(n, post)))
    } else if (node.name == UINodeName.Ul) {
      post.push(new GeneralNode(UINodeName.Br, ''))
      let listStyle: UINodeName.Ul | UINodeName.Ol = UINodeName.Ul
      // web端样式
      // ul.litype_1 li {
      //   list-style-type: decimal;
      // }
      //
      // ul.litype_2 li {
      //   list-style-type: lower-alpha;
      // }
      //
      // ul.litype_3 li {
      //   list-style-type: upper-alpha;
      // }
      if (node.attributes && node.attributes['class'] == 'litype_1') {
        listStyle = UINodeName.Ol
      }
      let index = 1
      node.elements?.forEach((n): void => {
        if (n.type == XMLNodeType.element && n.name == UINodeName.Li) {
          ContentParser(n, post, index++, listStyle)
        }
      })
    } else if (node.name == UINodeName.Ol) {
      post.push(new GeneralNode(UINodeName.Br, ''))
      let index = 1
      node.elements?.forEach((n): void => {
        if (n.type == XMLNodeType.element && n.name == UINodeName.Li) {
          ContentParser(n, post, index++, UINodeName.Ol)
        }
      })
    } else if (node.name == UINodeName.Li) {
      if (post.peek()?.name != UINodeName.Br) {
        post.push(new GeneralNode(UINodeName.Br, ''))
      }
      if (listMode == UINodeName.Ul) {
        post.push(new GeneralNode(UINodeName.Text, '·').style(TextStyle.peek()))
      } else if (listMode == UINodeName.Ol) {
        TextStyle.combine({
          color: $r('sys.color.font_tertiary')
        }, (): void => post!.push(new GeneralNode(UINodeName.Text, listRowCounter + ' ').style(TextStyle.peek())))
      }
      node.elements?.forEach((n): void => ContentParser(n, post))
    } else if (node.name == UINodeName.Table) {
      post!.newBlock(UINodeName.Table)
      node.elements?.forEach((n): void => ContentParser(n, post))
      post.newBlock(UINodeName.Text)
    } else if (node.name == UINodeName.Tr) {
      const row: UINodeFactory = post.inherit()
      node.elements?.forEach((n): void => ContentParser(n, row))
      const rowNode = new GeneralNode(UINodeName.Tr, '')
      const parsed = row.finish()
      if (parsed.length > 0) {
        rowNode.nestedGeneralNode = parsed[0].block
      }
      post!.push(rowNode)
    } else if (node.name == UINodeName.Td) {
      const cellWidth = node.attributes ? node.attributes['width'] : ''
      const cell: UINodeFactory = post.inherit()
      node.elements?.forEach((n): void => ContentParser(n, cell))
      const cellNode = new GeneralNode(UINodeName.Td, cellWidth)
      cellNode.nestedRootNode = cell.finish()
      post!.push(cellNode)
    }
  }

  root.elements && root.elements.forEach((node): void => ContentParser(node, rootPost))
  return {
    imgUrl,
    node: rootPost.finish()
  }
}

export interface UIRootNode {
  type: RootLevelNode,
  block: GeneralNode[],
  textAlign: TextAlign
}


@Builder
export function ThreadPostUINodeRender(param: ThreadPostUINodeRenderParam) {
  if (param.uiRoot.type == UINodeName.Text) {
    Text() {
      ForEach(param.uiRoot.block,
        (node: GeneralNode, index: number) => TextContentBuilder(node, index, param.onLinkClick,
          FontSizeEnum[param.fontSize], param.fontSizeOverride, param.appTheme.fontEmphasize),
        (node: GeneralNode, index: number) => index.toString())
    }.width('100%')
    .copyOption(param.copyOption)
    .textAlign(param.uiRoot.textAlign)
    .lineSpacing({
      value: param.lineSpace,
      unit: LengthUnit.VP
    })
  } else if (param.uiRoot.type == UINodeName.Quote) {
    Column() {
      ForEach(param.uiRoot.block,
        (node: GeneralNode, index: number) => {
          NestedNodesBuilder(node, param)
        },
        (node: GeneralNode, index: number) => index.toString())
    }
    .width('100%')
    .borderColor(param.appTheme.themeColorDarken)
    .borderWidth({ left: 4 })
    .margin({ bottom: 4 })
    .padding({ left: 8, bottom: 4 })
  } else if (param.uiRoot.type == UINodeName.Div) {
    Column({ space: 8 }) {
      ForEach(param.uiRoot.block, (node: GeneralNode) => {
        if (node.name == UINodeName.Img && node.content) {
          ImageContainer({
            src: node.content,
            onImgClick: () => param.onImgClick(node.content, parseInt(node.attribute))
          }).geometryTransition(generateImageViewerTransitionKey(node.content, node.attribute))
        } else if (node.name == UINodeName.IEdit) {
          Text(node.content)
            .textAlign(TextAlign.Start)
            .width('100%')
            .fontStyle(FontStyle.Italic)
            .opacity(0.7)
            .fontSize(FontSizeEnum[param.fontSize].vp15)
        }
      }, (node: GeneralNode, index: number) => index.toString())
    }.width('100%')
    .alignItems(HorizontalAlign.Start)
  } else if (param.uiRoot.type == UINodeName.Code) {
    Text() {
      ForEach(param.uiRoot.block,
        (node: GeneralNode, index: number) => TextContentBuilder(node, index, param.onLinkClick,
          FontSizeEnum[param.fontSize], param.fontSizeOverride, param.appTheme.fontEmphasize),
        (node: GeneralNode, index: number) => index.toString())
    }
    .width('100%')
    .wordBreak(WordBreak.BREAK_ALL)
    .fontFeature('"ss01" on')
    .copyOption(param.copyOption)
    .textAlign(param.uiRoot.textAlign)
    .border({
      color: param.appTheme.fontPrimary,
      width: 1,
      radius: 6
    })
    .padding(12)
    .backgroundColor(param.appTheme.isDark ? '#32ffffff' : '#45b1b1b1')
  } else if (param.uiRoot.type == UINodeName.Table) {
    Scroll() {
      Column() {
        ForEach(param.uiRoot.block,
          (node: GeneralNode, index: number) => {
            if (node.name == UINodeName.Tr && node.nestedGeneralNode) {
              TableRowBuilder(node.nestedGeneralNode, param)
            }
          }, (node: GeneralNode, index: number) => index.toString())
      }.constraintSize({
        minWidth: '100%'
      }).alignItems(HorizontalAlign.Start)
      .margin({
        bottom: 20
      })
    }.scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.On)
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_ONLY,
      scrollBackward: NestedScrollMode.SELF_ONLY
    })
    .width('100%')
  }
}

@Builder
function TableRowBuilder(block: GeneralNode[], param: ThreadPostUINodeRenderParam) {
  RowSplit() {
    ForEach(block, (node: GeneralNode, index: number) => {
      if (node.name === UINodeName.Td) {
        Column() {
          NestedNodesBuilder(node, param)
        }
        .width((parseInt(node.content) || 150) * 16 / 14 * FontSizeEnum[param.fontSize].ratio)
        .padding(4)
      }
    }, (node: GeneralNode, index: number) => index.toString())
  }.border({
    color: $r('sys.color.font_tertiary'),
    width: 1
  }).resizeable(false)
  .hitTestBehavior(HitTestMode.None)
}

@Builder
function NestedNodesBuilder(node: GeneralNode, param: ThreadPostUINodeRenderParam) {
  if (node.nestedRootNode) {
    ForEach(node.nestedRootNode, (nested: UIRootNode, index: number) => {
      ThreadPostUINodeRender({
        uiRoot: nested,
        appTheme: param.appTheme,
        fontSize: param.fontSize,
        lineSpace: param.lineSpace,
        fontSizeOverride: param.fontSizeOverride,
        copyOption: param.copyOption,
        onLinkClick: param.onLinkClick,
        onImgClick: param.onImgClick
      })
    })
  }
}

@Builder
function TextContentBuilder(node: GeneralNode, index: number, onLinkClick: (href: string) => void, fontSize: FontSize,
  fontSizeOverride: FontSizeOverride, fontEmphasizeColor: ResourceColor = $r('sys.color.font_emphasize')) {
  if (node.name == UINodeName.Text) {
    if (node.styleControl.href) {
      Span(node.content).attributeModifier(new applyTextStyle(node.styleControl, fontSize, fontSizeOverride, fontEmphasizeColor))
        .onClick(() => {
          onLinkClick(node.styleControl.href!)
        })
    } else {
      Span(node.content).attributeModifier(new applyTextStyle(node.styleControl, fontSize, fontSizeOverride, fontEmphasizeColor))
    }
  } else if (node.name == UINodeName.ImgSmily) {
    ImageSmily({
      src: node.content
    })
  } else if (node.name == UINodeName.Br && index != 0) {
    Span('\n')
  }
}


export class applyTextStyle implements AttributeModifier<SpanAttribute> {
  style: TextStyleControl
  fontSize: FontSize
  fontSizeOverride: FontSizeOverride
  emphasizeColor: ResourceColor

  constructor(style: TextStyleControl, fontSize: FontSize, fontSizeUniform: FontSizeOverride, fontEmphasizeColor: ResourceColor) {
    this.style = style
    this.fontSize = fontSize
    this.fontSizeOverride = fontSizeUniform
    this.emphasizeColor = fontEmphasizeColor
  }

  applyNormalAttribute(instance: SpanAttribute): void {
    const style = this.style
    if (style.href) {
      style.color = style.color ?? this.emphasizeColor
    }
    if (style.weight) {
      instance.fontWeight(style.weight)
    }
    if (style.color) {
      instance.fontColor(style.color)
    }
    if (style.italic) {
      instance.fontStyle(style.italic)
    }
    if (style.underline) {
      instance.decoration({
        type: TextDecorationType.Underline,
        color: style.color || this.emphasizeColor
      })
    }
    if (style.strike) {
      instance.decoration({
        type: TextDecorationType.LineThrough,
        color: style.color || this.emphasizeColor
      })
    }
    if (style.backgroundColor) {
      instance.textBackgroundStyle({
        color: style.backgroundColor
      })
    }
    let fontSize: number
    switch (style.fontSize) {
      case 1:
        fontSize = this.fontSize.vp12
        break
      case 2:
        fontSize = this.fontSize.vp13
        break
      case 3:
        fontSize = this.fontSize.vp16
        break
      case 4:
        fontSize = this.fontSize.vp18
        break
      case 5:
        fontSize = this.fontSize.vp24
        break
      case 6:
        fontSize = this.fontSize.vp32
        break
      case 7:
        fontSize = this.fontSize.vp48
        break
      default:
        fontSize = this.fontSize.vp16
        break
    }
    if (style.fontSizeStyle) {
      fontSize = style.fontSizeStyle * this.fontSize.ratio
    }
    if (this.fontSizeOverride == FontSizeOverride.ignoreAll) {
      fontSize = this.fontSize.vp16
    } else if (this.fontSizeOverride == FontSizeOverride.ignoreSmall) {
      fontSize = this.fontSize.vp16 > fontSize ? this.fontSize.vp16 : fontSize
    }
    instance.fontSize(fontSize)
  }
}