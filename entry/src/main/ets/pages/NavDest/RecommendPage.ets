import { common } from '@kit.AbilityKit'
import { SegmentButton, SegmentButtonIconTextItem, SegmentButtonItemTuple, SegmentButtonOptions } from '@kit.ArkUI'
import { OuterScroller } from '../../common/component/OuterScroller'
import { TitleBar } from '../../common/component/TitleBar'
import { AppThemeColor } from '../../common/theme/basic/basic'
import { PageNameEnum } from '../PageNameEnum'
import { openOrJumpTo } from '../SingletonPage'
import { PreferenceState } from '../NavProvider/NavigationPage'
import { FontSizeEnum } from '../../common/fontSize/FontSizeEnum'
import { PropKey } from '../../common/Constants'
import { PreferenceManager } from '../../config/UserConfig'
import { RecommendWeights } from '../../config/v1/default'
import { RoundPanel, SettingGroupHeader, SettingRow } from './Preferences'
import {
  Recommend,
  RECOMMEND_MIN_BUFFER_POSITIVES,
  RECOMMEND_MIN_CLICKS,
  RECOMMEND_MIN_SAMPLES,
  RecommendState,
  RecommendStatus
} from '../../common/recommend/RecommendManager'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'

const WeightGroupLabels: string[] = ['板块', '分类', '标题文本', '正文文本', '热度', '新增互动', '历史行为']
const TopKOptions: string[] = ['1', '2', '3', '4', '5']
const CHART_AREA_HEIGHT = 100
const ANNOT_TEXT_HEIGHT = 16
const CHART_STACK_HEIGHT = CHART_AREA_HEIGHT + ANNOT_TEXT_HEIGHT
const AUC_MIN = 0.5
const AUC_MAX = 1.0
const AUC_THRESHOLD = 0.65
const CHART_BARS = 12

@Component
export struct RecommendPage {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  @Consume appTheme: AppThemeColor
  @Consume @Watch('stateChanged') appState: PreferenceState
  context = getContext(this) as common.UIAbilityContext
  @State status?: RecommendStatus = undefined
  @State weights: number[] = [1, 1, 1, 1, 1, 1, 1]
  @State settingRow: SettingRow = new SettingRow(FontSizeEnum[this.appState.fontSize])
  @State segmentOption: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: TopKOptions.map(v => ({ text: v } as SegmentButtonIconTextItem)) as SegmentButtonItemTuple,
    multiply: false,
    fontSize: FontSizeEnum[this.appState.fontSize].vp16,
    selectedFontSize: FontSizeEnum[this.appState.fontSize].vp16,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK
  })
  @State @Watch('topKChanged') topKSelected: number[] = []

  stateChanged() {
    this.segmentOption.fontSize = FontSizeEnum[this.appState.fontSize].vp16
    this.segmentOption.selectedFontSize = FontSizeEnum[this.appState.fontSize].vp16
    this.settingRow = new SettingRow(FontSizeEnum[this.appState.fontSize])
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      const w = conf.recommend_weights
      this.weights = [w.board, w.type, w.titleText, w.contentText, w.hot, w.fresh, w.history]
      this.topKSelected.push(conf.recommend_top_k - 1)
    })
    this.refreshStatus()
  }

  refreshStatus() {
    Recommend.getStatus().then(s => this.status = s)
  }

  stateText(): string {
    if (!this.status) {
      return '状态：加载中'
    }
    if (this.status.state == RecommendState.active) {
      return '状态：已激活，帖子列表将高亮推荐内容'
    }
    if (this.status.state == RecommendState.degraded) {
      return '状态：观察中，预测准确率下降，暂停高亮'
    }
    return '状态：采集中，学习你的浏览偏好'
  }

  topKChanged() {
    PreferenceManager.modify(conf => {
      this.topKSelected.forEach(idx => {
        conf.recommend_top_k = idx + 1
      })
    })
    Recommend.refreshConfig()
  }

  applyWeight(w: RecommendWeights, idx: number, v: number) {
    switch (idx) {
      case 0:
        w.board = v
        break
      case 1:
        w.type = v
        break
      case 2:
        w.titleText = v
        break
      case 3:
        w.contentText = v
        break
      case 4:
        w.hot = v
        break
      case 5:
        w.fresh = v
        break
      default:
        w.history = v
        break
    }
  }

  onWeightChange(idx: number, v: number) {
    this.weights[idx] = v
    PreferenceManager.modify(conf => {
      this.applyWeight(conf.recommend_weights, idx, v)
    })
    Recommend.refreshConfig()
  }

  barHeight(auc: number): number {
    const ratio = Math.min(Math.max((auc - AUC_MIN) / (AUC_MAX - AUC_MIN), 0), 1)
    return Math.max(ratio * CHART_AREA_HEIGHT, 2)
  }

  thresholdLineY(): number {
    return CHART_STACK_HEIGHT - this.barHeight(AUC_THRESHOLD)
  }

  /** 最后一根柱的数值标注位置（柱顶上方，Stack 顶部预留了一行标注空间） */
  lastAnnotY(): number {
    if (!this.status || this.status.lastAuc < 0) {
      return 0
    }
    return Math.max(CHART_STACK_HEIGHT - this.barHeight(this.status.lastAuc) - ANNOT_TEXT_HEIGHT, 0)
  }

  resetModel() {
    this.getUIContext().showAlertDialog({
      title: '重置推荐模型',
      message: '将清空已学习的模型与全部历史数据，恢复到初始状态。确定继续？',
      buttons: [
        {
          value: '取消',
          action: () => {
          }
        },
        {
          value: '确定',
          fontColor: Color.Red,
          action: (): void => {
            Recommend.reset().then(() => {
              this.refreshStatus()
              this.getUIContext().getPromptAction().showToast({ message: '模型已重置' })
            })
          }
        }]
    })
  }

  @Builder
  statusCard() {
    SettingGroupHeader({
      text: '功能',
      fontSizeIndex: this.appState.fontSize
    })
    Column() {
      Row() {
        Column({ space: 4 }) {
          Text('浏览偏好推荐')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.appTheme.fontPrimary)
          Text('在本地学习你的浏览偏好，自动在帖子列表高亮你可能感兴趣的帖子。所有数据仅保存在本机，不会上传')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
            .fontColor(this.appTheme.fontSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.appState.recommendEnabled }).onChange(isOn => {
          PreferenceManager.modify(conf => {
            conf.recommend_enabled = isOn
            this.appState.recommendEnabled = isOn
          })
          Recommend.refreshConfig()
        })
      }
      .attributeModifier(this.settingRow)
      .alignItems(VerticalAlign.Center)

      Row() {
        Column({ space: 4 }) {
          Text('调试模式')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.appTheme.fontPrimary)
          Text('在参与推荐计算的帖子右下角显示预测分数')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
            .fontColor(this.appTheme.fontSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.appState.recommendDebug }).onChange(isOn => {
          PreferenceManager.modify(conf => {
            conf.recommend_debug = isOn
            this.appState.recommendDebug = isOn
          })
        })
      }
      .attributeModifier(this.settingRow)
      .alignItems(VerticalAlign.Center)

      Row() {
        Blank()
        Button('重置模型')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
          .fontColor(this.appTheme.fontSecondary)
          .onClick(() => this.resetModel())
      }.width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .attributeModifier(new RoundPanel(this.appTheme.backgroundPrimary))
  }

  @Builder
  condLine(met: boolean, label: string) {
    Row({ space: 6 }) {
      Text(met ? '🟢' : '🟡')
        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
        .fontColor(met ? this.appTheme.fontEmphasize : this.appTheme.fontSecondary)
      Text(label)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
        .fontColor(met ? this.appTheme.fontPrimary : this.appTheme.fontSecondary)
    }
  }

  aucCondLabel(): string {
    if (!this.status || this.status.lastAuc < 0) {
      return `最近评估 AUC 暂无（需 ≥${AUC_THRESHOLD}）`
    }
    return `最近评估 AUC ${this.status.lastAuc.toFixed(3)}（需 ≥${AUC_THRESHOLD}）`
  }

  formatBytes(bytes: number): string {
    if (bytes >= 1024 * 1024) {
      return `${(bytes / 1024 / 1024).toFixed(1)} MB`
    }
    if (bytes >= 1024) {
      return `${Math.round(bytes / 1024)} KB`
    }
    return `${bytes} B`
  }

  @Builder
  modelStatusCard() {
    SettingGroupHeader({
      text: '模型状态',
      fontSizeIndex: this.appState.fontSize
    })
    Column({ space: 6 }) {
      if (!this.status) {
        Text('加载中…')
          .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
          .fontColor(this.appTheme.fontSecondary)
      } else {
        Text(this.stateText())
          .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
          .fontColor(this.appTheme.fontPrimary)
        if (this.status.state == RecommendState.collecting) {
          this.condLine(this.status.sampleCount >= RECOMMEND_MIN_SAMPLES,
            `样本 ${this.status.sampleCount}/${RECOMMEND_MIN_SAMPLES}`)
          this.condLine(this.status.clickSampleCount >= RECOMMEND_MIN_CLICKS,
            `点击样本 ${this.status.clickSampleCount}/${RECOMMEND_MIN_CLICKS}`)
          this.condLine(this.status.lastAuc >= AUC_THRESHOLD, this.aucCondLabel())
          this.condLine(this.status.bufferPositives >= RECOMMEND_MIN_BUFFER_POSITIVES,
            `评估正样本 ${this.status.bufferPositives}/${RECOMMEND_MIN_BUFFER_POSITIVES}`)
          Text('各项达标后，在下次列表翻页或刷新时激活高亮')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
            .fontColor(this.appTheme.fontSecondary)
        } else if (this.status.state == RecommendState.degraded) {
          this.condLine(this.status.lastAuc >= AUC_THRESHOLD, this.aucCondLabel())
          this.condLine(this.status.bufferPositives >= RECOMMEND_MIN_BUFFER_POSITIVES,
            `评估正样本 ${this.status.bufferPositives}/${RECOMMEND_MIN_BUFFER_POSITIVES}`)
          Text('满足上述条件后恢复高亮')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
            .fontColor(this.appTheme.fontSecondary)
        } else {
          Text(`已学习 ${this.status.sampleCount} 个样本（含 ${this.status.clickSampleCount} 个点击样本）`)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
            .fontColor(this.appTheme.fontSecondary)
          if (this.status.lastAuc >= 0) {
            Text(`最近评估 AUC：${this.status.lastAuc.toFixed(3)}`)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
              .fontColor(this.appTheme.fontSecondary)
          }
        }
        Divider().opacity(0.4).margin({ top: 2, bottom: 2 })
        Text(`内存占用：约 ${this.formatBytes(this.status.memEstimateBytes)} · ` +
          `磁盘占用：约 ${this.formatBytes(this.status.diskEstimateBytes)}（按数据量估算）`)
          .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
          .fontColor(this.appTheme.fontSecondary)
        Text(this.status.lastComputeMs >= 0 ?
          `上次推荐计算耗时：${this.status.lastComputeMs} ms` : '上次推荐计算耗时：尚未计算')
          .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
          .fontColor(this.appTheme.fontSecondary)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .attributeModifier(new RoundPanel(this.appTheme.backgroundPrimary))
  }

  @Builder
  aucChartCard() {
    SettingGroupHeader({
      text: '预测准确率历史',
      fontSizeIndex: this.appState.fontSize
    })
    Column() {
      if (!this.status) {
        Text('加载中…')
          .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
          .fontColor(this.appTheme.fontSecondary)
      } else if (this.status.aucHistory.length == 0) {
        Text('暂无评估数据。每次列表翻页、刷新或离开版面时进行一次评估')
          .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
          .fontColor(this.appTheme.fontSecondary)
          .padding({ top: 8, bottom: 8 })
      } else {
        Stack({ alignContent: Alignment.BottomStart }) {
          Row({ space: 6 }) {
            ForEach(this.status.aucHistory.slice(-CHART_BARS), (auc: number, idx: number) => {
              Column()
                .width(14)
                .height(this.barHeight(auc))
                .borderRadius(3)
                .backgroundColor(auc >= AUC_THRESHOLD ?
                this.appTheme.fontEmphasize : this.appTheme.fontSecondary)
            }, (auc: number, idx: number) => `${idx}-${auc}`)
          }
          .alignItems(VerticalAlign.Bottom)
          .padding({ left: 6, right: 6 })

          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.appTheme.fontSecondary)
            .opacity(0.4)

          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.appTheme.fontEmphasize)
            .opacity(0.7)
            .position({ x: 0, y: this.thresholdLineY() })

          Row() {
            Blank()
            Text(this.status.lastAuc.toFixed(3))
              .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
              .fontColor(this.appTheme.fontPrimary)
          }
          .width('100%')
          .padding({ right: 6 })
          .position({ x: 0, y: this.lastAnnotY() })
        }
        .width('100%')
        .height(CHART_STACK_HEIGHT)

        Row() {
          Text('AUC 范围: [0.5 - 1]')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
            .fontColor(this.appTheme.fontSecondary)
          Blank()
          Text('最近一次评估值')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
            .fontColor(this.appTheme.fontSecondary)
        }
        .width('100%')
        .margin({ top: 4 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .attributeModifier(new RoundPanel(this.appTheme.backgroundPrimary))
  }

  @Builder
  weightsCard() {
    SettingGroupHeader({
      text: '特征权重与高亮数量',
      fontSizeIndex: this.appState.fontSize
    })
    Column() {
      ForEach(WeightGroupLabels, (label: string, idx: number) => {
        Column({ space: 4 }) {
          Row() {
            Text(label)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
              .fontColor(this.appTheme.fontPrimary)
            Blank()
            Text(this.weights[idx].toFixed(1))
              .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
              .fontColor(this.appTheme.fontSecondary)
          }.width('100%')

          Slider({
            value: this.weights[idx],
            min: 0,
            max: 2,
            step: 0.1
          })
            .selectedColor(this.appTheme.fontEmphasize)
            .onChange(v => this.onWeightChange(idx, v))
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
      }, (label: string) => label)

      Divider().opacity(0.4).margin({ top: 6, bottom: 6 })

      Column({ space: 8 }) {
        Text('高亮帖子数 Top K')
          .fontSize(FontSizeEnum[this.appState.fontSize].vp15)
          .fontColor(this.appTheme.fontPrimary)
        SegmentButton({
          options: this.segmentOption,
          selectedIndexes: $topKSelected
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 6, bottom: 6 })
    }
    .alignItems(HorizontalAlign.Start)
    .attributeModifier(new RoundPanel(this.appTheme.backgroundPrimary))
  }

  build() {
    NavDestination() {
      OuterScroller() {
        TitleBar({
          titleContent: '推荐系统',
          useRightMenu: false,
          clickLeftButton: () => {
            this.pathStack.pop()
          }
        })
        Column() {
          this.statusCard()
          this.modelStatusCard()
          this.aucChartCard()
          this.weightsCard()
          BottomSafeArea()
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 36 })
        .constraintSize({ minHeight: '100%' })
      }
    }
    .hideTitleBar(true)
    .backgroundColor(this.appTheme.backgroundSecondary)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
    .onShown(() => {
      this.refreshStatus()
    })
    .onBackPressed(() => {
      this.pathStack.pop()
      return true
    })
  }
}

@Builder
export function RegisterBuilder() {
  RecommendPage()
}

export function openRecommend(pathStack: NavPathStack) {
  openOrJumpTo(pathStack, PageNameEnum.Recommend)
}
