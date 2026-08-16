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
  RECOMMEND_MIN_CLICKS,
  RECOMMEND_MIN_SAMPLES,
  RecommendState,
  RecommendStatus
} from '../../common/recommend/RecommendManager'
import { BottomSafeArea } from '../../common/component/BottomSafeArea'

const WeightGroupLabels: string[] = ['板块', '分类', '标题文本', '正文文本', '热度', '新增互动', '历史行为']
const TopKOptions: string[] = ['1', '2', '3', '4', '5']
const CHART_AREA_HEIGHT = 100
const CHART_TOTAL_HEIGHT = 124
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
    return CHART_TOTAL_HEIGHT - (AUC_THRESHOLD - AUC_MIN) / (AUC_MAX - AUC_MIN) * CHART_AREA_HEIGHT
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
      .alignItems(VerticalAlign.Top)

      if (this.status) {
        Column({ space: 4 }) {
          Text(this.stateText())
            .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
            .fontColor(this.appTheme.fontPrimary)
          Text(`已采集样本 ${this.status.sampleCount}/${RECOMMEND_MIN_SAMPLES}，` +
            `点击样本 ${this.status.clickSampleCount}/${RECOMMEND_MIN_CLICKS}`)
            .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
            .fontColor(this.appTheme.fontSecondary)
          if (this.status.lastAuc >= 0) {
            Text(`最近评估 AUC：${this.status.lastAuc.toFixed(3)}`)
              .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
              .fontColor(this.appTheme.fontSecondary)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

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
  progressRow(label: string, value: number, total: number) {
    Column({ space: 4 }) {
      Text(`${label} ${value}/${total}`)
        .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
        .fontColor(this.appTheme.fontSecondary)
      Progress({ value: Math.min(value, total), total: total, type: ProgressType.Linear })
        .color(this.appTheme.fontEmphasize)
    }.width('100%')
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
      } else if (this.status.state == RecommendState.collecting) {
        Column({ space: 10 }) {
          this.progressRow('样本', this.status.sampleCount, RECOMMEND_MIN_SAMPLES)
          this.progressRow('点击', this.status.clickSampleCount, RECOMMEND_MIN_CLICKS)
          Text('样本量与预测准确率达标后自动激活高亮')
            .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
            .fontColor(this.appTheme.fontSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      } else if (this.status.aucHistory.length == 0) {
        Text('暂无评估数据')
          .fontSize(FontSizeEnum[this.appState.fontSize].vp14)
          .fontColor(this.appTheme.fontSecondary)
          .padding({ top: 8, bottom: 8 })
      } else {
        Stack({ alignContent: Alignment.BottomStart }) {
          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.appTheme.fontSecondary)
            .opacity(0.4)

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
          .padding({ left: 6, right: 6 })

          Line()
            .width('100%')
            .height(1)
            .startPoint([0, 0.5])
            .endPoint(['100%', 0.5])
            .strokeWidth(1)
            .strokeDashArray([5, 4])
            .stroke(this.appTheme.fontEmphasize)
            .opacity(0.7)
            .position({ x: 0, y: this.thresholdLineY() })

          Row() {
            Blank()
            Text('冷启动阈值 0.65')
              .fontSize(FontSizeEnum[this.appState.fontSize].vp12)
              .fontColor(this.appTheme.fontEmphasize)
              .opacity(0.8)
          }
          .width('100%')
          .position({ x: 0, y: this.thresholdLineY() - 18 })
        }
        .width('100%')
        .height(CHART_TOTAL_HEIGHT)
        .padding({ top: 8, bottom: 4 })
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
          this.aucChartCard()
          this.weightsCard()
          BottomSafeArea()
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
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
