import { URL } from '../../api/base'
import request from '../../api/request'
import wrapper from '../../api/wrapper'
import { FavList } from '../../api/model/favlist'
import { readJson, writeJson } from './JsonPersist'

const bucketName = 'favoriteList'
const PAGE_REQUEST_INTERVAL = 500

export interface FavoriteItem {
  favid: string
  id: string
  title: string
  replies: string
}

export interface FavoriteCacheData {
  fetchAt: number
  items: FavoriteItem[]
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>(resolve => {
    setTimeout(() => resolve(), ms)
  })
}

export async function LoadFavoriteCache(uid: string): Promise<FavoriteCacheData | null> {
  return readJson<FavoriteCacheData>(bucketName, uid)
}

async function SaveFavoriteCache(uid: string, data: FavoriteCacheData) {
  await writeJson<FavoriteCacheData>(bucketName, uid, data)
}

export interface FavoriteSyncResult {
  added: number
  removed: number
  fetchAt: number
  items: FavoriteItem[]
}

function mergeFavoriteItems(localItems: FavoriteItem[], remoteItems: FavoriteItem[], page: number): FavoriteItem[] {
  if (localItems.length == 0) {
    return remoteItems
  }
  const localIndex: Map<string, number> = new Map()
  localItems.forEach((item, index) => localIndex.set(item.favid, index))
  const remoteIds: Set<string> = new Set()
  remoteItems.forEach(item => remoteIds.add(item.favid))

  const anchors: number[] = []
  let previousLocalIndex = -1
  for (let i = 0; i < remoteItems.length; i++) {
    const index = localIndex.get(remoteItems[i].favid) ?? -1
    if (index < 0) {
      continue
    }
    if (index <= previousLocalIndex) {
      return localItems
    }
    previousLocalIndex = index
    anchors.push(i)
  }
  if (anchors.length == 0) {
    return page > 1 ? localItems.concat(remoteItems) : remoteItems.concat(localItems)
  }

  const rangeStart = localIndex.get(remoteItems[anchors[0]].favid) ?? -1
  const rangeEnd = localIndex.get(remoteItems[anchors[anchors.length - 1]].favid) ?? -1

  const headRun: FavoriteItem[] = remoteItems.slice(0, anchors[0])
  const runsAfterAnchor: Map<string, FavoriteItem[]> = new Map()
  for (let a = 0; a < anchors.length; a++) {
    const from = anchors[a] + 1
    const to = a + 1 < anchors.length ? anchors[a + 1] : remoteItems.length
    if (to > from) {
      runsAfterAnchor.set(remoteItems[anchors[a]].favid, remoteItems.slice(from, to))
    }
  }

  const items: FavoriteItem[] = []
  for (let i = 0; i < localItems.length; i++) {
    if (i == rangeStart) {
      headRun.forEach(item => items.push(item))
    }
    const item = localItems[i]
    if (i > rangeStart && i < rangeEnd && !remoteIds.has(item.favid)) {
      continue
    }
    items.push(item)
    runsAfterAnchor.get(item.favid)?.forEach(runItem => items.push(runItem))
  }
  return items
}

/**
 * 增量更新：把网络拉取到的一页收藏按条目（favid）合入本地列表，返回合并后的列表。
 * 只在已经存在完整缓存时才生效——本地缓存只能由整页拉取创建，这样 fetchAt 永远代表"整体拉取过"，
 * 增量更新既不会写出半份缓存，也不会把拉取时间抹掉导致下次进入又重新拉取。
 */
export async function MergeFavoriteCache(uid: string, page: number,
  remoteItems: FavoriteItem[]): Promise<FavoriteItem[] | null> {
  const cache = await LoadFavoriteCache(uid)
  if (cache == null) {
    return null
  }
  const items = mergeFavoriteItems(cache.items, remoteItems, page)
  await SaveFavoriteCache(uid, {
    fetchAt: cache.fetchAt,
    items: items
  })
  return items
}

export async function RemoveFavoriteItem(uid: string, favid: string) {
  const cache = await LoadFavoriteCache(uid)
  if (cache == null) {
    return
  }
  await SaveFavoriteCache(uid, {
    fetchAt: cache.fetchAt,
    items: cache.items.filter(item => item.favid != favid)
  })
}

export async function SyncFavoriteList(uid: string,
  onPageLoaded: (page: number, totalPage: number) => void): Promise<FavoriteSyncResult> {
  const localItems = (await LoadFavoriteCache(uid))?.items ?? []
  const items: FavoriteItem[] = []
  let page = 1
  let totalPage = 1
  let validResponse = false
  while (page <= totalPage) {
    if (page > 1) {
      await sleep(PAGE_REQUEST_INTERVAL)
    }
    const resp = await new request<wrapper<FavList>>(URL.FAVLIST)
      .param('page', page.toString())
      .get()
    const perpage = parseInt(resp.Variables.perpage ?? '')
    const count = parseInt(resp.Variables.count ?? '')
    if (perpage > 0 && !isNaN(count)) {
      validResponse = true
      totalPage = Math.max(1, Math.ceil(count / perpage))
    }
    const list = resp.Variables.list
    if (list == null || list.length == 0) {
      break
    }
    list.forEach(fav => items.push({
      favid: fav.favid,
      id: fav.id,
      title: fav.title,
      replies: fav.replies
    }))
    onPageLoaded(page, totalPage)
    page += 1
  }
  if (!validResponse) {
    throw new Error('invalid favorite list response')
  }
  const data: FavoriteCacheData = {
    fetchAt: Date.now(),
    items: items
  }
  await SaveFavoriteCache(uid, data)
  const localIds: Set<string> = new Set()
  localItems.forEach(item => localIds.add(item.favid))
  const remoteIds: Set<string> = new Set()
  items.forEach(item => remoteIds.add(item.favid))
  return {
    added: items.filter(item => !localIds.has(item.favid)).length,
    removed: localItems.filter(item => !remoteIds.has(item.favid)).length,
    fetchAt: data.fetchAt,
    items: items
  }
}
