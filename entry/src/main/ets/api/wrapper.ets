import Account from './model/account';

interface Message {
  messageval: string;
  messagestr: string;
}

export default interface wrapper<T extends Account> {
  Variables: T;
  Message: Message
}

export interface wrapperApp<T> {
  success: boolean
  message: string
  code: number
  data: T
}