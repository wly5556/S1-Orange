import { readJson, writeJson } from './JsonPersist'

const bucketName = 'smilies'
const key = 'frequent_list'
const MAX_COUNT = 30

export interface FrequentSmily {
  text: string
  filename: string
  path: string
}

let frequentList: FrequentSmily[] = []

export function getFrequentSmilyList(): FrequentSmily[] {
  return frequentList
}

export async function loadFrequentSmily() {
  const data = await readJson<FrequentSmily[]>(bucketName, key)
  frequentList = data ? data : []
}

export function recordFrequentSmily(smily: FrequentSmily) {
  frequentList = frequentList.filter(v => v.text != smily.text)
  frequentList.unshift(smily)
  if (frequentList.length > MAX_COUNT) {
    frequentList = frequentList.slice(0, MAX_COUNT)
  }
  writeJson<FrequentSmily[]>(bucketName, key, frequentList)
}
