import Account from './account';

export interface LoginResult extends Account {
  auth: string | null
}