export enum ForumThreadDisplayOrder {
  normal = '0',
  top = '1'
}

export interface ForumThread {
  tid: string
  fid: string
  typeid: string
  author: string
  authorid: string
  subject: string  // 标题，xml特殊符号会被转义
  dateline: string
  lastpost: string
  lastposter: string
  views: string
  replies: string
  readperm: string
  displayorder: ForumThreadDisplayOrder.normal | ForumThreadDisplayOrder.top
}

export interface Reply {
  pid: string
  author: string
  authorid: string
  message: string
  avatar?: string
}
