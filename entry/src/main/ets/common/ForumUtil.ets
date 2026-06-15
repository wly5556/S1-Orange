let forumGroupNameMap: Map<string, string> = new Map()
let threadTypeNameMap: Map<string, Map<string, string>> = new Map()

export function setForumGroupNameMap(map: Map<string, string>): void {
  forumGroupNameMap = new Map(map)
}

export function setThreadTypeNameMap(map: Map<string, Map<string, string>>): void {
  map.forEach((typeMap, fid) => {
    threadTypeNameMap.set(fid, new Map(typeMap))
  })
}

export function getGroupName(fid?: string): string {
  if (!fid) {
    return ''
  }
  return forumGroupNameMap.get(fid) || ''
}

export function getThreadTypeName(fid?: string, typeid?: string): string {
  if (!fid || !typeid) {
    return ''
  }
  return threadTypeNameMap.get(fid)?.get(typeid) || ''
}
