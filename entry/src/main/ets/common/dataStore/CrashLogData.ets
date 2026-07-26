import { common } from '@kit.AbilityKit'
import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { FaultLogger } from '@kit.PerformanceAnalysisKit'

const CRASH_LOG_EXTENSION = '.txt'

export enum CrashLogMode {
  crashOnly = 0,
  full = 1
}

function formatTimestamp(ts: number): string {
  const date = new Date(ts) // 文档说是秒级，其实是毫秒级
  const pad = (value: number): string => value.toString().padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

function faultTypeLabel(type: FaultLogger.FaultType): string {
  switch (type) {
    case FaultLogger.FaultType.JS_CRASH:
      return 'JS_CRASH'
    case FaultLogger.FaultType.CPP_CRASH:
      return 'CPP_CRASH'
    case FaultLogger.FaultType.APP_FREEZE:
      return 'APP_FREEZE'
    default:
      return `FAULT_${type}`
  }
}

function formatFaultLog(info: FaultLogger.FaultLogInfo, mode: CrashLogMode): string {
  const lines: string[] = []
  lines.push(`================ ${faultTypeLabel(info.type)} ================`)
  lines.push(`time: ${formatTimestamp(info.timestamp)}`)
  lines.push(`module: ${info.module}`)
  lines.push(`reason: ${info.reason}`)
  lines.push(`pid: ${info.pid}, uid: ${info.uid}`)
  lines.push(`summary: ${info.summary}`)
  if (mode == CrashLogMode.full) {
    lines.push('---------------- full log ----------------')
    lines.push(info.fullLog)
  }
  lines.push('')
  return lines.join('\n')
}

async function queryFaultLogsByType(type: FaultLogger.FaultType): Promise<FaultLogger.FaultLogInfo[]> {
  try {
    return await FaultLogger.query(type)
  } catch (e) {
    console.error(`query fault log (${faultTypeLabel(type)}) failed: ${JSON.stringify(e)}`)
    return []
  }
}

export async function collectCrashLogs(mode: CrashLogMode = CrashLogMode.crashOnly): Promise<string> {
  const jsLogs = await queryFaultLogsByType(FaultLogger.FaultType.JS_CRASH)
  const cppLogs = await queryFaultLogsByType(FaultLogger.FaultType.CPP_CRASH)
  const all: FaultLogger.FaultLogInfo[] = []
  all.push(...jsLogs)
  all.push(...cppLogs)
  all.sort((a, b) => b.timestamp - a.timestamp)

  const header: string[] = []
  header.push(`S1-Orange 崩溃日志导出`)
  header.push(`导出时间: ${new Date().toLocaleString()}`)
  header.push(`JS_CRASH: ${jsLogs.length} 条, CPP_CRASH: ${cppLogs.length} 条`)
  header.push('')

  if (all.length == 0) {
    header.push('（暂无崩溃日志）')
    return header.join('\n')
  }

  const body = all.map(info => formatFaultLog(info, mode)).join('\n')
  return header.join('\n') + body
}

function exportFileName(exportedAt: number): string {
  const date = new Date(exportedAt)
  const pad = (value: number): string => value.toString().padStart(2, '0')
  return `崩溃日志_S1Orange_${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}_` +
    `${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}${CRASH_LOG_EXTENSION}`
}

async function writeTextFile(uri: string, text: string) {
  const file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
  try {
    await fs.write(file.fd, text)
  } finally {
    await fs.close(file.fd)
  }
}

export async function exportCrashLogs(context: common.UIAbilityContext, mode: CrashLogMode = CrashLogMode.crashOnly): Promise<string | undefined> {
  const text = await collectCrashLogs(mode)
  const filename = exportFileName(Date.now())
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
