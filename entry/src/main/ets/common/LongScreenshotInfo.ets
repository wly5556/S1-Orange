export interface LongScreenshotThreadInfo {
  tid: string
  threadDatelineTs: number
  replyCount: number
}

let shotTid: string = ''
let shotThreadDatelineTs: number = 0
let shotReplyCount: number = 0

export function setLongScreenshotThreadInfo(tid: string, threadDatelineTs: number, replyCount: number): void {
  shotTid = tid
  shotThreadDatelineTs = threadDatelineTs
  shotReplyCount = replyCount
}

export function getLongScreenshotThreadInfo(matchedTid: string): LongScreenshotThreadInfo | undefined {
  if (matchedTid.length == 0 || shotTid != matchedTid) {
    return undefined
  }
  return {
    tid: shotTid,
    threadDatelineTs: shotThreadDatelineTs,
    replyCount: shotReplyCount
  }
}