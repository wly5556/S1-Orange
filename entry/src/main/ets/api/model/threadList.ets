import Account from './account';
import { ForumInfo } from './forumGroup';
import { ForumThread } from './thread';

export type ThreadtypeRecord = Record<string, string>

export interface Threadtype {
  required: string
  listable: string
  prefix: string
  types: ThreadtypeRecord
}

export interface ThreadList extends Account {
  forum: ForumInfo
  forum_threadlist: ForumThread[]
  sublist: ForumInfo[]
  page: number
  threadtypes: Threadtype
}