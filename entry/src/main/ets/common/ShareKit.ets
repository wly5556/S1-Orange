import { systemShare } from '@kit.ShareKit'
import { unifiedDataChannel, uniformTypeDescriptor as utd } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { BusinessError, pasteboard } from '@kit.BasicServicesKit'
import { fileUri } from '@kit.CoreFileKit'
import { promptAction } from '@kit.ArkUI'

export function ShareText(text: string, context: common.UIAbilityContext) {
  const shareData: systemShare.SharedData = new systemShare.SharedData({
    utd: utd.UniformDataType.TEXT,
    content: text,
  })
  const controller: systemShare.ShareController = new systemShare.ShareController(shareData)
  controller.show(context, {
    selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DETAIL,
  }).then(() => {
    console.info('ShareController show success.')
  }).catch((error: BusinessError) => {
    console.error(`ShareController show error. code: ${error.code}, message: ${error.message}`)
  })
}

export function ShareImage(path: string, ext: string, context: common.UIAbilityContext) {
  const utdTypeId = utd.getUniformDataTypeByFilenameExtension(`.${ext}`, utd.UniformDataType.IMAGE);
  const shareData: systemShare.SharedData = new systemShare.SharedData({
    utd: utdTypeId,
    uri: fileUri.getUriFromPath(path)
  })
  const controller: systemShare.ShareController = new systemShare.ShareController(shareData)
  controller.show(context, {
    selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DETAIL,
  }).then(() => {
    console.info('ShareController show success.')
  }).catch((error: BusinessError) => {
    console.error(`ShareController show error. code: ${error.code}, message: ${error.message}`)
  })
}

export function CopyText(text: string, toast?: string) {
  const plaintext = new unifiedDataChannel.PlainText()
  plaintext.textContent = text
  writeToPasteboard(plaintext, toast)
}

export function CopyHyperLink(url: string, desc?: string, toast?: string) {
  const link = new unifiedDataChannel.Hyperlink()
  link.url = url
  if (desc) {
    link.description = desc
  }
  writeToPasteboard(link, toast)
}

function writeToPasteboard(content: unifiedDataChannel.UnifiedRecord, toast: string = '已复制') {
  const data = new unifiedDataChannel.UnifiedData()
  data.properties.shareOptions = unifiedDataChannel.ShareOptions.CROSS_APP
  data.addRecord(content)
  pasteboard.getSystemPasteboard().setUnifiedData(data).then(() => {
    promptAction.showToast({
      message: toast
    })
  }).catch((error: BusinessError) => {

  })
}