import Account from './account'
import { ForumThread } from './thread'

export interface PostList extends Account {
  postlist: Post[]
  thread: ForumThread
  special_poll?: SpecialPoll
}

export interface SpecialPoll {
  polloptions: Record<string, Polloptions>
  expirations: string
  multiple: string
  maxchoices: string
  voterscount: string
  visiblepoll: SpecialPollResultVisible
  allowvote: SpecialPollAllowVote
  remaintime: string
}

export enum SpecialPollAllowVote {
  ALLOW = '1',
  FORBIDDEN = ''
}

export enum SpecialPollResultVisible {
  VISIBLE = '0',
  INVISIBLE = '1'
}

export interface Polloptions {
  polloptionid: string
  polloption: string
  votes: string
  width: string
  percent: string
  color: string
  imginfo: string[]
}

export interface PostListV4 extends PostList {
  comments: Record<string, []>
}

export interface Post {
  pid: string
  tid: string
  first: string
  author: string
  authorid: string
  dateline: string
  message: string
  anonymous: string
  attachment: string
  status: string
  username: string
  adminid: string
  groupid: string
  memberstatus: string
  number?: string
  dbdateline: string
  attachments?: Record<string, Attachment>
  imagelist?: string[]
  position: string
}

export interface Attachment {
  aid: string
  aidencode: string
  url: string
  dateline: string
  filename: string
  filesize: string
  attachment: string
  isimage: string
  width: string
  height: string
  attachicon: string
  attachsize: string
  downloads: string
}