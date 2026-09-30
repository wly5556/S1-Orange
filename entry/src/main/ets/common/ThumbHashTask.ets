import { encodeThumbHashFromFile } from './ThumbHash'

/**
 * 并发函数内只能使用 import 进来的符号、不能调用同文件的普通函数，
 * 因此 @Concurrent 的包装单独放一个文件。
 */
@Concurrent
export async function encodeThumbHashTask(path: string): Promise<string> {
  return encodeThumbHashFromFile(path)
}
