import { PersistMap } from './PersistMap'

export interface PostLocation {
  tid: string
  page: number
}

const locationMap: PersistMap<PostLocation> = new PersistMap<PostLocation>('postLocation', 'all')

export async function loadPostLocationData(): Promise<void> {
  await locationMap.load()
}

export function queryPostLocation(pid: string): PostLocation | undefined {
  return locationMap.get(pid)
}

export function reportPostLocation(pids: string[], tid: string, page: number): void {
  if (pids.length == 0 || tid.length == 0 || page < 1) {
    return
  }
  const uniquePids: Set<string> = new Set<string>(pids)
  uniquePids.forEach((pid: string) => locationMap.set(pid, { tid: tid, page: page }))
}
