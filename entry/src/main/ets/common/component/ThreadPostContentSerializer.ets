import { GeneralNode, UINodeName, UIRootNode } from './ThreadPostContent'

const TABLE_CELL_SEPARATOR = '    '

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
      return this.serializeInlineNodes(root.block)
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
    let result = ''
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i]
      if (node.name == UINodeName.Text) {
        result += node.content
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
