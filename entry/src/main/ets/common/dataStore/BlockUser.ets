import { URL } from '../../api/base'
import request from '../../api/request'
import { pagePattern } from '../../pages/NavDest/SearchPage'
import { BlockKeyWordListClear, BlockKeywordListSetUser } from './BlockKeyword'
import { readJson, removeJson, writeJson } from './JsonPersist'

export const BLOCK_USER_LIST_STATE = 'BlockListState'

export let blockUserList: BlockUserList = {}

export let blockUserListSyncAt: number

export interface BlockUserInfo {
  uid: string
  username: string
  date: number
}

export type BlockUserList = Record<string, BlockUserInfo>

const defaultUser = ''
const bucketName = 'blockUserList'
let currentUid: string = defaultUser


interface BlockListPersist {
  list: BlockUserList,
  remoteSyncAt: number
}

export async function BlockListSetUser(uid: string = defaultUser) {
  await BlockUserListSetUser(uid)
  await BlockKeywordListSetUser(uid)
}

export async function clearBlockList(uid: string) {
  BlockUserListClear(uid)
  BlockKeyWordListClear(uid)
}

function BlockUserListClear(uid: string) {
  removeJson(bucketName, uid)
}

export async function BlockUserListSetUser(uid: string = defaultUser) {
  currentUid = uid
  const data = await readBlockList(uid)
  if (data) {
    blockUserList = data.list
    blockUserListSyncAt = data.remoteSyncAt
  } else {
    blockUserList = {}
    await SyncBlockUserListWithWeb()
  }
  refreshAppStorage()
}

export async function SyncBlockUserListWithWeb() {
  if (currentUid != defaultUser) {
    blockUserListSyncAt = Date.now()
    let remoteList: UidUsername[] = []
    try {
      let page: number = 1
      let totalPage: number = 1
      while (page <= totalPage) {
        const remoteBlockList = extractBlockListFromWeb(await new request<string>(URL.BLOCKLIST_WEB, URL.WEB_BASE)
          .param('page', String(page))
          .formHash()
          .toText()
          .get())
        remoteList = remoteList?.concat(remoteBlockList.list)
        totalPage = remoteBlockList.totalPage
        page += 1
      }
    } catch (e) {
    }
    if (remoteList.length > 0) {
      const uidSet: Set<string> = new Set
      remoteList.forEach(u => {
        uidSet.add(u.uid)
        if (!blockUserList[u.uid]) {
          blockUserLocal(u.uid, u.username)
        }
      })
      Object.keys(blockUserList).forEach(uid => {
        if (!uidSet.has(uid)) {
          unblockUserLocal(uid)
        }
      })
    }
    saveBlockList()
  }
}

function refreshAppStorage() {
  const uidSet: Set<string> = new Set
  Object.keys(blockUserList).forEach(u => uidSet.add(u))
  AppStorage.setOrCreate(BLOCK_USER_LIST_STATE, uidSet)
}

export async function BlockUser(uid: string, username: string) {
  blockUserLocal(uid, username)
  if (currentUid != defaultUser) {
    await new request<string>(URL.BLOCK_ACTION, URL.WEB_BASE)
      .formHash()
      .toText()
      .post({
        blacklistsubmit_btn: true,
        blacklistsubmit: true,
        username: username
      })
    await SyncBlockUserListWithWeb()
  }
}

export async function UnblockUser(uid: string) {
  unblockUserLocal(uid)
  if (currentUid != defaultUser) {
    await new request<string>(URL.BLOCK_ACTION, URL.WEB_BASE)
      .param('subop', 'delete')
      .param('uid', uid)
      .get()
    await SyncBlockUserListWithWeb()
  }
}

async function blockUserLocal(uid: string, username: string) {
  blockUserList[uid] = {
    uid: uid,
    username: username,
    date: Date.now()
  }
  refreshAppStorage()
  saveBlockList()
}

async function unblockUserLocal(uid: string) {
  const list: BlockUserList = {}
  Object.keys(blockUserList).filter(k => k != uid).forEach(k => list[k] = blockUserList[k])
  blockUserList = list
  refreshAppStorage()
  saveBlockList()
}

function saveBlockList() {
  writeJson<BlockListPersist>(bucketName, currentUid, {
    list: blockUserList,
    remoteSyncAt: blockUserListSyncAt
  })
}

async function readBlockList(uid: string) {
  return readJson<BlockListPersist>(bucketName, uid)
}

interface UidUsername {
  uid: string
  username: string
}

interface BlockListFromWeb {
  list: UidUsername[]
  totalPage: number
}

function extractBlockListFromWeb(html: string): BlockListFromWeb {
  const userPattern = /<li id="friend_.*?>([\s\S]*?)<\/li>/g
  const uidNamePattern = /<a href="space-uid-(\d+).html">(.*?)<\/a>/
  let match: RegExpExecArray | null = null
  const results: UidUsername[] = []
  const page = pagePattern.exec(html)

  while ((match = userPattern.exec(html)) !== null) {
    const htmlResult = match[0]
    const uidNameMatch = htmlResult.match(uidNamePattern)
    if (uidNameMatch) {
      const uid = uidNameMatch[1]
      const username = uidNameMatch[2]
      results.push({ uid, username })
    }
  }

  return {
    totalPage: page ? parseInt(page[1]) : 1,
    list: results
  }
}