export async function waitFor(ms: number) {
  return new Promise<void>(res => setTimeout(res, ms))
}