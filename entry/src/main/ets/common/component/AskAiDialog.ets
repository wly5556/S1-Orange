import { common } from '@kit.AbilityKit'
import { AppThemeColor } from '../theme/basic/basic'
import { ThemeColorLight } from '../theme/basic/light'
import { AniSpeed } from '../Animation'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { UIRootNode } from './ThreadPostContent'
import { ShareText } from '../ShareKit'
import { buildAskAiMarkdown, buildAskAiPayload, computeAskAiStats } from '../AskAiUtil'
import { PreferenceManager } from '../../config/UserConfig'
import { defaultApplicationConfig } from '../../config/v1/default'

@CustomDialog
export struct AskAiDialog {
  controller: CustomDialogController
  context = getContext(this) as common.UIAbilityContext
  @Prop postNodes: UIRootNode[] = []
  @Prop postAuthor: string = ''
  @Prop postDateline: number = 0
  @Prop postTid: string = ''
  @Prop postPid: string = ''
  @Prop postSubject: string = ''
  @Prop appTheme: AppThemeColor = new ThemeColorLight()
  @Prop fontSize: number = 0
  @State includeQuotes: boolean = defaultApplicationConfig.ask_ai_include_quoted
  @State includeMainPost: boolean = defaultApplicationConfig.ask_ai_include_main
  @State inputText: string = ''
  @State sending: boolean = false
  @State statsText: string = ''
  @State statsOpacity: number = 1
  statsVersion: number = 0

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.includeQuotes = conf.ask_ai_include_quoted
      this.includeMainPost = conf.ask_ai_include_main
      this.updateStats()
    })
  }

  async updateStats(): Promise<void> {
    this.statsVersion++
    const version = this.statsVersion
    try {
      const markdown = await buildAskAiMarkdown(this.postNodes, this.postAuthor, this.postDateline,
        this.postTid, this.postPid, this.postSubject, this.includeMainPost, this.includeQuotes)
      if (version != this.statsVersion) {
        return
      }
      const stats = computeAskAiStats(markdown)
      this.statsText = `${stats.floorCount}层楼 共${stats.charCount}字符`
      this.statsOpacity = 1
    } catch (e) {
      if (version == this.statsVersion) {
        this.statsText = ''
        this.statsOpacity = 1
      }
    }
  }

  onContextToggle(which: 'main' | 'quoted', checked: boolean): void {
    if (which == 'main') {
      this.includeMainPost = checked
      PreferenceManager.modify(conf => {
        conf.ask_ai_include_main = checked
      })
    } else {
      this.includeQuotes = checked
      PreferenceManager.modify(conf => {
        conf.ask_ai_include_quoted = checked
      })
    }
    this.statsText = '统计中'
    this.statsOpacity = 0.7
    this.updateStats()
  }

  async sendToAi(prompt: string): Promise<void> {
    if (this.sending) {
      return
    }
    if (prompt.length == 0) {
      return
    }
    this.sending = true
    const payload = await buildAskAiPayload(this.postNodes, this.postAuthor, this.postDateline,
      this.postTid, this.postPid, this.postSubject, this.includeMainPost, this.includeQuotes, prompt)
    ShareText(payload, this.context)
    this.sending = false
    this.controller.close()
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Text('上下文')
          .fontSize(FontSizeEnum[this.fontSize].vp16)
          .fontColor(this.appTheme.fontSecondary)
        Blank()
        Checkbox({ name: 'askAiIncludeMain' })
          .select(this.includeMainPost)
          .onChange((checked: boolean) => {
            this.onContextToggle('main', checked)
          })
        Text('主楼')
          .fontSize(FontSizeEnum[this.fontSize].vp16)
        Checkbox({ name: 'askAiIncludeQuoted' })
          .select(this.includeQuotes)
          .onChange((checked: boolean) => {
            this.onContextToggle('quoted', checked)
          })
        Text('被引用楼层')
          .fontSize(FontSizeEnum[this.fontSize].vp16)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 12 }) {
        Button('总结一下')
          .fontSize(FontSizeEnum[this.fontSize].vp16)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(1)
          .enabled(!this.sending)
          .onClick(() => this.sendToAi('总结一下'))
        Button('真的吗？')
          .fontSize(FontSizeEnum[this.fontSize].vp16)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(1)
          .enabled(!this.sending)
          .onClick(() => this.sendToAi('真的吗？'))
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: $$this.inputText, placeholder: '或者是其它问题...' })
          .fontSize(FontSizeEnum[this.fontSize].vp16)
          .layoutWeight(1)
          .enabled(!this.sending)
          .onSubmit(() => {
            const text = this.inputText.trim()
            if (text.length > 0) {
              this.sendToAi(text)
            }
          })
        Button('发送')
          .fontSize(FontSizeEnum[this.fontSize].vp16)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .enabled(!this.sending && this.inputText.trim().length > 0)
          .onClick(() => {
            const text = this.inputText.trim()
            if (text.length > 0) {
              this.sendToAi(text)
            }
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.statsText)
        .fontSize(16)
        .fontColor(this.appTheme.fontSecondary)
        .width('100%')
        .textAlign(TextAlign.End)
        .opacity(this.statsOpacity)
        .animation({ duration: AniSpeed.ms120 })
    }
    .padding(20)
    .borderRadius(16)
  }
}
