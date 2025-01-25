import Account from './account';

export interface ForumInfo {
  description: string;
  fid: string;
  name: string;
  posts: string;
  threads: string;
  threadcount?: string;
  todayposts: string;
}

export interface ForumGroup extends Account {
  forumlist: ForumInfo[],
}