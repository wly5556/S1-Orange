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

function normalizeBlockKeywordInfo(data: BlockKeywordInfo[]): BlockKeywordInfo[] {
  const result: BlockKeywordInfo[] = []
  data.forEach(item => {
    if (typeof item.regex != 'string' || typeof item.date != 'number' || typeof item.enabled != 'boolean') {
      return
    }
    try {
      new RegExp(item.regex)
      result.push({
        regex: item.regex,
        date: item.date,
        enabled: item.enabled
      })
    } catch (e) {
    }
  })
  return result
}

function updateBlockKwInfo() {
  blockKeywordList = blockKeywordInfo.filter(v => v.enabled).map(v => new RegExp(v.regex))
  writeJson<BlockKeywordInfo[]>(bucketName, currentUid, blockKeywordInfo)
}

export function BlockKeyWordListClear(uid: string) {
  removeJson(bucketName, uid)
}

export async function ExportBlockKeyword(uid: string): Promise<BlockKeywordInfo[]> {
  const data = await readJson<BlockKeywordInfo[]>(bucketName, uid)
  if (data) {
    return normalizeBlockKeywordInfo(data)
  }
  return []
}

export async function RestoreBlockKeyword(uid: string, data: BlockKeywordInfo[]) {
  const normalized = normalizeBlockKeywordInfo(data)
  await writeJson<BlockKeywordInfo[]>(bucketName, uid, normalized)
  if (uid == currentUid) {
    blockKeywordInfo = normalized
    blockKeywordList = normalized.filter(v => v.enabled).map(v => new RegExp(v.regex))
  }
}
