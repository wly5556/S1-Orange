export interface ThreadDataApp {
  webpageurl: string
  totalCount: number
  pageNo: number
  pageSize: number
  list: PostListApp[]
}

export interface PostListApp {
  pid: number
  fid: number
  tid: number
  author: string
  authorid: number
  dateline: number
  message: string
  status: number
  // position: number // 楼层号可能会错误（在tid=1712412发现），不使用
  blocked: boolean
  e: number
  customstatus: string
  grouptitle: string
  gorupid: number
  avatarurl: string
}
