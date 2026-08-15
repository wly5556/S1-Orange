import { common } from '@kit.AbilityKit'
import { AppThemeColor } from '../theme/basic/basic'
import { ThemeColorLight } from '../theme/basic/light'
import { AniSpeed } from '../Animation'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { UIRootNode } from './ThreadPostContent'
import { ShareText } from '../ShareKit'
import { buildAskAiMarkdown, composeAskAiPayload, computeAskAiStats } from '../AskAiUtil'
import { PreferenceManager } from '../../config/UserConfig'
import { defaultApplicationConfig } from '../../config/v1/default'

const DEFAULT_PREVIOUS_COUNT = 5
const MAX_PREVIOUS_COUNT = 400
const STATS_DEBOUNCE_MS = 300

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
  @Prop postFloorNumber: string = ''
  @Prop appTheme: AppThemeColor = new ThemeColorLight()
  @Prop fontSize: number = 0
  @State includeQuotes: boolean = defaultApplicationConfig.ask_ai_include_quoted
  @State includeMainPost: boolean = defaultApplicationConfig.ask_ai_include_main
  @State includePrevious: boolean = defaultApplicationConfig.ask_ai_include_previous
  @State previousCountText: string = DEFAULT_PREVIOUS_COUNT.toString()
  @State inputText: string = ''
  @State sending: boolean = false
  @State statsText: string = ''
  @State statsOpacity: number = 1
  statsVersion: number = 0
  statsTask: Promise<string> | undefined = undefined
  statsTaskKey: string = ''
  lastMarkdown: string = ''
  lastKey: string = ''
  statsDebounceTimer: number = -1

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      this.includeQuotes = conf.ask_ai_include_quoted
      this.includeMainPost = conf.ask_ai_include_main
      this.includePrevious = conf.ask_ai_include_previous
      this.updateStats()
    })
  }

  aboutToDisappear(): void {
    if (this.statsDebounceTimer >= 0) {
      clearTimeout(this.statsDebounceTimer)
      this.statsDebounceTimer = -1
    }
  }

  getCurrentFloor(): number {
    const floor = parseInt(this.postFloorNumber)
    return isNaN(floor) ? 0 : floor
  }

  getPreviousCount(): number {
    const count = parseInt(this.previousCountText)
    if (isNaN(count) || count < 1) {
      return DEFAULT_PREVIOUS_COUNT
    }
    return Math.min(count, MAX_PREVIOUS_COUNT)
  }

  contextKey(): string {
    return `${this.postPid}|${this.includeMainPost}|${this.includeQuotes}|${this.includePrevious}|${this.getPreviousCount()}|${this.getCurrentFloor()}`
  }

  buildMarkdown(): Promise<string> {
    return buildAskAiMarkdown(this.postNodes, this.postAuthor, this.postDateline,
      this.postTid, this.postPid, this.postSubject, this.includeMainPost, this.includeQuotes,
      this.includePrevious, this.getPreviousCount(), this.getCurrentFloor())
  }

  setPreviousCount(count: number): void {
    this.previousCountText = Math.min(Math.max(count, 1), MAX_PREVIOUS_COUNT).toString()
    this.refreshStats()
  }

  refreshStats(): void {
    this.statsText = '统计中'
    this.statsOpacity = 0.7
    this.updateStats()
  }

  refreshStatsDebounced(): void {
    this.statsText = '统计中'
    this.statsOpacity = 0.7
    if (this.statsDebounceTimer >= 0) {
      clearTimeout(this.statsDebounceTimer)
    }
    this.statsDebounceTimer = setTimeout(() => {
      this.statsDebounceTimer = -1
      this.updateStats()
    }, STATS_DEBOUNCE_MS)
  }

  applyStats(markdown: string): void {
    const stats = computeAskAiStats(markdown)
    this.statsText = `${stats.floorCount}层楼 共${stats.charCount}字符`
    this.statsOpacity = 1
  }

  async updateStats(): Promise<void> {
    const key = this.contextKey()
    if (key == this.lastKey) {
      this.applyStats(this.lastMarkdown)
      return
    }
    if (key == this.statsTaskKey && this.statsTask) {
      return
    }
    this.statsVersion++
    const version = this.statsVersion
    const task = this.buildMarkdown()
    this.statsTask = task
    this.statsTaskKey = key
    try {
      const markdown = await task
      if (version == this.statsVersion) {
        this.lastMarkdown = markdown
        this.lastKey = key
        this.applyStats(markdown)
      }
    } catch (e) {
      if (version == this.statsVersion) {
        this.statsText = ''
        this.statsOpacity = 1
      }
    } finally {
      if (this.statsTask == task) {
        this.statsTask = undefined
        this.statsTaskKey = ''
      }
    }
  }

  onContextToggle(which: 'main' | 'quoted' | 'previous', checked: boolean): void {
    if (which == 'main') {
      this.includeMainPost = checked
      PreferenceManager.modify(conf => {
        conf.ask_ai_include_main = checked
      })
    } else if (which == 'quoted') {
      this.includeQuotes = checked
      PreferenceManager.modify(conf => {
        conf.ask_ai_include_quoted = checked
      })
    } else {
      this.includePrevious = checked
      PreferenceManager.modify(conf => {
        conf.ask_ai_include_previous = checked
      })
    }
    this.refreshStats()
  }

  async sendToAi(prompt: string): Promise<void> {
    if (this.sending) {
      return
    }
    if (prompt.length == 0) {
      return
    }
    this.sending = true
    const key = this.contextKey()
    let markdown: string
    if (key == this.lastKey) {
      markdown = this.lastMarkdown
    } else {
      let task = this.statsTaskKey == key ? this.statsTask : undefined
      if (!task) {
        task = this.buildMarkdown()
      }
      try {
        markdown = await task
      } catch (e) {
        markdown = ''
      }
      this.lastMarkdown = markdown
      this.lastKey = key
    }
    ShareText(composeAskAiPayload(markdown, prompt), this.context)
    this.sending = false
    this.controller.close()
  }

  @Builder
  quickCountButton(count: number) {
    Button(count.toString() + '层')
      .enabled(!this.sending && this.includePrevious)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .onClick(() => {
        this.setPreviousCount(count)
      })
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

      Row({ space: 8 }) {
        Checkbox({ name: 'askAiIncludePrevious' })
          .select(this.includePrevious)
          .onChange((checked: boolean) => {
            this.onContextToggle('previous', checked)
          })
        Text('之前的')
          .fontSize(FontSizeEnum[this.fontSize].vp16)
        TextInput({ text: this.previousCountText })
          .fontSize(FontSizeEnum[this.fontSize].vp16)
          .type(InputType.Number)
          .flexShrink(1)
          .padding({ left: 8, right: 8 })
          .enabled(!this.sending && this.includePrevious)
          .onChange((value: string) => {
            const digits = value.replace(/\D/g, '')
            if (digits.length == 0) {
              this.previousCountText = ''
            } else {
              const count = parseInt(digits)
              this.previousCountText = count > MAX_PREVIOUS_COUNT ?
              MAX_PREVIOUS_COUNT.toString() : count.toString()
            }
            this.refreshStatsDebounced()
          })
        Text('层')
          .fontSize(FontSizeEnum[this.fontSize].vp16)
        Blank()
        this.quickCountButton(10)
        this.quickCountButton(40)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()

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
