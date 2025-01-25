export interface RipImageUpload {
  success: boolean
  code: string
  message: string
  data: RipImageItem
}

export interface RipImageItem {
  size: number
  path: string
  url: string
  delete_url: string
}
