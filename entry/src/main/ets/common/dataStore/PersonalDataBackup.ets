import { common } from '@kit.AbilityKit'
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit'
import BuildProfile from 'BuildProfile'
import {
  AccountAssetsSnapshot,
  AccountAssetSnapshot,
  exportAccountAssets,
  initAccountManager,
  restoreAccountAssets
} from '../account/AccountManager'
import { PreferenceManager } from '../../config/UserConfig'
import { ApplicationConfig } from '../../config/v1/default'
import { DraftItem, ExportDraft, RestoreDraft } from './DraftData'
import { ExportViewHistory, RestoreViewHistory, ViewHistoryItem } from './HistoryData'
import { BlockKeywordInfo, ExportBlockKeyword, RestoreBlockKeyword } from './BlockKeyword'

const PERSONAL_DATA_FORMAT = 's1-orange-personal-data'
const PERSONAL_DATA_FORMAT_VERSION = 1
const PERSONAL_DATA_EXTENSION = '.json'

export interface PersonalDataBundle {
  format: string
  formatVersion: number
  exportedAt: number
  appVersion: string
  config: ApplicationConfig
  accountAssets: AccountAssetsSnapshot
  histories: Record<string, ViewHistoryItem[]>
  drafts: Record<string, DraftItem[]>
  blockKeywords: Record<string, BlockKeywordInfo[]>
}

interface PersonalDataStoreSnapshot {
  config: ApplicationConfig
  accountAssets: AccountAssetsSnapshot
  histories: Record<string, ViewHistoryItem[]>
  drafts: Record<string, DraftItem[]>
  blockKeywords: Record<string, BlockKeywordInfo[]>
}

function collectConfigUids(config: ApplicationConfig): string[] {
  const uidSet: Set<string> = new Set()
  if (config.user_uid.length > 0) {
    uidSet.add(config.user_uid)
  }
  if (isObjectRecord(config.account_list)) {
    Object.keys(config.account_list).forEach(uid => {
      if (uid.length > 0) {
        uidSet.add(uid)
      }
    })
  }
  return Array.from(uidSet)
}

function isObjectRecord(value: Object | undefined): boolean {
  return value != undefined && typeof value == 'object' && !Array.isArray(value)
}

function normalizeAccountAssets(input: AccountAssetsSnapshot, uidList: string[]): AccountAssetsSnapshot {
  const uidSet: Set<string> = new Set(uidList)
  const result: AccountAssetsSnapshot = {}
  Object.keys(input).forEach(uid => {
    if (!uidSet.has(uid)) {
      return
    }
    const item = input[uid]
    if (!isObjectRecord(item)) {
      return
    }
    const normalized: AccountAssetSnapshot = {}
    if (typeof item.cookie == 'string') {
      normalized.cookie = item.cookie
    }
    if (typeof item.appToken == 'string') {
      normalized.appToken = item.appToken
    }
    if (typeof item.formhash == 'string') {
      normalized.formhash = item.formhash
    }
    if (normalized.cookie != undefined || normalized.appToken != undefined || normalized.formhash != undefined) {
      result[uid] = normalized
    }
  })
  return result
}

function normalizeViewHistoryList(data: ViewHistoryItem[] | undefined): ViewHistoryItem[] {
  if (!Array.isArray(data)) {
    return []
  }
  const result: ViewHistoryItem[] = []
  data.forEach(item => {
    if (!isObjectRecord(item)) {
      return
    }
    if (typeof item.thread_id == 'number' && typeof item.title == 'string' &&
      typeof item.pid == 'number' && typeof item.date == 'number' &&
      typeof item.reply == 'number' && typeof item.page == 'number') {
      result.push({
        thread_id: item.thread_id,
        title: item.title,
        pid: item.pid,
        date: item.date,
        reply: item.reply,
        page: item.page
      })
    }
  })
  return result
}

function normalizeDraftList(data: DraftItem[] | undefined): DraftItem[] {
  if (!Array.isArray(data)) {
    return []
  }
  const result: DraftItem[] = []
  data.forEach(item => {
    if (!isObjectRecord(item)) {
      return
    }
    const newSubjectValid = item.new_subject == null || typeof item.new_subject == 'string'
    const threadTypeValid = item.thread_type == null || typeof item.thread_type == 'number'
    if (typeof item.draft_type == 'number' && typeof item.thread_id == 'number' &&
      typeof item.forum_id == 'number' && typeof item.edit_pid == 'number' &&
      typeof item.quote_pid == 'number' && typeof item.pm_uid == 'number' &&
      typeof item.date == 'number' && typeof item.content == 'string' &&
      typeof item.thread_subject == 'string' && newSubjectValid && threadTypeValid) {
      result.push({
        draft_type: item.draft_type,
        thread_id: item.thread_id,
        forum_id: item.forum_id,
        edit_pid: item.edit_pid,
        quote_pid: item.quote_pid,
        pm_uid: item.pm_uid,
        date: item.date,
        content: item.content,
        new_subject: item.new_subject,
        thread_type: item.thread_type,
        thread_subject: item.thread_subject
      })
    }
  })
  return result
}

function normalizeBlockKeywordList(data: BlockKeywordInfo[] | undefined): BlockKeywordInfo[] {
  if (!Array.isArray(data)) {
    return []
  }
  const result: BlockKeywordInfo[] = []
  data.forEach(item => {
    if (!isObjectRecord(item)) {
      return
    }
    if (typeof item.regex != 'string' || typeof item.date != 'number' || typeof item.enabled != 'boolean') {
      return
    }
    try {
      new RegExp(item.regex)
      result.push({
        regex: item.regex,
        date: item.date,
        enabled: item.enabled
      })
    } catch (e) {
    }
  })
  return result
}

function normalizePersonalDataBundle(bundle: PersonalDataBundle): PersonalDataBundle {
  const uidList = collectConfigUids(bundle.config)
  const histories: Record<string, ViewHistoryItem[]> = {}
  const drafts: Record<string, DraftItem[]> = {}
  const blockKeywords: Record<string, BlockKeywordInfo[]> = {}
  uidList.forEach(uid => {
    histories[uid] = normalizeViewHistoryList(bundle.histories[uid])
    drafts[uid] = normalizeDraftList(bundle.drafts[uid])
    blockKeywords[uid] = normalizeBlockKeywordList(bundle.blockKeywords[uid])
  })
  return {
    format: PERSONAL_DATA_FORMAT,
    formatVersion: PERSONAL_DATA_FORMAT_VERSION,
    exportedAt: bundle.exportedAt,
    appVersion: typeof bundle.appVersion == 'string' ? bundle.appVersion : '',
    config: bundle.config,
    accountAssets: normalizeAccountAssets(bundle.accountAssets, uidList),
    histories: histories,
    drafts: drafts,
    blockKeywords: blockKeywords
  }
}

function unionUids(a: string[], b: string[]): string[] {
  const uidSet: Set<string> = new Set()
  a.forEach(uid => {
    if (uid.length > 0) {
      uidSet.add(uid)
    }
  })
  b.forEach(uid => {
    if (uid.length > 0) {
      uidSet.add(uid)
    }
  })
  return Array.from(uidSet)
}

function exportFileName(exportedAt: number): string {
  const date = new Date(exportedAt)
  const pad = (value: number): string => value.toString().padStart(2, '0')
  return `个人数据_S1Orange_${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}_${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}${PERSONAL_DATA_EXTENSION}`
}

async function writeTextFile(uri: string, text: string) {
  const file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
  try {
    await fs.write(file.fd, text)
  } finally {
    await fs.close(file.fd)
  }
}

async function createPersonalDataBundle(exportedAt: number): Promise<PersonalDataBundle> {
  const config = await PreferenceManager.snapshot()
  const uidList = collectConfigUids(config)
  const histories: Record<string, ViewHistoryItem[]> = {}
  const drafts: Record<string, DraftItem[]> = {}
  const blockKeywords: Record<string, BlockKeywordInfo[]> = {}
  for (const uid of uidList) {
    histories[uid] = await ExportViewHistory(uid)
    drafts[uid] = await ExportDraft(uid)
    blockKeywords[uid] = await ExportBlockKeyword(uid)
  }
  return {
    format: PERSONAL_DATA_FORMAT,
    formatVersion: PERSONAL_DATA_FORMAT_VERSION,
    exportedAt: exportedAt,
    appVersion: BuildProfile.VERSION_NAME,
    config: config,
    accountAssets: await exportAccountAssets(uidList),
    histories: histories,
    drafts: drafts,
    blockKeywords: blockKeywords
  }
}

async function createStoreSnapshot(config: ApplicationConfig, uidList: string[]): Promise<PersonalDataStoreSnapshot> {
  const histories: Record<string, ViewHistoryItem[]> = {}
  const drafts: Record<string, DraftItem[]> = {}
  const blockKeywords: Record<string, BlockKeywordInfo[]> = {}
  for (const uid of uidList) {
    histories[uid] = await ExportViewHistory(uid)
    drafts[uid] = await ExportDraft(uid)
    blockKeywords[uid] = await ExportBlockKeyword(uid)
  }
  return {
    config: config,
    accountAssets: await exportAccountAssets(uidList),
    histories: histories,
    drafts: drafts,
    blockKeywords: blockKeywords
  }
}

async function restoreStoreSnapshot(snapshot: PersonalDataStoreSnapshot, uidList: string[]) {
  await restoreAccountAssets(uidList, snapshot.accountAssets)
  await PreferenceManager.restore(snapshot.config)
  for (const uid of uidList) {
    await RestoreViewHistory(uid, snapshot.histories[uid] || [])
    await RestoreDraft(uid, snapshot.drafts[uid] || [])
    await RestoreBlockKeyword(uid, snapshot.blockKeywords[uid] || [])
  }
  initAccountManager()
}

export async function exportPersonalData(context: common.UIAbilityContext): Promise<string | undefined> {
  const exportedAt = Date.now()
  const filename = exportFileName(exportedAt)
  const bundle = await createPersonalDataBundle(exportedAt)
  const text = JSON.stringify(bundle)
  const documentViewPicker = new picker.DocumentViewPicker(context)
  const documentSaveOptions = new picker.DocumentSaveOptions()
  documentSaveOptions.newFileNames = [filename]
  const documentSaveResult: string[] = await documentViewPicker.save(documentSaveOptions)
  if (documentSaveResult.length == 0) {
    return undefined
  }
  const selectedUri = documentSaveResult[0]
  await writeTextFile(selectedUri, text)
  return selectedUri
}

function parsePersonalDataBundle(text: string): PersonalDataBundle {
  const bundle = JSON.parse(text) as PersonalDataBundle
  if (bundle.format != PERSONAL_DATA_FORMAT || bundle.formatVersion != PERSONAL_DATA_FORMAT_VERSION ||
    typeof bundle.exportedAt != 'number' || bundle.config == undefined || bundle.accountAssets == undefined ||
    bundle.histories == undefined || bundle.drafts == undefined || bundle.blockKeywords == undefined) {
    throw new Error('Invalid personal data bundle')
  }
  return normalizePersonalDataBundle(bundle)
}

export async function selectPersonalDataBundle(context: common.UIAbilityContext): Promise<PersonalDataBundle | undefined> {
  const documentViewPicker = new picker.DocumentViewPicker(context)
  const documentSelectOptions = new picker.DocumentSelectOptions()
  const documentSelectResult: string[] = await documentViewPicker.select(documentSelectOptions)
  if (documentSelectResult.length == 0) {
    return undefined
  }
  const selectedPath = new fileUri.FileUri(documentSelectResult[0]).path
  const text = await fs.readText(selectedPath)
  return parsePersonalDataBundle(text)
}

export async function importPersonalDataBundle(bundle: PersonalDataBundle) {
  const normalizedBundle = normalizePersonalDataBundle(bundle)
  const oldConfig = await PreferenceManager.snapshot()
  const oldUidList = collectConfigUids(oldConfig)
  const newUidList = collectConfigUids(normalizedBundle.config)
  const allUidList = unionUids(oldUidList, newUidList)
  const oldSnapshot = await createStoreSnapshot(oldConfig, allUidList)

  try {
    await restoreAccountAssets(allUidList, normalizedBundle.accountAssets)
    await PreferenceManager.restore(normalizedBundle.config)
    for (const uid of allUidList) {
      await RestoreViewHistory(uid, normalizedBundle.histories[uid] || [])
      await RestoreDraft(uid, normalizedBundle.drafts[uid] || [])
      await RestoreBlockKeyword(uid, normalizedBundle.blockKeywords[uid] || [])
    }
    initAccountManager()
  } catch (e) {
    try {
      await restoreStoreSnapshot(oldSnapshot, allUidList)
    } catch (rollbackError) {
      console.error(`Rollback personal data import failed: ${JSON.stringify(rollbackError)}`)
    }
    throw new Error(`Import personal data failed: ${JSON.stringify(e)}`)
  }
}

export function formatPersonalDataTime(time: number): string {
  const date = new Date(time)
  const pad = (value: number): string => value.toString().padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`
}
