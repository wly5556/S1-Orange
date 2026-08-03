import { markdownSerializer } from './ThreadPostContentSerializer'
import {
  GeneralNode,
  parseXML,
  PostContentParser,
  UINodeName,
  UIRootNode
} from './component/ThreadPostContent'
import { URL } from '../api/base'
import request from '../api/request'
import { ThreadDataApp } from '../api/model/app/thread'
import { wrapperApp } from '../api/wrapper'

const SECTION_SEPARATOR = '\n\n---\n\n'

export interface AskAiStats {
  floorCount: number
  charCount: number
}

export function computeAskAiStats(markdown: string): AskAiStats {
  if (markdown.length == 0) {
    return { floorCount: 0, charCount: 0 }
  }
  const parts = markdown.split(SECTION_SEPARATOR).filter(p => p.length > 0)
  return { floorCount: parts.length, charCount: markdown.length }
}

interface QuoteRedirectInfo {
  tid: string
  page: number
  pid: string
}

interface FetchedPost {
  nodes: UIRootNode[]
  author: string
  dateline: number
  pid: string
}

interface AskAiSection {
  author: string
  dateline: number
  isMain: boolean
  content: string
}

function isQuoteRoot(root: UIRootNode): boolean {
  return root.type == UINodeName.Quote
}

function isRedirectHref(href: string): boolean {
  const n = normalizeHref(href)
  return n.includes('mod=redirect') && n.includes('goto=findpost')
}

function normalizeHref(href: string): string {
  let n = href
  while (n.includes('&amp;')) {
    n = n.replace(/&amp;/g, '&')
  }
  return n
}

function findRedirectHref(nodes: GeneralNode[]): string {
  for (const node of nodes) {
    if (node.name == UINodeName.A) {
      if (node.attribute.length > 0 && isRedirectHref(node.attribute)) {
        return normalizeHref(node.attribute)
      }
      if (node.content.length > 0 && isRedirectHref(node.content)) {
        return normalizeHref(node.content)
      }
    }
    const href = node.styleControl.href
    if (href && href.length > 0 && isRedirectHref(href)) {
      return normalizeHref(href)
    }
    if (node.nestedRootNode) {
      for (const nestedRoot of node.nestedRootNode) {
        const found = findRedirectHref(nestedRoot.block)
        if (found.length > 0) {
          return found
        }
      }
    }
  }
  return ''
}

function extractRedirectHrefFromQuote(quoteRoot: UIRootNode): string {
  for (const node of quoteRoot.block) {
    if (node.nestedRootNode) {
      for (const nestedRoot of node.nestedRootNode) {
        const href = findRedirectHref(nestedRoot.block)
        if (href.length > 0) {
          return href
        }
      }
    }
  }
  return ''
}

async function resolveRedirectLink(href: string): Promise<QuoteRedirectInfo | undefined> {
  let fullHref = href
  if (fullHref.includes(URL.DOMAIN_APP)) {
    fullHref = fullHref.replace(URL.DOMAIN_APP, URL.DOMAIN_WEB)
  }
  if (!fullHref.startsWith('http')) {
    fullHref = URL.WEB_BASE + fullHref
  }
  try {
    const location = await new request<string>(fullHref, '')
      .redirectLocation()
      .get()
    const regex = /tid=(\d+)&page=(\d+)#pid(\d+)/
    const match = location.match(regex)
    if (match && match.length === 4) {
      return { tid: match[1], page: parseInt(match[2]), pid: match[3] }
    }
  } catch (e) {
  }
  return undefined
}

async function fetchPost(tid: string, page: number, pid: string): Promise<FetchedPost | undefined> {
  const matchPid = pid.length > 0
  let cachedPost: FetchedPost | undefined = undefined
  const cacheReady = new Promise<void>(resolve => {
    new request<wrapperApp<ThreadDataApp>>(URL.THREAD_POST_APP, URL.APP_BASE)
      .appToken()
      .cache((v): void => {
        const postlist = v.data.list
        for (const p of postlist) {
          if (!matchPid || p.pid.toString() == pid) {
            const parsed = parseXML([p])
            if (parsed.length > 0) {
              cachedPost = {
                nodes: PostContentParser(parsed[0], []).node,
                author: p.author,
                dateline: p.dateline,
                pid: p.pid.toString()
              }
            }
            break
          }
        }
        resolve()
      }, false, true)
      .post({
        tid: tid,
        pageNo: page,
        uid: ''
      })
      .catch(() => {
        resolve()
      })
  })
  await cacheReady
  if (cachedPost) {
    return cachedPost
  }

  try {
    const v = await new request<wrapperApp<ThreadDataApp>>(URL.THREAD_POST_APP, URL.APP_BASE)
      .appToken()
      .cache((data): void => {
      })
      .post({
        tid: tid,
        pageNo: page,
        uid: ''
      })
    const postlist = v.data.list
    for (const p of postlist) {
      if (!matchPid || p.pid.toString() == pid) {
        const parsed = parseXML([p])
        if (parsed.length > 0) {
          return {
            nodes: PostContentParser(parsed[0], []).node,
            author: p.author,
            dateline: p.dateline,
            pid: p.pid.toString()
          }
        }
      }
    }
  } catch (e) {
  }
  return undefined
}

function pad2(n: number): string {
  return n < 10 ? '0' + n : '' + n
}

function formatQuoteDate(dateline: number): string {
  if (dateline <= 0) {
    return ''
  }
  const date = new Date(dateline * 1000)
  const y = date.getFullYear()
  const m = date.getMonth() + 1
  const d = date.getDate()
  return `${y}-${m}-${d} ${pad2(date.getHours())}:${pad2(date.getMinutes())}`
}

async function flattenPostContentAsync(nodes: UIRootNode[], author: string, dateline: number,
  visitedPids: Set<string>, isMain: boolean): Promise<AskAiSection[]> {
  const ownRoots: UIRootNode[] = []
  const quoteRoots: UIRootNode[] = []

  for (const root of nodes) {
    if (isQuoteRoot(root)) {
      quoteRoots.push(root)
    } else {
      ownRoots.push(root)
    }
  }

  const sections: AskAiSection[] = []

  for (const quoteRoot of quoteRoots) {
    const href = extractRedirectHrefFromQuote(quoteRoot)
    let resolved = false
    if (href.length > 0) {
      const info = await resolveRedirectLink(href)
      if (info) {
        if (visitedPids.has(info.pid)) {
          resolved = true
        } else {
          visitedPids.add(info.pid)
          const fetched = await fetchPost(info.tid, info.page, info.pid)
          if (fetched) {
            const nestedSections = await flattenPostContentAsync(fetched.nodes, fetched.author,
              fetched.dateline, visitedPids, false)
            for (const s of nestedSections) {
              sections.push(s)
            }
            resolved = true
          }
        }
      }
    }
    if (!resolved) {
      for (const node of quoteRoot.block) {
        if (node.nestedRootNode) {
          const nestedSections = await flattenPostContentAsync(node.nestedRootNode, '', 0, visitedPids, false)
          for (const s of nestedSections) {
            sections.push(s)
          }
        }
      }
    }
  }

  const ownContent = ownRoots.length > 0 ? markdownSerializer.convert(ownRoots) : ''
  sections.push({ author, dateline, isMain, content: ownContent })

  return sections
}

function formatSection(section: AskAiSection): string {
  const lines: string[] = []
  if (section.author.length > 0) {
    const mainMarker = section.isMain ? '（主楼） ' : ''
    lines.push(`## ${mainMarker}${section.author} 发表于 ${formatQuoteDate(section.dateline)}`)
  }
  if (section.content.length > 0) {
    lines.push(section.content)
  }
  return lines.join('\n')
}

export async function buildAskAiMarkdown(nodes: UIRootNode[], author: string, dateline: number,
  tid: string, currentPid: string, threadSubject: string,
  includeMain: boolean, includeQuotes: boolean): Promise<string> {
  const parts: string[] = []
  let currentIsMain = false

  if (includeMain && tid.length > 0) {
    const mainPost = await fetchPost(tid, 1, '')
    if (mainPost) {
      if (mainPost.pid != currentPid) {
        const mainContent = mainPost.nodes.length > 0 ? markdownSerializer.convert(mainPost.nodes) : ''
        const mainPart = formatSection({
          author: mainPost.author,
          dateline: mainPost.dateline,
          isMain: true,
          content: mainContent
        })
        if (mainPart.length > 0) {
          parts.push(mainPart)
        }
      } else {
        currentIsMain = true
      }
    }
  }

  if (includeQuotes) {
    const sections = await flattenPostContentAsync(nodes, author, dateline, new Set(), currentIsMain)
    for (const section of sections) {
      const part = formatSection(section)
      if (part.length > 0) {
        parts.push(part)
      }
    }
  } else {
    const ownRoots: UIRootNode[] = []
    for (const root of nodes) {
      if (!isQuoteRoot(root)) {
        ownRoots.push(root)
      }
    }
    const content = ownRoots.length > 0 ? markdownSerializer.convert(ownRoots) : ''
    const part = formatSection({ author, dateline, isMain: currentIsMain, content })
    if (part.length > 0) {
      parts.push(part)
    }
  }

  const body = parts.join(SECTION_SEPARATOR)
  if (threadSubject.length > 0) {
    return `# ${threadSubject}\n\n` + body
  }
  return body
}

export async function buildAskAiPayload(nodes: UIRootNode[], author: string, dateline: number,
  tid: string, currentPid: string, threadSubject: string,
  includeMain: boolean, includeQuotes: boolean, prompt: string): Promise<string> {
  const markdown = await buildAskAiMarkdown(nodes, author, dateline, tid, currentPid,
    threadSubject, includeMain, includeQuotes)
  if (prompt.length == 0) {
    return markdown
  }
  if (markdown.length == 0) {
    return prompt
  }
  return markdown + SECTION_SEPARATOR + prompt
}
