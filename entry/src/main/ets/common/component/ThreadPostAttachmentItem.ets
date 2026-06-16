import { common } from '@kit.AbilityKit'
import { URL } from '../../api/base'
import { DownloadFile } from '../../api/download'
import { Attachment } from '../../api/model/postList'
import { FontSizeIndex } from '../../config/v1/default'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { AppThemeColor } from '../theme/basic/basic'

@Component
export struct ThreadPostAttachmentItem {
  @Prop @Require attach: Attachment
  @Prop @Require appTheme: AppThemeColor
  @Prop @Require fontSize: FontSizeIndex
  context = getContext(this) as common.UIAbilityContext

  build() {
    Row({ space: 12 }) {
      Image($r('app.media.arrow_right_folder_circle')).width(26).height(26)
        .fillColor(this.appTheme.fontEmphasize)
      Column({ space: 6 }) {
        Text(this.attach.filename)
          .fontSize(FontSizeEnum[this.fontSize].vp14)
          .wordBreak(WordBreak.BREAK_ALL)
        Text(`${this.attach.attachsize}   ${this.attach.downloads}\u6b21\u4e0b\u8f7d`)
          .fontSize(FontSizeEnum[this.fontSize].vp12)
          .opacity(.7)
      }.flexGrow(100)
      .flexShrink(1)
      .alignItems(HorizontalAlign.Start)

      Button('\u4e0b\u8f7d')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .fontSize(FontSizeEnum[this.fontSize].vp14)
        .onClick(() => {
          DownloadFile(this.context, this.attach.filename,
            URL.WEB_BASE + URL.ATTACHMENT_DOWNLOAD + this.attach.aidencode)
        })
    }
    .backgroundColor(this.appTheme.backgroundTertiary)
    .padding(12)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .margin({ top: 8 })
  }
}
