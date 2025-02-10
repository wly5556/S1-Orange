import { relationalStore } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { WriteReplyParam } from '../../pages/NavDest/WriteReply'
import { EventListener } from '../EventListener'

export const MAX_DRAFT_ITEM = 100

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'RdbDraft.db',
  securityLevel: relationalStore.SecurityLevel.S2
}
const tableNamePrefix = 'drafts'
let dbEngine: relationalStore.RdbStore | undefined = undefined

enum COLUMN {
  id = 'id',
  date = 'date',
  thread_subject = 'thread_subject',
  content = 'content',
  new_subject = 'new_subject',
  thread_type = 'thread_type',
}

let CURR_USER = ''

function tableNameForUser(uid = CURR_USER) {
  return `${tableNamePrefix}_${uid}`
}

function createTableSQL() {
  return [`
  CREATE TABLE IF NOT EXISTS ${tableNameForUser()} (
      ${COLUMN.id} TEXT PRIMARY KEY,
      ${COLUMN.date} INTEGER,
      ${COLUMN.thread_type} INTEGER,
      ${COLUMN.content} TEXT,
      ${COLUMN.new_subject} TEXT,
      ${COLUMN.thread_subject} TEXT
      )`, `
      CREATE INDEX IF NOT EXISTS idx_${tableNameForUser()}_date ON ${tableNameForUser()}(${COLUMN.date})`]
}

let dbInitFinished: () => void = () => {
}
let dbInitPromise: Promise<void> = new Promise(resolve => dbInitFinished = resolve)

export function DraftDbInit(context: Context) {
  if (dbEngine == undefined) {
    relationalStore.getRdbStore(context, STORE_CONFIG, (err, store) => {
      if (err) {
        console.error(`Failed to get RdbStore. Code:${err.code}, message:${err.message}`)
        return
      }
      console.info('Succeeded in getting RdbStore.')
      if (store.version === 0) {
        store.version = 1
      }
      dbEngine = store
      dbInitFinished()
    })
  }
}

export async function DraftDbSetUser(username: string) {
  await dbInitPromise
  try {
    if (username != CURR_USER && username != '') {
      CURR_USER = username
      for (const sql of createTableSQL()) {
        await dbEngine?.executeSql(sql)
      }
    }
  } catch (err) {
    console.error(`Failed to create table. Code:${err.code}, message:${err.message}`);
  }
}

export interface DraftItem {
  draft_type: number,
  thread_id: number,
  forum_id: number,
  edit_pid: number,
  quote_pid: number,
  pm_uid: number,
  [COLUMN.date]: number,
  [COLUMN.content]: string,
  [COLUMN.new_subject]: string | null,
  [COLUMN.thread_type]: number | null,
  [COLUMN.thread_subject]: string,
}

async function insertDraft(draft: DraftItem) {
  if (CURR_USER == '') {
    return
  }
  await dbInitPromise
  const row: relationalStore.ValuesBucket = {
    [COLUMN.id]: GetDraftItemKey(draft),
    [COLUMN.date]: draft.date,
    [COLUMN.content]: draft.content,
    [COLUMN.new_subject]: draft.new_subject,
    [COLUMN.thread_type]: draft.thread_type,
    [COLUMN.thread_subject]: draft.thread_subject
  }
  dbEngine?.insert(tableNameForUser(), row,
    relationalStore.ConflictResolution.ON_CONFLICT_REPLACE, (err: BusinessError, rowId: number) => {
      if (err) {
        console.error(`Failed to insert data. Code:${err.code}, message:${err.message}`)
        return
      }
      DraftModifiedListener.emit()
      console.info(`Succeeded in inserting data. rowId:${rowId}`)
    })
}

export const DraftModifiedListener = new EventListener<void>()

export async function DeleteDraft(draft: DraftItem): Promise<boolean> {
  if (CURR_USER == '') {
    return false
  }
  await dbInitPromise
  try {
    const predicates = new relationalStore.RdbPredicates(tableNameForUser())
      .equalTo(COLUMN.id, GetDraftItemKey(draft))
    const effected = await dbEngine!.delete(predicates)
    if (effected > 0) {
      DraftModifiedListener.emit()
    }
    return true
  } catch (err) {
    console.warn(err)
    return false
  }
}

export function GetDraftItemKey(draft: DraftItem) {
  return `${draft.thread_id},${draft.forum_id},${draft.edit_pid},${draft.quote_pid},${draft.pm_uid},${draft.draft_type}`
}

export function RemoveDraftIfExist(pageParam: WriteReplyParam) {
  if (CURR_USER == '') {
    return
  }
  DeleteDraft(fillDraftItemKeyWithPageParam(pageParam))
}

function resultToDraftItem(resultSet: relationalStore.ResultSet): DraftItem {
  const id = resultSet.getString(resultSet.getColumnIndex(COLUMN.id))
  const parts = id.split(',')
  const thread_id = parseInt(parts[0]) || 0
  const forum_id = parseInt(parts[1]) || 0
  const edit_pid = parseInt(parts[2]) || 0
  const quote_pid = parseInt(parts[3]) || 0
  const pm_uid = parseInt(parts[4]) || 0
  const draft_type = parseInt(parts[5]) || 0
  const date = resultSet.getLong(resultSet.getColumnIndex(COLUMN.date))
  const content = resultSet.getString(resultSet.getColumnIndex(COLUMN.content))
  const subject = resultSet.getString(resultSet.getColumnIndex(COLUMN.new_subject))
  const thread_type = resultSet.getLong(resultSet.getColumnIndex(COLUMN.thread_type))
  const thread_subject = resultSet.getString(resultSet.getColumnIndex(COLUMN.thread_subject))
  return {
    thread_id: thread_id,
    draft_type: draft_type,
    forum_id: forum_id,
    edit_pid: edit_pid,
    quote_pid: quote_pid,
    pm_uid: pm_uid,
    [COLUMN.date]: date,
    [COLUMN.content]: content,
    [COLUMN.new_subject]: subject,
    [COLUMN.thread_type]: thread_type,
    [COLUMN.thread_subject]: thread_subject
  }
}

export async function QueryDraft(offset = 0, limit = 100) {
  if (CURR_USER == '') {
    return []
  }
  await dbInitPromise
  try {
    await dbEngine!.execute(`
    DELETE FROM ${tableNameForUser()} WHERE ${COLUMN.date} NOT IN (
    SELECT ${COLUMN.date} FROM ${tableNameForUser()} ORDER BY ${COLUMN.date} DESC LIMIT ${MAX_DRAFT_ITEM});`)
    const predicates = new relationalStore.RdbPredicates(tableNameForUser())
      .orderByDesc(COLUMN.date)
      .offsetAs(offset)
      .limitAs(limit)
    const resultSet = await dbEngine!.query(predicates)
    const draft: DraftItem[] = []
    while (resultSet.goToNextRow()) {
      draft.push(resultToDraftItem(resultSet))
    }
    resultSet.close()
    return draft
  } catch (err) {
    console.log(err)
  }
  return []
}

export function RecordDraft(pageParam: WriteReplyParam, content: string, thread_subject: string, new_subject?: string,
  threadType?: number) {
  if (CURR_USER == '') {
    return
  }
  insertDraft(constructDraftItem(pageParam, content, thread_subject, new_subject, threadType))
}

function fillDraftItemKeyWithPageParam(pageParam: WriteReplyParam): DraftItem {
  const tid: number = parseInt(pageParam.tid) || 0
  const fid: number = pageParam.fid ? parseInt(pageParam.fid) || 0 : 0
  const editPid: number = pageParam.editPid ? parseInt(pageParam.editPid) || 0 : 0
  const quotePid: number = pageParam.quotePid ? parseInt(pageParam.quotePid) || 0 : 0
  const pmId: number = pageParam.pmUid ? parseInt(pageParam.pmUid) || 0 : 0
  return {
    draft_type: pageParam.mode,
    thread_id: tid,
    forum_id: fid,
    edit_pid: editPid,
    quote_pid: quotePid,
    pm_uid: pmId,
    [COLUMN.date]: Date.now(),
    [COLUMN.content]: '',
    [COLUMN.thread_subject]: '',
    [COLUMN.new_subject]: null,
    [COLUMN.thread_type]: null
  }
}

function constructDraftItem(pageParam: WriteReplyParam, content: string, thread_subject: string, new_subject?: string,
  threadType?: number): DraftItem {
  const item = fillDraftItemKeyWithPageParam(pageParam)
  item.content = content
  item.thread_subject = thread_subject
  item.new_subject = new_subject || null
  item.thread_type = threadType || null
  return item
}

export async function QueryDraftItem(pageParam: WriteReplyParam) {
  const item = fillDraftItemKeyWithPageParam(pageParam)
  await dbInitPromise
  const predicates = new relationalStore.RdbPredicates(tableNameForUser())
    .equalTo(COLUMN.id, GetDraftItemKey(item))
  const resultSet = await dbEngine!.query(predicates)
  let result: DraftItem | undefined
  while (resultSet.goToNextRow()) {
    result = resultToDraftItem(resultSet)
  }
  resultSet.close()
  return result
}

export async function clearDraft(uid: string) {
  await dbInitPromise
  try {
    await dbEngine!.delete(new relationalStore.RdbPredicates(tableNameForUser(uid)).isNotNull(COLUMN.date))
  } catch (err) {
    console.error(`Clear clearDraft failed. Code:${err.code}, message:${err.message}`)
  }
}