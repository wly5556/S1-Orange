import { Avatar } from './Avatar'
import {
  addUserTag,
  getUserTags,
  getTagHistory,
  addTagHistory,
  removeUserTag
} from '../dataStore/UserTag'

@CustomDialog
export struct UserTagDialog {
  controller: CustomDialogController
  @Prop uid: string = ''
  @Prop username: string = ''
  @Prop userCredit: string = ''
  @State userTags: string[] = []
  @State historyTags: string[] = []
  @State inputText: string = ''
  onTagChanged: (uid: string) => void = () => {}

  aboutToAppear(): void {
    this.userTags = getUserTags(this.uid)
    this.historyTags = getTagHistory()
  }

  submitInput() {
    const parts = this.inputText.split(/\s+/).map(s => s.trim()).filter(s => s.length > 0)
    parts.forEach(tag => {
      addUserTag(this.uid, tag)
      addTagHistory(tag)
    })
    this.inputText = ''
    this.userTags = getUserTags(this.uid)
    this.historyTags = getTagHistory()
    this.onTagChanged(this.uid)
  }

  addFromHistory(tag: string) {
    addUserTag(this.uid, tag)
    this.userTags = getUserTags(this.uid)
    this.onTagChanged(this.uid)
  }

  removeTag(tag: string) {
    removeUserTag(this.uid, tag)
    this.userTags = getUserTags(this.uid)
    this.onTagChanged(this.uid)
  }

  @Builder
  existingTagChip(tag: string) {
    Row({ space: 4 }) {
      Text(tag)
        .fontSize(16)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Image($r('app.media.plus'))
        .width(14)
        .height(14)
        .fillColor($r('sys.color.font_primary'))
        .rotate({ angle: 45 })
    }
    .padding({ left: 12, right: 10, top: 6, bottom: 6 })
    .borderRadius(16)
    .backgroundColor($r('sys.color.background_tertiary'))
    .margin({ right: 8, bottom: 8 })
    .onClick(() => this.removeTag(tag))
  }

  @Builder
  historyTagChip(tag: string) {
    Row({ space: 4 }) {
      Text(tag)
        .fontSize(16)
        .fontColor(this.userTags.includes(tag) ? $r('sys.color.font_tertiary') :
        $r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Image($r('app.media.plus'))
        .width(14)
        .height(14)
        .fillColor(this.userTags.includes(tag) ? $r('sys.color.font_tertiary') :
        $r('sys.color.font_primary'))
    }
    .padding({ left: 12, right: 10, top: 6, bottom: 6 })
    .borderRadius(16)
    .backgroundColor($r('sys.color.background_tertiary'))
    .opacity(this.userTags.includes(tag) ? 0.5 : 1)
    .margin({ right: 8, bottom: 8 })
    .onClick(() => this.addFromHistory(tag))
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        Avatar({
          uid: this.uid,
          avatarSize: 40
        })
        Column({ space: 2 }) {
          Text(this.username)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(this.userCredit)
            .fontSize(13)
            .opacity(0.7)
            .fontColor($r('sys.color.font_tertiary'))
        }.alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }.width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 6 }) {
        Text('已有标签')
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
        if (this.userTags.length == 0) {
          Text('暂无')
            .fontSize(13)
            .opacity(0.5)
        } else {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.userTags, (tag: string) => {
              this.existingTagChip(tag)
            }, (tag: string) => tag)
          }.width('100%')
        }
      }.width('100%')
      .alignItems(HorizontalAlign.Start)

      TextInput({ text: $$this.inputText, placeholder: '在此输入。空格分隔多个' })
        .fontSize(14)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .onSubmit(() => this.submitInput())

      if (this.historyTags.length > 0) {
        Column({ space: 6 }) {
          Text('常用标签')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.historyTags, (tag: string) => {
              this.historyTagChip(tag)
            }, (tag: string) => tag)
          }.width('100%')
        }.width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }.width('100%')
    .padding(24)
  }
}
