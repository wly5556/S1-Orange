import { relationalStore } from '@kit.ArkData';
import { URL } from '../../api/base';

const CACHE_DB_FILE = 'ApiCache.db'
const CACHE_STORE_CONFIG: relationalStore.StoreConfig = {
  name: CACHE_DB_FILE,
  securityLevel: relationalStore.SecurityLevel.S2
}

const GLOBAL_TABLE_NAME = 'ApiCacheGlobal'
const FORUM_GROUP_CACHE_KEY = URL.BASE + URL.FORUM_GROUP
export const CLEAN_UP_CACHE_THRESHOLD = 1000

enum COLUMN {
  key = 'key',
  lru = 'lru',
  data = 'data'
}

let currentUid: string = ''
let cacheDb: relationalStore.RdbStore | undefined = undefined

let cacheDbInitFinished: () => void = () => {}
let cacheDbInitPromise: Promise<void> = new Promise(resolve => cacheDbInitFinished = resolve)

function userTableName(uid = currentUid) {
  return `ApiCache_${uid}`
}

function createUserTableSQL(name = userTableName()) {
  return `
  CREATE TABLE IF NOT EXISTS ${name} (
    ${COLUMN.key} TEXT PRIMARY KEY,
    ${COLUMN.lru} INTEGER,
    ${COLUMN.data} TEXT
  ) WITHOUT ROWID;
  CREATE INDEX IF NOT EXISTS idx_${name}_lru
  ON ${name}(${COLUMN.lru});`
}

let storageDatabase: string = ''

export function CacheDbInit(context: Context) {
  if (!cacheDb) {
    storageDatabase = context.databaseDir
    relationalStore.getRdbStore(context, CACHE_STORE_CONFIG, (err, store) => {
      if (err) {
        console.error(`Failed to init cache DB. Code:${err.code}, message:${err.message}`)
        return
      }
      try {
        store.executeSync(createUserTableSQL(GLOBAL_TABLE_NAME))
      } catch (e) {
        console.error('Create global table failed:', e)
      }
      cacheDb = store
      cacheDbInitFinished()
    })
  }
}

export async function CacheDbSetUser(uid: string = 'default') {
  await cacheDbInitPromise
  currentUid = uid

  try {
    cacheDb?.executeSync(createUserTableSQL())
  } catch (err) {
    console.error(`Create user table failed. Code:${err.code}, message:${err.message}`)
  }
}

export async function putCache(key: string, data: Object) {
  await cacheDbInitPromise

  if (key === FORUM_GROUP_CACHE_KEY) {
    const row: relationalStore.ValuesBucket = {
      [COLUMN.key]: FORUM_GROUP_CACHE_KEY,
      [COLUMN.lru]: Date.now(),
      [COLUMN.data]: JSON.stringify(data)
    }
    cacheDb?.beginTransaction()
    cacheDb?.insert(GLOBAL_TABLE_NAME, row,
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
    cacheDb?.commit()
    return
  }

  const row: relationalStore.ValuesBucket = {
    [COLUMN.key]: key,
    [COLUMN.lru]: Date.now(),
    [COLUMN.data]: JSON.stringify(data)
  }
  cacheDb?.beginTransaction()
  cacheDb?.insert(userTableName(), row,
    relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  cacheDb?.commit()
}

export async function getCache(key: string): Promise<Object> {
  await cacheDbInitPromise

  if (key === FORUM_GROUP_CACHE_KEY) {
    const predicates = new relationalStore.RdbPredicates(GLOBAL_TABLE_NAME)
      .equalTo(COLUMN.key, FORUM_GROUP_CACHE_KEY)

    const result = await cacheDb!.query(predicates, [COLUMN.data])
    if (result.rowCount === 0) return Promise.reject()

    result.goToFirstRow()
    const data = JSON.parse(result.getString(result.getColumnIndex(COLUMN.data))) as Object
    result.close()
    return data
  }

  const predicates = new relationalStore.RdbPredicates(userTableName())
    .equalTo(COLUMN.key, key)

  const result = await cacheDb!.query(predicates, [COLUMN.data])
  if (result.rowCount === 0) return Promise.reject()

  result.goToFirstRow()
  const data = JSON.parse(result.getString(result.getColumnIndex(COLUMN.data))) as Object
  result.close()
  return data
}

export async function clearApiCache(uid?: string) {
  await cacheDbInitPromise
  try {
    await cacheDb!.delete(new relationalStore.RdbPredicates(userTableName(uid)).isNotNull(COLUMN.key))
  } catch (err) {
    console.error(`Clear cache failed. Code:${err.code}, message:${err.message}`)
  }
}

export async function ApiCacheSetUser(uid = '') {
  if (currentUid === uid) return
  await CacheDbSetUser(uid)
  try {
    const count = await getCacheCount()
    if (count > CLEAN_UP_CACHE_THRESHOLD) {
      const retainCount = Math.floor(CLEAN_UP_CACHE_THRESHOLD * 0.75)
      await cacheDb!.executeSql(
        `DELETE FROM ${userTableName()} WHERE ${COLUMN.key} NOT IN (` +
          `SELECT ${COLUMN.key} FROM ${userTableName()} ` +
          `ORDER BY ${COLUMN.lru} DESC LIMIT ${retainCount})`
      )
    }
  } catch (err) {
    console.error('Cache cleanup failed:', err)
  }
}

async function getCacheCount(): Promise<number> {
  const result = await cacheDb!.querySql(`SELECT COUNT(*) as count FROM ${userTableName()}`)
  let count = 0
  if (result.rowCount > 0) {
    result.goToFirstRow()
    count = result.getLong(result.getColumnIndex('count'))
  }
  result.close()
  return count
}

export interface ApiCacheState {
  count: number
}

export async function getApiCacheState(): Promise<ApiCacheState> {
  return {
    count: await getCacheCount()
  }
}