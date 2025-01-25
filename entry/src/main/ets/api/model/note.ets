import Account from './account';

export interface MyNote extends Account {
  list: Note[]
  count: string
  perpage: string
  page: string
}

export interface Note {
  id: string
  uid: string
  type: string
  new: string
  authorid: string
  author?: string
  note: string
  dateline: string
  from_id: string
  from_idtype: string
  from_num: string
  notevar: Notevar
}

export interface Notevar {
  tid: string
  pid: string
  subject: string
  actoruid: string
  actorusername: string
}
