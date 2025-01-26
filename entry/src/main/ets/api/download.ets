import { common } from '@kit.AbilityKit'
import { fileUri, fileIo as fs, picker } from '@kit.CoreFileKit'
import { promptAction } from '@kit.ArkUI'
import { BusinessError, request } from '@kit.BasicServicesKit'
import { userCookieString } from './request'
import { URL } from './base'

export async function DownloadFile(context: common.UIAbilityContext, filename: string, url: string) {
  const sandboxPath = context.cacheDir + '/' + filename
  if (await fs.access(sandboxPath)) {
    await fs.unlink(sandboxPath)
  }
  const config: request.DownloadConfig = {
    background: true,
    title: filename,
    url,
    filePath: sandboxPath,
    header: {
      'cookie': userCookieString,
      'referer': URL.WEB_BASE,
      'user-agent': 'libcurl-agent/1.0'
    }
  }
  request.downloadFile(context, config).then((task: request.DownloadTask) => {
    task.on('complete', async () => {
      promptAction.showToast({
        message: filename + '下载完成'
      })
      const documentViewPicker = new picker.DocumentViewPicker(context)
      const documentSaveOptions = new picker.DocumentSaveOptions()
      documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
      await documentViewPicker.save(documentSaveOptions).then(async (documentSaveResult: Array<string>) => {
        if (documentSaveResult.length > 0) {
          const publicDownloadFolder = new fileUri.FileUri(documentSaveResult[0]).path
          const publicPath = publicDownloadFolder + '/' + filename
          if (await fs.access(publicPath)) {
            await fs.unlink(publicPath)
          }
          await fs.moveFile(sandboxPath, publicPath)
          promptAction.showToast({
            message: `${filename}下载完成，请前往系统下载管理器查看`,
            duration: 5000
          })
        } else {
          promptAction.showToast({
            message: '获取下载目录失败'
          })
          fs.unlink(sandboxPath)
          return
        }
      }).catch((err: BusinessError) => {
        console.error(`Invoke documentViewPicker.save failed, code is ${err.code}, message is ${err.message}`)
      })
    })
    task.on('fail', (err) => {
      promptAction.showToast({
        message: '异常: ' + filename + '下载失败'
      })
    })
  }).catch((err: BusinessError) => {
    console.error(`Failed to request the download. Code: ${err.code}, message: ${err.message}`);
  })
}