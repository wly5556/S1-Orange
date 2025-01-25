import Account from './account'

export interface PrivateMessageList extends Account {
  list: PrivateMessage[]
  count: string
  perpage: string
  page: string
}

export interface PrivateMessage {
  plid: string
  isnew: string
  pmnum: string
  lastupdate: string
  lastdateline: string
  authorid: string
  pmtype: string
  subject: string
  members: string
  dateline: string
  touid: string
  pmid: string
  lastauthorid: string
  lastauthor: string
  lastsummary: string
  msgfromid: string
  msgfrom: string
  message: string
  msgtoid: string
  tousername: string
}
