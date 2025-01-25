import Account from './account'

export interface FavList extends Account {
  list: FavThread[] | null
  perpage: string | null
  count: string | null
}

export interface FavThread {
  favid: string
  uid: string
  id: string  // tid
  idtype: string
  spaceuid: string
  title: string
  description: string
  dateline: string
  icon: string
  url: string
  replies: string
  author: string
}