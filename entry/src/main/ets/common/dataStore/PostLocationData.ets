import { readJson, writeJson } from './JsonPersist'

export interface PostLocation {
  tid: string
  page: number
}

const bucketName = 'postLocation'
const persistKey = 'all'
const MAX_POST_LOCATION = 400

let postLocations: Map<string, PostLocation> = new Map
let dataDirty: boolean = false

export async function loadPostLocationData() {
  const data = await readJson<Record<string, PostLocation>>(bucketName, persistKey)
  if (data) {
    const map: Map<string, PostLocation> = new Map
    Object.keys(data).forEach(pid => map.set(pid, data[pid]))
    postLocations = map
  }
}

export function queryPostLocation(pid: string): PostLocation | undefined {
  return postLocations.get(pid)
}

export function reportPostLocation(pids: string[], tid: string, page: number) {
  if (pids.length == 0 || tid.length == 0 || page < 1) {
    return
  }
  const uniquePids: Set<string> = new Set<string>(pids)
  let newCount = 0
  uniquePids.forEach((pid: string) => {
    if (!postLocations.has(pid)) {
      newCount += 1
    }
  })
  const overflow = postLocations.size + newCount - MAX_POST_LOCATION
  if (overflow > 0) {
    Array.from(postLocations.keys()).slice(0, overflow)
      .forEach((pid: string) => postLocations.delete(pid))
  }
  uniquePids.forEach((pid: string) => {
    postLocations.set(pid, { tid: tid, page: page })
  })
  dataDirty = true
}

export function flushPostLocationData() {
  if (!dataDirty) {
    return
  }
  dataDirty = false
  const record: Record<string, PostLocation> = {}
  postLocations.forEach((location: PostLocation, pid: string) => {
    record[pid] = location
  })
  writeJson<Record<string, PostLocation>>(bucketName, persistKey, record)
}
