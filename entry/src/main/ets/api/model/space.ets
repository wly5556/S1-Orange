import Account from './account';

export interface Space extends Account {
  space: SpaceInfo,
  extcredits: Record<string, Extcredits>
}

export interface Extcredits {
  title: string
  unit: string
}

export interface SpaceInfo {
  uid: string
  username: string
  adminid: string
  groupid: string
  regdate: string
  credits: string
  freeze: string
  extcredits1: string
  extcredits2: string
  extcredits3: string
  extcredits4: string
  extcredits5: string
  extcredits6: string
  extcredits7: string
  extcredits8: string
  friends: string
  posts: string
  threads: string
  oltime: string
  feeds: string
  follower: string
  following: string
  blacklist: string
  recentnote: string
  spacenote: string
  lastvisit: string
  lastactivity: string
  lastpost: string
  admingroup: Group
  group: Group
  customstatus: string
  medals: string
  sightml: string
}

export interface Group {
  type: string
  grouptitle: string
}