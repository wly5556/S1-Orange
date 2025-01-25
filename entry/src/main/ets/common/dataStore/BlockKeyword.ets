import { readJson, removeJson, writeJson } from './JsonPersist'

const defaultUser = ''
const bucketName = 'blockKeywordList'
let currentUid: string = defaultUser

export let blockKeywordList: RegExp[] = []

export let blockKeywordInfo: BlockKeywordInfo[] = []

export interface BlockKeywordInfo {
  regex: string
  date: number
  enabled: boolean
}

export async function BlockKeywordListSetUser(uid: string = defaultUser) {
  currentUid = uid
  const data = await readJson<BlockKeywordInfo[]>(bucketName, uid)
  if (data) {
    blockKeywordInfo = data
    blockKeywordList = data.map(v => new RegExp(v.regex))
  } else {
    blockKeywordList = []
    blockKeywordInfo = []
  }
}

export function BlockKeyword(regex: string) {
  blockKeywordInfo.push({
    regex: regex,
    date: Date.now(),
    enabled: true
  })
  updateBlockKwInfo()
  return blockKeywordInfo
}

export function UnblockKeyword(itemDate: number) {
  blockKeywordInfo = blockKeywordInfo.filter(v => v.date != itemDate)
  updateBlockKwInfo()
  return blockKeywordInfo
}

export function ToggleEnableBlockKeyword(itemDate: number, isOn: boolean) {
  if (isOn) {
    blockKeywordInfo.forEach(v => {
      if (v.date == itemDate) {
        v.enabled = true
      }
    })
  } else {
    blockKeywordInfo.forEach(v => {
      if (v.date == itemDate) {
        v.enabled = false
      }
    })
  }
  updateBlockKwInfo()
}

function updateBlockKwInfo() {
  blockKeywordList = blockKeywordInfo.filter(v => v.enabled).map(v => new RegExp(v.regex))
  writeJson<BlockKeywordInfo[]>(bucketName, currentUid, blockKeywordInfo)
}

export function BlockKeyWordListClear(uid: string) {
  removeJson(bucketName, uid)
}