export default interface Account {
  member_uid: string;
  member_username: string;
  readaccess: string;
  formhash: string;
  notice: Notice;
  error?: string
}

export interface Notice {
  newpush: string
  newpm: string
  newprompt: string
  newmypost: string
}