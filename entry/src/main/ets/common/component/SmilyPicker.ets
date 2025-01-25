import { URL } from '../../api/base';
import request from '../../api/request';
import { ClickDarkenEffect, HeavyClickEffect } from '../Animation';
import { BasicDataSource } from '../BasicDataSource';
import { AppThemeColor } from '../theme/basic/basic';
import { BottomSafeArea } from './BottomSafeArea';
import { ImageSmily } from './ImageSmily';
import { common } from '@kit.AbilityKit';
import { readJson, writeJson } from '../dataStore/JsonPersist';
import { PreferenceState } from '../../pages/NavProvider/NavigationPage';

const SMILY_COL_NUM = 8

class SmilySource extends BasicDataSource<Smily[]> {
  private smiles: Smily[] = []

  constructor() {
    super()
  }

  public totalCount(): number {
    return Math.ceil(this.smiles.length / SMILY_COL_NUM)
  }

  public getData(index: number): Smily[] {
    return this.smiles.slice(index * SMILY_COL_NUM, index * SMILY_COL_NUM + SMILY_COL_NUM)
  }

  public load(smiles: Smily[]) {
    this.smiles = smiles
    this.notifyDataReload()
  }
}

class SmilyGroupSource extends BasicDataSource<SmilySource> {
  private group: SmilySource[] = []

  constructor() {
    super();
  }

  public totalCount(): number {
    return this.group.length
  }

  public getData(index: number): SmilySource {
    return this.group[index]
  }

  public load(smiles: Smily[][]) {
    smiles.forEach(s => {
      const item = new SmilySource()
      item.load(s)
      this.group.push(item)
    })
    this.notifyDataReload()
  }
}

interface SmilyInfoCache {
  data: Smily[][]
  group: SmilyGroup[]
  updateAt: number
}

let memoryCache: SmilyInfoCache

function loadCache(cacheMissed: () => void) {
  return new Promise<SmilyInfoCache>(res => {
    readJson<SmilyInfoCache>('smilies', 'smilies_list').then(data => {
      if (data == null) {
        throw new Error
      }
      memoryCache = data
      res(memoryCache)
    }).catch(() => {
      cacheMissed()
    }).finally(() => {
      const lastUpdate = memoryCache ? (memoryCache.updateAt || 0) : 0
      if (lastUpdate < Date.now() - 24 * 60 * 60 * 1000) {
        const latest: SmilyInfoCache = {
          data: [],
          group: [],
          updateAt: Date.now()
        }
        new request<string>(URL.SMILY_LIST, URL.WEB_BASE)
          .toText()
          .get()
          .then(data => {
            const smilies: Record<string, SmiliesInfo> = extractSmiliesType(data)
            extractSmiliesArray(data, smilies)
            Object.values(smilies).forEach(smilies => {
              latest.data.push(smilies.smilies)
              latest.group.push({
                type_id: smilies.type_id,
                name: smilies.name,
                path: smilies.path
              })
            })
            memoryCache = latest
            res(memoryCache)
            writeJson<SmilyInfoCache>('smilies', 'smilies_list', memoryCache)
          })
      }
    })
  })
}

@Component
export struct SmilyPicker {
  @State clickEffectModifier: AttributeModifier<CommonAttribute> = new ClickDarkenEffect()
  smilyGroupSource: SmilyGroupSource = new SmilyGroupSource()
  @State smilyGroup: SmilyGroup[] = []
  @State smilyGroupIndex: number = 0
  @State tabBarIndex: number = 0
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  context = getContext(this) as common.UIAbilityContext
  onPicked: (text: string) => void = () => {
  }
  controller: SwiperController = new SwiperController()

  aboutToAppear(): void {
    loadCache(() => {
      this.getUIContext().getPromptAction().showToast({
        message: '表情包功能初次加载，耗时较长'
      })
    }).then(cache => {
      this.smilyGroup = cache.group
      this.smilyGroupSource.load(cache.data)
    })
  }

  build() {
    Scroll() {
      Column() {
        if (this.smilyGroup.length == 0) {
          LoadingProgress()
            .width(64)
            .height(64)
            .color($r('sys.color.ohos_id_color_emphasize'))
            .offset({ top: 100 })
            .zIndex(100)
        }
        Tabs({ barPosition: BarPosition.Start, index: this.tabBarIndex }) {
          ForEach(this.smilyGroup, (item: SmilyGroup, index: number) => {
            TabContent() {
            }.tabBar(SubTabBarStyle.of(item.name)
              .labelStyle({ selectedColor: this.appTheme.fontEmphasize})
              .indicator({ color: '#00000000' })
            )
          })
        }.onAnimationStart((index, target) => {
          this.controller.changeIndex(target, true)
        })
        .barMode(BarMode.Scrollable)
        .scrollable(false)
        .height('auto')
        Swiper(this.controller) {
          LazyForEach(this.smilyGroupSource, (group: SmilyGroupSource, groupIndex: number) => {
            List() {
              LazyForEach(group, (item: Smily[]) => {
                ListItem() {
                  GridRow({
                    columns: SMILY_COL_NUM
                  }) {
                    ForEach(item, (smily: Smily) => {
                      GridCol() {
                        ImageSmily({
                          src: getSmilyUrl(smily, this.smilyGroup[groupIndex])
                        })
                      }.onClick(() => {
                        this.onPicked(smily.text)
                      }).padding({ top: 8, bottom: 8 })
                      .clickEffect(HeavyClickEffect)
                      .attributeModifier(this.clickEffectModifier)
                      .borderRadius(8)
                    })
                  }
                }
              })
              ListItem() {
                BottomSafeArea()
              }
            }
            .width('100%')
            .height('100%')
            .nestedScroll({
              scrollForward: NestedScrollMode.PARENT_FIRST,
              scrollBackward: NestedScrollMode.PARENT_FIRST
            })
            .scrollBar(BarState.Off)
            .transition(TransitionEffect.OPACITY.animation({ duration: 100 }))
          })
        }
        .index($$this.smilyGroupIndex)
        .width('100%')
        .height('100%')
        .loop(false)
        .cachedCount(0)
        .indicator(false)
        .onAnimationStart((index, target) => {
          this.tabBarIndex = target
        })
      }.alignItems(HorizontalAlign.Center)
    }.scrollBar(BarState.Off)
  }
}

interface Smily {
  text: string
  filename: string
}

interface SmiliesInfo {
  type_id: string
  name: string
  path: string
  smilies: Smily[]
}

interface SmilyGroup {
  type_id: string
  name: string
  path: string
}

function extractSmiliesType(input: string): Record<string, SmiliesInfo> {
  const regex = /smilies_type\['(_\d+)'\]\s*=\s*\['([^']+)', '([^']+)'\];/g
  const result: Record<string, SmiliesInfo> = {}
  let match: RegExpExecArray | null = null
  while ((match = regex.exec(input)) !== null) {
    if (match.length == 4) {
      const type_id = match[1].substring(1)
      const path = match[3]
      if (!path.includes('2017')) {
        continue
      }
      result[type_id] = {
        type_id: type_id,
        name: match[2],
        path: match[3],
        smilies: []
      }
    }
  }
  return result
}

function extractSmiliesArray(input: string, smilies: Record<string, SmiliesInfo>) {
  const regex = /smilies_array\[(\d+)\]\[\d+\]\s*=\s*(\[.*?\]);/gs
  let match: RegExpExecArray | null = null
  while ((match = regex.exec(input)) !== null) {
    if (match.length != 3) {
      continue
    }
    const type_id = parseInt(match[1], 10)
    let dataStr = match[2]
    dataStr = dataStr.replace(/'/g, '"')

    const data = JSON.parse(dataStr) as Array<string[]>
    data.forEach(tuple => { // ['758', '[f:001]', '001.png', '20', '20', '32']
      if (smilies[type_id]) {
        smilies[type_id].smilies.push({
          text: tuple[1],
          filename: tuple[2]
        })
      }
    })
  }
}

function getSmilyUrl(smily: Smily, group: SmilyGroup) {
  return URL.SMILY_HOST_A + group.path + '/' + smily.filename
}