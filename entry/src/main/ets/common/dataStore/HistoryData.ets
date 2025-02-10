import { relationalStore } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'RdbViewHistory.db',
  securityLevel: relationalStore.SecurityLevel.S2
}
const tableNamePrefix = 'ViewHistory'
let dbEngine: relationalStore.RdbStore | undefined = undefined
const MAX_HISTORY_ITEM = 2000


enum COLUMN {
  thread_id = 'thread_id',
  pid = 'pid',
  page = 'page',
  date = 'date',
  reply = 'reply',
  title = 'title'
}

let CURR_USER = '' // 未登录时

function tableNameForUser(uid = CURR_USER) {
  return `${tableNamePrefix}_${uid}`
}

function createTableSQL() {
  return [`
  CREATE TABLE IF NOT EXISTS ${tableNameForUser()} (
      ${COLUMN.thread_id} INTEGER PRIMARY KEY,
      ${COLUMN.title} TEXT,
      ${COLUMN.pid} INTEGER,
      ${COLUMN.page} INTEGER,
      ${COLUMN.date} INTEGER,
      ${COLUMN.reply} INTEGER
  )`, `
  CREATE INDEX IF NOT EXISTS idx_${tableNameForUser()}_date ON ${tableNameForUser()}(${COLUMN.date})`]
}

let dbInitFinished: () => void = () => {
}
let dbInitPromise: Promise<void> = new Promise(resolve => dbInitFinished = resolve)

export function HistoryDbInit(context: Context) {
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

export async function HistoryDbSetUser(uid: string = '') {
  await dbInitPromise
  CURR_USER = uid
  try {
    for (const sql of createTableSQL()) {
      await dbEngine?.executeSql(sql)
    }
  } catch (err) {
    console.error(`Failed to create table. Code:${err.code}, message:${err.message}`);
  }
}

export interface ViewHistoryItem {
  [COLUMN.thread_id]: number,
  [COLUMN.title]: string,
  [COLUMN.pid]: number,
  [COLUMN.date]: number,
  [COLUMN.reply]: number,
  [COLUMN.page]: number
}

async function insertViewHistory(history: ViewHistoryItem) {
  await dbInitPromise
  const row: relationalStore.ValuesBucket = {
    [COLUMN.thread_id]: history.thread_id,
    [COLUMN.title]: history.title,
    [COLUMN.pid]: history.pid,
    [COLUMN.date]: history.date,
    [COLUMN.reply]: history.reply,
    [COLUMN.page]: history.page
  }
  dbEngine?.insert(tableNameForUser(), row,
    relationalStore.ConflictResolution.ON_CONFLICT_REPLACE, (err: BusinessError, rowId: number) => {
      if (err) {
        console.error(`Failed to insert data. Code:${err.code}, message:${err.message}`);
        return;
      }
      console.info(`Succeeded in inserting data. rowId:${rowId}`);
    })
}

function resultSetToViewHistory(resultSet: relationalStore.ResultSet) {
  const thread_id = resultSet.getLong(resultSet.getColumnIndex(COLUMN.thread_id))
  const title = resultSet.getString(resultSet.getColumnIndex(COLUMN.title))
  const pid = resultSet.getLong(resultSet.getColumnIndex(COLUMN.pid))
  const date = resultSet.getLong(resultSet.getColumnIndex(COLUMN.date))
  const reply = resultSet.getLong(resultSet.getColumnIndex(COLUMN.reply))
  const page = resultSet.getLong(resultSet.getColumnIndex(COLUMN.page))
  const history: ViewHistoryItem = {
    thread_id: thread_id,
    title: title,
    pid: pid,
    date: date,
    reply: reply,
    page: page
  }
  return history
}

export async function QuerySingleViewHistory(thread_id: string) {
  await dbInitPromise
  const predicates = new relationalStore.RdbPredicates(tableNameForUser())
  predicates.equalTo(COLUMN.thread_id, thread_id)
  const resultSet = await dbEngine!.query(predicates)
  try {
    while (resultSet.goToNextRow()) {
      const history = resultSetToViewHistory(resultSet)
      resultSet.close()
      return history
    }
  } catch (err) {
    resultSet.close()
    console.log(err)
  }
  return undefined
}

export async function QueryViewHistory(offset = 0, limit = 100) {
  await dbInitPromise
  try {
    await dbEngine!.executeSql(`
    DELETE FROM ${tableNameForUser()} WHERE ${COLUMN.thread_id} NOT IN (
    SELECT ${COLUMN.thread_id} FROM ${tableNameForUser()} ORDER BY ${COLUMN.date} DESC LIMIT ${MAX_HISTORY_ITEM});`)
    const predicates = new relationalStore.RdbPredicates(tableNameForUser())
      .orderByDesc(COLUMN.date)
      .offsetAs(offset)
      .limitAs(limit)
    const resultSet =
      await dbEngine!.query(predicates,
        [COLUMN.thread_id, COLUMN.title, COLUMN.pid, COLUMN.date, COLUMN.reply, COLUMN.page])
    const history: ViewHistoryItem[] = []
    while (resultSet.goToNextRow()) {
      history.push(resultSetToViewHistory(resultSet))
    }
    resultSet.close()
    return history
  } catch (err) {
    console.log(err)
  }
  return []
}

export type ThreadReplyHistoryItem = Record<string, number>

export async function QueryThreadReplyCount(thread_id: number[]) {
  await dbInitPromise
  let predicates = new relationalStore.RdbPredicates(tableNameForUser())
  predicates.in(COLUMN.thread_id, thread_id)
  const resultSet = await dbEngine!.query(predicates, [COLUMN.thread_id, COLUMN.reply])
  const replyItems: ThreadReplyHistoryItem[] = []
  while (resultSet.goToNextRow()) {
    const thread_id = resultSet.getString(resultSet.getColumnIndex(COLUMN.thread_id))
    const reply = resultSet.getLong(resultSet.getColumnIndex(COLUMN.reply))
    replyItems[thread_id] = reply
  }
  resultSet.close()
  return replyItems
}

export async function clearThreadViewHistory(uid: string) {
  await dbInitPromise
  try {
    await dbEngine!.delete(new relationalStore.RdbPredicates(tableNameForUser(uid)).isNotNull(COLUMN.date))
  } catch (err) {
    console.error(`Clear ThreadViewHistorye failed. Code:${err.code}, message:${err.message}`)
  }
}

const historyToRecord: Map<number, ViewHistoryItem> = new Map()

export function RecordThreadViewHistory(thread_id: string, title: string, post_id: string, date: number,
  reply_count: string, page: number) {
  const tid = parseInt(thread_id)
  const pid = parseInt(post_id)
  const rp_count = parseInt(reply_count)
  if (isNaN(tid) || isNaN(pid) || isNaN(rp_count)) {
    return
  }
  const data: ViewHistoryItem = {
    thread_id: tid,
    title: title,
    pid: pid,
    date: date,
    reply: rp_count,
    page: page
  }
  historyToRecord.set(tid, data)
  return data
}

export function FlushThreadViewHistory(thread_id: string) {
  const tid = parseInt(thread_id)
  if (isNaN(tid)) {
    return
  }
  const data = historyToRecord.get(tid)
  if (data) {
    insertViewHistory(data)
    historyToRecord.delete(tid)
  }
}