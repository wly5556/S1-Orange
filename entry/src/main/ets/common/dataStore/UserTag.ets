import { readJson, writeJson } from './JsonPersist'

const bucketName = 'userTags'
const tagsKey = 'all'
const historyInputKey = 'history'
const MAX_HISTORY = 10

let userTags: Record<string, string[]> = {}
let historyList: string[] = []

export function getUserTags(uid: string): string[] {
  return userTags[uid] ?? []
}

export function getUserTagsCopy(uid: string): string[] {
  return (userTags[uid] ?? []).slice()
}

export function setUserTags(uid: string, tags: string[]) {
  userTags[uid] = tags
  writeJson<Record<string, string[]>>(bucketName, tagsKey, userTags)
}

export function addUserTag(uid: string, tag: string) {
  const tags = getUserTags(uid)
  if (tags.includes(tag)) {
    return
  }
  tags.push(tag)
  setUserTags(uid, tags)
}

export function removeUserTag(uid: string, tag: string) {
  const tags = getUserTags(uid).filter(v => v !== tag)
  setUserTags(uid, tags)
}

export function getTagHistory(): string[] {
  return historyList
}

export function addTagHistory(tag: string) {
  historyList = historyList.filter(v => v !== tag)
  historyList.unshift(tag)
  if (historyList.length > MAX_HISTORY) {
    historyList = historyList.slice(0, MAX_HISTORY)
  }
  writeJson<string[]>(bucketName, historyInputKey, historyList)
}

export async function loadUserTags() {
  const all = await readJson<Record<string, string[]>>(bucketName, tagsKey)
  if (all) {
    userTags = all
  }
  const history = await readJson<string[]>(bucketName, historyInputKey)
  historyList = history ? history : []
}
