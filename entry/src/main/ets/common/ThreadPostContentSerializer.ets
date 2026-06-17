import { GeneralNode, UINodeName, UIRootNode } from './component/ThreadPostContent'

const TABLE_CELL_SEPARATOR = '    '
const SMILY_PATTERN = /\/(?:static\/)?image\/smiley\/([^\/?#]+)\/(\d+)\.(?:png|gif|jpg|jpeg|webp)(?:[?#].*)?$/i
const SMILY_GROUP_PREFIX: Map<string, string> = new Map()
SMILY_GROUP_PREFIX.set('face2017', 'f')
SMILY_GROUP_PREFIX.set('carton2017', 'c')
SMILY_GROUP_PREFIX.set('animal2017', 'a')
SMILY_GROUP_PREFIX.set('device2017', 'd')
SMILY_GROUP_PREFIX.set('goose2017', 'g')
SMILY_GROUP_PREFIX.set('bundam2017', 'b')

export abstract class ContentSerializer {
  abstract convert(nodes: UIRootNode[]): string
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
