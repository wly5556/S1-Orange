import { relationalStore } from '@kit.ArkData';

const CACHE_DB_FILE = 'SmilyImageCache.db'
const CACHE_STORE_CONFIG: relationalStore.StoreConfig = {
  name: CACHE_DB_FILE,
  securityLevel: relationalStore.SecurityLevel.S1
}

const TABLE_NAME = 'SmilyImageCache'

enum COLUMN {
  key = 'key',
  type = 'type',
  data = 'data'
}

let cacheDb: relationalStore.RdbStore | undefined = undefined

let cacheDbInitFinished: () => void = () => {
}
let cacheDbInitPromise: Promise<void> = new Promise(resolve => cacheDbInitFinished = resolve)

export enum SmilyImageType {
  PNG,
  GIF
}

function createTableSQL() {
  return [`
    CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
      ${COLUMN.key} TEXT PRIMARY KEY,
      ${COLUMN.type} INTEGER,
      ${COLUMN.data} BLOB
    ) WITHOUT ROWID
  `]
}

export interface SmilyImageCacheRow {
  key: string
  type: number
  data: Uint8Array
}

export function SmilyImageCacheInit(context: Context) {
  if (!cacheDb) {
    relationalStore.getRdbStore(context, CACHE_STORE_CONFIG, async (err, store) => {
      if (err) {
        console.error(`Failed to init SmilyImageCache DB. Code:${err.code}, message:${err.message}`)
        return
      }
      try {
        for (const sql of createTableSQL()) {
          await store.executeSql(sql)
        }
      } catch (e) {
        console.error('Create SmilyImageCache table failed:', e)
      }
      cacheDb = store
      cacheDbInitFinished()
    })
  }
}

export async function putSmilyImageCache(row: SmilyImageCacheRow) {
  await cacheDbInitPromise
  const values: relationalStore.ValuesBucket = {
    [COLUMN.key]: row.key,
    [COLUMN.type]: row.type,
    [COLUMN.data]: row.data
  }
  cacheDb?.beginTransaction()
  cacheDb?.insert(TABLE_NAME, values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
  cacheDb?.commit()
}

export async function getSmilyImageCache(key: string): Promise<SmilyImageCacheRow | undefined> {
  await cacheDbInitPromise
  const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
    .equalTo(COLUMN.key, key)
  const result = await cacheDb!.query(predicates, [COLUMN.key, COLUMN.type, COLUMN.data])
  if (result.rowCount === 0) {
    return undefined
  }
  result.goToFirstRow()
  const row: SmilyImageCacheRow = {
    key: result.getString(result.getColumnIndex(COLUMN.key)),
    type: result.getLong(result.getColumnIndex(COLUMN.type)),
    data: result.getBlob(result.getColumnIndex(COLUMN.data))
  }
  result.close()
  return row
}

export async function clearSmilyImageCache() {
  await cacheDbInitPromise
  try {
    await cacheDb!.delete(new relationalStore.RdbPredicates(TABLE_NAME).isNotNull(COLUMN.key))
  } catch (err) {
    console.error(`Clear SmilyImageCache failed. Code:${err.code}, message:${err.message}`)
  }
}