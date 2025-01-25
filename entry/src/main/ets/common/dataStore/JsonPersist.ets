import { fileIo as fs } from '@kit.CoreFileKit'

export let storeBaseDir: string

export async function initJsonStorage(filesDir: string) {
  storeBaseDir = filesDir
}

function getStoreFilePath(bucketName: string, key: string): string {
  return `${storeBaseDir}/${bucketName}/${key}.json`
}

export async function readJson<T>(bucketName: string, key: string): Promise<T | null> {
  const filePath = getStoreFilePath(bucketName, key)
  try {
    const text = await fs.readText(filePath)
    return JSON.parse(text) as T
  } catch (e) {
    return null
  }
}

export async function writeJson<T>(bucketName: string, key: string, data: T) {
  if (!fs.accessSync(`${storeBaseDir}/${bucketName}`)) {
    fs.mkdir(`${storeBaseDir}/${bucketName}`)
  }
  const filePath = getStoreFilePath(bucketName, key)
  const file = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC | fs.OpenMode.CREATE)
  await fs.write(file.fd, JSON.stringify(data))
  await fs.close(file.fd)
}

export async function removeJson(bucketName: string, key: string) {
  const filePath = getStoreFilePath(bucketName, key)
  try {
    fs.unlink(filePath)
  } catch (e) {
  }
}