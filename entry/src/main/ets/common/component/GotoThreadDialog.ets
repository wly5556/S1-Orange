import { openThreadPost, openThreadPostByLink, ThreadPostParam } from '../../pages/NavDest/ThreadPostList'

@CustomDialog
export struct GotoThreadDialog {
  controller: CustomDialogController
  @State threadUrl: string = ''
  getPathStack?: () => NavPathStack

  build() {
    Column({ space: 16 }) {
      Text('跳转到帖子')
        .width('100%')
        .fontSize(20)
      TextInput({ text: $$this.threadUrl, placeholder: '帖子链接 / 帖子的数字id' })
        .width('100%')

      Row() {
        Button('取消', { buttonStyle: ButtonStyleMode.TEXTUAL }).onClick(() => this.controller.close())
          .margin({ right: 10 })
          .layoutWeight(1)
        Button('跳转', { buttonStyle: ButtonStyleMode.TEXTUAL })
          .margin({ left: 10 })
          .layoutWeight(1)
          .onClick(e => {
            if (!this.getPathStack) {
              return
            }
            if (!isNaN(parseInt(this.threadUrl))) {
              const param: ThreadPostParam = {
                tid: this.threadUrl
              }
              openThreadPost(param, this.getPathStack())
              this.controller.close()
            } else {
              openThreadPostByLink(this.threadUrl,
                this.getPathStack(), () => {
                  this.getUIContext().getPromptAction().showToast({
                    message: '解析帖子链接出错'
                  })
                })
              this.controller.close()
            }
          })
      }.width('100%')
    }.padding(24)
  }
}

export interface S1WebLink {
  tid: string
  page: number
  authorId?: string
}

export function resolveS1WebLink(threadUrl: string): S1WebLink | null {
  const regex = /thread-(\d+)-(\d+)-/
  const match = threadUrl.match(regex)

  if (match && match.length === 3 && !isNaN(parseInt(match[2]))) {
    const tid = match[1]
    const pageStr = match[2]
    const page = isNaN(parseInt(pageStr)) ? 1 : parseInt(pageStr)
    return {
      tid, page
    }
  }

  const tidMatch = threadUrl.match(/[?&]tid=(\d+)/)
  if (tidMatch) {
    const tid = tidMatch[1]
    let page = 1
    const pageMatch = threadUrl.match(/[?&]page=(\d+)/)
    if (pageMatch) {
      const pageNum = parseInt(pageMatch[1], 10)
      page = isNaN(pageNum) ? 1 : pageNum
    }
    let authorId: string | undefined = undefined
    const authorIdMatch = threadUrl.match(/[?&]authorid=(\d+)/)
    if (authorIdMatch) {
      authorId = authorIdMatch[1]
    }
    return { tid, page, authorId }
  }
  return null
}