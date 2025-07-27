import { URL } from "../../api/base"
import request from "../../api/request"
import promptAction from "@ohos.promptAction"
import { AniSpeed, AppearDisappearAni } from "../../common/Animation"
import { openOrJumpTo } from "../SingletonPage"
import { PageNameEnum } from "../PageNameEnum"
import { OuterScroller } from "../../common/component/OuterScroller"
import { TitleBar } from "../../common/component/TitleBar"
import { AppThemeColor } from "../../common/theme/basic/basic"
import { PreferenceState } from "../NavProvider/NavigationPage"
import { FontSizeEnum } from "../../common/fontSize/FontSizeEnum"
import { generateS1WebPostLink } from "../../common/WantUitl"

export interface ReportPostParam {
  rid: string
  tid: string
  fid: string
  page: number
}

@Component
export struct ReportPost {
  pathStack: NavPathStack = new NavPathStack()
  @State pageParam: ReportPostParam = {
    rid: '',
    tid: '',
    fid: '',
    page: 1
  }
  formData?: ReportFormData = undefined
  @State ready: boolean = false
  @State reasons: string[] = ['请选择举报理由']
  @State selectedReason: number = 0
  @State customReason: string = ''
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState

  popBack() {
    this.pathStack.pop()
  }

  readyToReport() {
    return this.selectedReason > 0
      && (
        this.selectedReason != this.reasons.length - 1 // 其它理由，需要输入
          || this.customReason.length > 0
      )
  }

  isCustomReason() {
    return this.selectedReason == this.reasons.length - 1
  }

  getHandleKey() {
    return `miscreport${this.pageParam.rid}`
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: `举报`,
          clickLeftButton: () => {
            this.popBack()
          },
          useRightMenu: false
        })

        Column({ space: 16 }) {
          if (!this.ready) {
            LoadingProgress()
              .width(64)
              .height(64)
              .color($r('sys.color.ohos_id_color_emphasize'))
              .transition(AppearDisappearAni)
          } else {
            Select(this.reasons.map(v => ({
              value: v
            }) as SelectOption))
              .selected($$this.selectedReason)
              .value(this.reasons[this.selectedReason])
              .width('100%')
              .font({
                size: FontSizeEnum[this.appState.fontSize].vp16
              })
            TextInput({
              placeholder: '在此输入举报理由',
              text: $$this.customReason
            }).maxLength(200)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              .visibility(this.selectedReason > 0 && this.isCustomReason() ? Visibility.Visible : Visibility.Hidden)
            Divider()
            Row() {
              Button('取消').buttonStyle(ButtonStyleMode.TEXTUAL)
                .layoutWeight(1)
                .onClick(() => this.pathStack.pop())
                .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
              Button('举报')
                .buttonStyle(ButtonStyleMode.EMPHASIZED)
                .layoutWeight(1)
                .opacity(this.readyToReport() ? 1 : 0.4)
                .animation({ duration: AniSpeed.ms120 })
                .enabled(this.readyToReport())
                .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                .onClick(() => {
                  new request<string>(URL.REPORT_POST, URL.WEB_BASE)
                    .post({
                      'report_select': this.reasons[this.selectedReason],
                      'message': this.isCustomReason() ? this.customReason : this.reasons[this.selectedReason],
                      'reportsubmit': true,
                      'rid': this.pageParam.rid,
                      'fid': this.pageParam.fid,
                      'inajax': 1,
                      'referer': generateS1WebPostLink(this.pageParam.tid, this.pageParam.page),
                      'url': '',
                      'handlekey': this.getHandleKey(),
                      'formhash': this.formData?.hiddenFields.get('formhash') || '',
                      'rtype': 'post'
                    })
                    .then(() => {
                      promptAction.showToast({
                        message: '已举报'
                      })
                    })
                    .catch(() => {
                      promptAction.showToast({
                        message: '举报时出现异常情况'
                      })
                    })
                    .finally(() => {
                      this.popBack()
                    })
                })
            }
          }
        }.padding(24)
      }
    }.hideTitleBar(true)
    .onReady(async (context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.pageParam = context.pathInfo.param as ReportPostParam
      try {
        const reportForm = await new request<string>(URL.REPORT_POST, URL.WEB_BASE)
          .param('rtype', 'post')
          .param('rid', this.pageParam.rid.toString())
          .param('tid', this.pageParam.tid.toString())
          .param('fid', this.pageParam.fid.toString())
          .param('handlekey', this.getHandleKey())
          .param('t', Date.now().toString())
          .toText()
          .get()
        this.formData = extractReportForm(reportForm)
        this.reasons = this.reasons.concat(this.formData.reasons)
        this.ready = true
      } catch (e) {
        promptAction.showToast({
          message: '获取举报表单失败'
        })
        this.pathStack.pop()
      }
    }).onBackPressed(() => {
      this.popBack()
      return true
    })
  }
}

interface ReportFormData {
  action: string
  reasons: string[]
  hiddenFields: Map<string, string>
}

function extractReportForm(html: string): ReportFormData {
  const formTagMatch = html.match(/<form[^>]*?action="([^"]+)"/i)
  const action = formTagMatch?.[1] || ''

  const hiddenFields = new Map<string, string>()
  const hiddenInputRegex = /<input[^>]*?type="hidden"[^>]*?name="([^"]+)"[^>]*?value="([^"]*)"/gi
  let hiddenMatch: RegExpExecArray | null = null
  while ((hiddenMatch = hiddenInputRegex.exec(html)) !== null) {
    hiddenFields.set(hiddenMatch[1], hiddenMatch[2])
  }

  const reasonsMatch = html.match(/var reasons = \['(.*?)'\];/)
  const reasons = reasonsMatch ? reasonsMatch[1].split("','") : []

  return {
    action,
    reasons,
    hiddenFields,
  }
}

@Builder
export function RegisterBuilder() {
  ReportPost()
}

export function openReportPost(param: ReportPostParam, pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.ReportPost, param)
}