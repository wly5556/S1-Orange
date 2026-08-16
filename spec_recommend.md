# S1-Orange 帖子推荐系统 Spec（偏好预测 + 列表高亮）

> 状态：待实现设计稿。所有文件路径、行号基于撰写时的代码现状，实现时以实际代码为准。

## 1. 概述

为论坛帖子列表增加一个**纯客户端、在线学习**的个性化偏好预测系统：

- 后台静默采集用户在帖子列表上的曝光与点击行为，结合帖子文本与热度特征，用 **FTRL-Proximal 在线逻辑回归** 持续训练"该用户是否会点击此帖"的模型；
- 冷启动完成且准确率达到阈值后，在每次帖子列表曝光时（初次进入、翻页、刷新、看贴返回后的缓存加载）对帖子打分，**Top K（默认 3）** 在帖子 item 左侧用 `fontEmphasize` 色小矩形高亮；
- 新增"推荐系统"页面（侧边栏入口），含功能说明+总开关、预测准确率历史柱状图、特征组权重调整三张卡片。

### 1.1 约束

- 纯客户端，无任何网络上报（隐私数据不出设备）；
- 计算量低：每页 50 帖推理 + 增量训练均需在毫秒级完成，不阻塞 UI；
- 移动端可运行：ArkTS 自研实现，不引入第三方依赖；
- 经过大量验证的算法：采用 Google CTR 预测生产系统同款（FTRL-Proximal）。

### 1.2 非目标

- 不做帖子重排序，只做高亮标记，不改变列表原有顺序；
- 不做跨用户/云端协同；
- 不纳入个人数据备份导出范围（模型文件较大且与设备行为相关，仅配置项随 `ApplicationConfig` 常规导出）。

## 2. 技术选型与论证

### 2.1 算法：FTRL-Proximal 在线逻辑回归

选型结论（已与用户确认）：**FTRL-Proximal（Follow-The-Regularized-Leader）优化的在线逻辑回归**，即 Google 论文《Ad Click Prediction: a View from the Trenches》(KDD'13) 中大规模 CTR 预测的生产算法。

| 候选 | 计算量 | 在线学习 | 精度 | 可解释/可调权重 | 结论 |
|---|---|---|---|---|---|
| **FTRL-Proximal LR** | 单样本 O(特征非零数) | 天然流式 | 高（CTR 场景业界标杆） | 线性权重，可按特征组调整 | **采用** |
| 多项式朴素贝叶斯 | 极低 | 流式 | 中（特征独立假设） | 权重不可调，与卡片3需求冲突 | 否 |
| 启发式线性加权 | 极低 | 无学习过程 | —（规则固定） | "准确率阈值"无从定义 | 否 |
| 端侧神经模型（EODRec 等） | 高 | 需训练框架 | 高 | 黑盒 | 单用户数据量下严重过杀，否 |

理由：

1. 场景完全同构：本需求就是 CTR 预测——"给定一次曝光（帖子+上下文特征），预测 P(点击)"；
2. 流式更新：每来一个标注样本做一次 O(nnz) 更新，无需全量重训，天然支持"边用边学"；
3. 资源友好：L1 正则产出稀疏权重，配合特征哈希，内存/持久化体积可控在 MB 级以下；
4. 实现简单：核心算法百行级（已有纯 JS 参考实现 ftrljs），ArkTS 严格模式可实现，无 `any`；
5. 中文文本无需分词：标题/正文用**字符 1+2-gram + 特征哈希**表示，研究表明其对中文文本分类有效（Luo et al., ICDAR 2011），规避 ArkTS 无轻量中文分词库的问题。

### 2.2 参考文献

- McMahan et al. *Ad Click Prediction: a View from the Trenches*. KDD 2013.（FTRL-Proximal 算法与工程实践）
- Luo et al. *A Study on Automatic Chinese Text Classification*. ICDAR 2011.（中文 1+2-gram 特征有效性）
- ftrljs（https://github.com/dirkschumacher/ftrljs）：纯 JS 的 FTRL-Proximal 实现，移植参考。

## 3. 总体架构

```
ThreadList.ets ──曝光埋点──┐
ThreadList.ets ──点击埋点──┤
ThreadPostList.ets ─浏览时长─┤
                           ▼
                 RecommendManager（单例）
        ┌──────────────┼──────────────────┐
        ▼              ▼                  ▼
  FeatureExtractor  FtrlModel      JsonPersist 持久化
  (n-gram/哈希/分桶) (训练/打分/AUC)  (recommend/<uid>/model)
        ▲
        └── 打分结果 topK 集合 ──→ ThreadList 高亮渲染
                 状态/AUC 历史/配置 ──→ RecommendPage 三张卡片
```

模块职责：

| 模块 | 文件（新增） | 职责 |
|---|---|---|
| 特征提取 | `common/recommend/FeatureExtractor.ets` | 文本 n-gram、FNV-1a 特征哈希、数值分桶、特征分组、tid 级文本特征 LRU 缓存 |
| 模型 | `common/recommend/FtrlModel.ets` | FTRL-Proximal 更新、sigmoid 打分、加权 AUC |
| 管理器 | `common/recommend/RecommendManager.ets` | 曝光批次管理、样本生成、训练调度、激活状态机、持久化、配置缓存 |
| 页面 | `pages/NavDest/RecommendPage.ets` | 三卡片 UI（说明+开关 / AUC 柱状图 / 权重调整） |

## 4. 数据采集设计

### 4.1 数据来源

帖子列表接口（现有 `URL.FORUM_THREAD_LIST`，`forumdisplay&version=4`）响应已包含所需文本字段（见附录路径），当前 `ForumThread` 接口未解析，需扩展：

```ts
// api/model/thread.ets 扩展（可选字段，向后兼容）
export interface ForumThread {
  // ...现有字段
  message?: string   // 楼主主帖内容
  reply?: Reply[]    // 前几楼回复
}
```

### 4.2 采集事件

| 事件 | 挂载点 | 采集内容 |
|---|---|---|
| 列表曝光 | `ThreadList.ets` `processThreadList()` 完成后 | 本批全部帖子：tid、fid、typeid、subject、message（前 160 字符）、reply[0..3].message（合并前 120 字符）、replies、新增回帖数（复用现有 `threadNewReplyCount` 计算）、置顶标记 |
| 帖子点击 | `ThreadList.ets` item `onClick`（约 :425）与长按 `onAction`（约 :414） | tid、时间戳 |
| 浏览时长 | `ThreadPostList.ets` 进入/离开（onShown/onHidden 或 aboutToAppear/aboutDisappear） | tid、进入时间戳、离开时间戳、本次阅读楼层数（可得则记录） |

### 4.3 曝光批次（Batch）与样本生成

- 每次列表数据到达（初次进入、翻页、刷新、缓存命中）创建一个**曝光批次**，快照本批每个帖子的特征向量与新增回帖数；
- **过滤规则**（不进入批次、不参与推荐与训练）：
  - 置顶帖（`displayorder == top`）；
  - 用户已看过（存在于浏览历史）且自上次查看以来新增回帖数为 0 的帖子；
  - **从未看过的帖子参与**（已确认）：视为全新内容，其"新增回帖"特征按全部回帖数处理；
- **正样本**：点击帖子后，在离开帖子详情页时生成（携带浏览时长），标签 y=1，样本权重见 §6.3。同批内该 tid 移出待定集合；
- **负样本**：批次关闭时，批内剩余未点击（且非 pending 点击）的帖子各生成一条，y=0。批次关闭触发条件：同版面下一次列表数据到达 / 版面切换（fid 变化）/ 列表页销毁 / 距批次创建超过 30 分钟；
- 跨批次重复曝光：同一 tid 重复曝光未点击仍产生负样本，但权重按 `1/sqrt(累计曝光次数)` 衰减，避免反复过度惩罚；
- 批次以 `generatePageKey`（现有机制）去重，重复到达的同 key 数据不重复建批。

### 4.4 采集的数据项与用途

| 数据 | 用途 |
|---|---|
| 点击历史 | 正样本标签；重复点击次数特征 |
| 标题 + 前几楼内容 | 文本 n-gram 特征 |
| 曝光次数 | 特征（分桶）；负样本权重衰减 |
| 板块 fid / 分类 typeid | 类别特征（含交叉） |
| 重复点击某帖次数 | 特征（分桶）；正样本加权 |
| 自上次查看以来新增回帖数 | 特征（分桶）；过滤规则 |
| 帖内浏览时长 | 正样本加权 |

## 5. 特征工程（FeatureExtractor）

### 5.1 特征哈希

- 哈希函数：FNV-1a 32 位 → 取模 `2^18 = 262144` 桶；
- 稀疏存储：仅保留出现过的坐标（`Map<number, number>`），内存预算 < 2MB。

### 5.2 特征表

| 组（卡片3可调） | 特征 | 构造 | 值 |
|---|---|---|---|
| — | 偏置 | `bias` | 1 |
| board 板块 | 板块 | `fid=<fid>` | 1 |
| type 分类 | 分类 | `type=<typeid>`；交叉 `fidtype=<fid>\|<typeid>` | 1 |
| titleText 标题文本 | 标题字符 1+2-gram | 前缀 `t:` + ngram 哈希 | 子线性 TF：`1+ln(tf)` |
| contentText 正文文本 | 主帖前 160 字符 + 前 3 楼合并前 120 字符的 1+2-gram | 前缀 `m:`（主帖）/ `r:`（回复） | 子线性 TF |
| hot 热度 | 回帖总量 | `replies=b<log10(replies) 取整>` | 1 |
| hot 热度 | 曝光次数 | `expo=b0(1)/b1(2-4)/b2(5+)` | 1 |
| fresh 新增互动 | 新增回帖数 | `new=b0(1-5)/b1(6-20)/b2(21-50)/b3(51+)`（未看过帖取全部回帖数入桶） | 1 |
| history 历史行为 | 该帖历史点击次数 | `clk=b0(1)/b1(2+)` | 1 |

说明：

- 文本先做归一化：去 BBCode 标签、URL、连续空白；截断到上述长度上限；
- 单帖特征非零数约 150~300，满足推理低计算量要求；
- 特征向量在**曝光时刻快照**存入批次，正/负样本统一使用快照（保证训练-推理一致性，浏览时长只影响样本权重）；
- tid 本身**不作为特征**（避免记忆单帖，保证泛化到新帖）。

### 5.3 分组与卡片3的推理期乘数

6 个特征组（board / type / titleText / contentText / hot / fresh / history 中，卡片3 提供组级乘数）：

- 训练时**不乘**组权重（保持模型学习的一致性，AUC 指标可比）；
- 推理打分时，组内特征贡献乘以用户可调乘数 `w_group`（默认 1.0，范围 0~2）。

### 5.4 文本 n-gram 特征缓存（tid 键，内存）

对 titleText / contentText 两组文本特征建立以 tid 为键的内存缓存，加速曝光快照与推理打分：

- **依据**：帖子标题与已发表楼层内容不可变（默认无后续更新），同 tid 的文本 n-gram 特征一旦计算即可终身复用，无需失效逻辑；
- **键/值**：`tid` → 文本归一化 + 1+2-gram 切分 + 哈希后的稀疏特征列表（含子线性 TF 值，titleText 与 contentText 分列表存）；
- **命中路径**：曝光建批快照与推理打分共用该缓存，命中时跳过文本归一化/n-gram 切分/哈希全程（这是文本特征的主要开销）；
- **淘汰**：进程内 LRU，上限 500 条（约 10 页列表），超出淘汰最久未访问项；
- **不持久化**：缓存仅存内存，重启后按需重算（未命中时单帖重算 < 1ms，代价可忽略），不进入 §9.2 模型文件；
- **范围**：仅文本特征进缓存；board/type/hot/fresh/history 等特征随时间变化（回帖数、曝光次数、点击次数），每次现算（本身仅为字符串拼接与查表，开销可忽略）。

## 6. 模型与训练（FtrlModel）

### 6.1 FTRL-Proximal 更新规则

对每个样本（稀疏特征 x，标签 y ∈ {0,1}，样本权重 s）：

```
p = sigmoid(Σ w_i · x_i)                     // 预测
g_i = (p − y) · x_i · s                      // 梯度（并入样本权重）
w_i = ( |z_i| ≤ λ1 ) ? 0
      : −(z_i − sign(z_i)·λ1) / ( λ2 + (β + √n_i)/α )
σ_i = (1/α) · ( √(n_i + g_i²) − √n_i )
z_i ← z_i + g_i − σ_i · w_i
n_i ← n_i + g_i²
```

超参数默认值：`α=0.15, β=1.0, λ1=1e-5, λ2=1.0`（弱 L1：单用户样本量小，过强 L1 会把特征过早归零；存储于模型文件，不暴露 UI）。

### 6.2 更新时机

- 正样本：离开帖子详情页时（含 dwell 信息）立即更新；
- 负样本：批次关闭时批量更新（每条一次，50 帖上限约几十次 update，微秒级/条）；
- 更新在 ArkTS 主线程同步执行即可（单次微秒级）；若实测批次关闭更新超过 16ms，再降级为 TaskPool。

### 6.3 样本权重（点击+时长加权，已确认）

正样本基础权重 1，累进叠加，上限 2：

| 条件 | 权重增量 |
|---|---|
| 浏览时长 ≥ 30s | +0.5 |
| 浏览时长 ≥ 120s | 再 +0.5 |
| 该帖历史点击 ≥ 2 次（重复回访） | +0.5 |
| 浏览时长 < 5s（快速退出，疑似误触） | 总权重强制 0.5 |

负样本权重：`1 / sqrt(该帖累计曝光次数)`。

### 6.4 评估：滚动 AUC（prequential）

- 曝光打分时记录 `(预测分数 p, 后续标签 y)`，进入滚动缓冲（最近 500 条）；
- 每次批次关闭后基于缓冲计算无权 AUC（Mann-Whitney U 秩统计，n=500 时 O(n log n) 可忽略）；
- 每次评估结果 push 进 AUC 历史（保留最近 30 条，持久化，供卡片2 柱状图）。

### 6.5 冷启动与激活状态机

```
COLLECTING（采集中）
  条件A：累计点击样本 ≥ 40 且 总样本 ≥ 300
  条件B：最近一次 AUC ≥ 0.65 且 缓冲内正样本 ≥ 20
  A∧B → ACTIVE（开始高亮）
ACTIVE（已激活）
  持续训练；若连续 5 次评估 AUC < 0.55 → DEGRADED（暂停高亮，继续学习）
DEGRADED（降级观察）
  再次满足 条件B → 回到 ACTIVE
```

- 阈值常量集中定义，不在 UI 暴露；
- 状态与进度（样本数/点击数/当前 AUC）持久化，RecommendPage 卡片1 显示。

## 7. 推理与列表高亮

### 7.1 触发时机

`processThreadList()` 完成后（覆盖初次进入、翻页、刷新、缓存命中、@Reusable 复用加载）：

1. 过滤 eligible 帖（§4.3 规则）；
2. 逐帖特征提取 + 打分（推理期乘组权重；文本特征优先查 §5.4 tid 缓存，命中即免重算）；
3. 取 Top K（默认 3）tid 集合，供渲染查询；
4. 同批打分结果进入 §6.4 评估缓冲。

性能预算：50 帖 × ~300 稀疏特征 ≈ 1.5 万次乘加，ArkTS < 5ms，不阻塞渲染；文本缓存命中的帖子（同版面翻回、刷新、缓存加载的常见场景）进一步跳过 n-gram 切分与哈希开销。

### 7.2 高亮 UI

挂载点：`ThreadList.ets` item 最外层 `Row()`（约 :368）内、`Text`（约 :369）之前：

- 统一渲染固定宽度 6vp 的左侧指示区容器（所有 item 一致，避免高亮帖文本偏移 3vp 造成跳动）；
- 高亮帖：指示区内显示 3vp 宽、14vp 高、圆角 2vp 矩形，颜色 `appTheme.fontEmphasize`（与回复数高亮同色，参考现有用法 `ThreadList.ets:383-388`）；
- 非高亮帖：指示区空白；
- 相应 `Text` 的 `padding.left` 由 18 调整为 12，保持视觉边距不变；
- 置顶帖永不显示指示矩形。

### 7.3 开关联动

- 总开关关闭：不采集、不训练、不高亮，保留已训练模型；
- 重新开启：从上次模型继续；
- `ThreadList` 渲染时通过 `RecommendManager` 查询开关与 topK 集合；开关切换后已渲染列表不重算，下次列表数据到达时生效（可在 spec 实现时以 `Event` 通知主动清除高亮，见 §10）。

## 8. 推荐系统页面（RecommendPage）

### 8.1 路由注册（三件套）

1. `pages/NavDest/RecommendPage.ets`：`@Component struct RecommendPage` + `@Builder export function RegisterBuilder()` + `export function openRecommend(pathStack)`；
2. `PageNameEnum.ets`：`Recommend = 'Recommend'`；
3. `route_map.json`：`{ "name": "Recommend", "pageSourceFile": "src/main/ets/pages/NavDest/RecommendPage.ets", "buildFunction": "RegisterBuilder" }`。

页面结构沿用模板：`NavDestination() { OuterScroller() { TitleBar(...) + 卡片列表 } }.hideTitleBar(true).onReady(...)`，卡片用 `RoundPanel` 风格 `Column`（与 `Preferences.ets` 设置组一致）。

### 8.2 卡片1：功能说明 + 总开关

- 说明文案：简要描述"本地学习你的浏览偏好，自动高亮你可能感兴趣的帖子；所有数据仅保存在本机"；
- 总开关：`Toggle(ToggleType.Switch)`，`onChange` 中 `PreferenceManager.modify(conf => { conf.recommend_enabled = isOn; this.appState.recommend_enabled = isOn })`（照抄 `Preferences.ets` 内联 Toggle 模式）；
- 状态行：模型状态（采集中 xx/300 样本 · 点击 xx/40 / 已激活 / 观察中）、当前 AUC；
- "重置模型"文字按钮：清空模型与历史（二次确认 AlertDialog）。

### 8.3 卡片2：历史预测准确率（柱状图）

- 每根柱 = 一次批次关闭时的 AUC 评估值（最近 30 次评估，横向滚动或展示最近 12 根）；
- 纵轴固定 0.5~1.0 映射柱高，0.5 处画基线；
- **冷启动阈值线**：0.65 处画一条贯穿整个柱状区的水平虚线（`appTheme.fontEmphasize`），右端带文字标注"冷启动阈值 0.65"，柱顶达到/越过该线即代表该次评估满足激活条件B；实现方式为叠加在柱状 Row 上的绝对定位 `Divider`/`Line` + `Text`；
- 柱色 `appTheme.fontEmphasize`，触达阈值前的柱用 `appTheme.fontSecondary` 区分；
- 实现用 `Row` + 等宽 `Column`（高度按 AUC 线性映射），不引入图表库；
- 未激活阶段：显示采集进度条（样本数/门槛）替代柱状图。

### 8.4 卡片3：各项权重调整

- 6 个特征组乘数 Slider（范围 0~2，步长 0.1，默认 1.0）：板块、分类、标题文本、正文文本、热度、新增互动；（history 组乘数同样暴露）
- 每行：组名 + 当前值 + Slider；
- 变更写入 `ApplicationConfig` 并同步 `RecommendManager` 内存缓存，下次列表打分生效；
- Top K 选择：`SegmentButton`（1/2/3/4/5，默认 3），照抄 `common/component/preference/` 模式。

### 8.5 侧边栏入口

`SideMenu.ets` 菜单 `Column`（约 :262-308）中，"历史记录"之后、`Divider` 之前插入：

```
this.MenuButton($r('app.media.xxx'), '推荐系统', () => openRecommend(this.pathStack))
```

图标：新增 svg 于 `resources/base/media/`（如 sparkles/wand 类），风格与现有线性图标一致。

## 9. 配置与持久化

### 9.1 ApplicationConfig 新字段（`config/v1/default.ets`）

```
recommend_enabled: boolean = false
recommend_top_k: number = 3
recommend_weights: RecommendWeights = { board:1, type:1, titleText:1, contentText:1, hot:1, fresh:1, history:1 }
```

- `RecommendWeights` 为 class 定义（ArkTS 需显式类型）；
- 旧版本备份导入：新字段缺失由默认值静默补齐，符合现有迁移约定，无需 adapter；
- `PreferenceState` 仅增加 `recommend_enabled`（列表高亮 UI 实时联动必需），`recommend_top_k` / `recommend_weights` 由 `RecommendManager` 在 `modify` 时同步自身内存缓存，避免 appState 膨胀。

### 9.2 模型持久化（JsonPersist）

- bucket：`recommend`，key：`<uid>/model`（未登录用 `guest`；账号切换时重新加载，参照 `HistoryDbSetUser` 时机）；
- 内容：z/n 两个坐标 Map（**w 不存**，由 §6.1 公式从 z,n 重导）、超参、计数器（曝光/点击统计、tid→曝光次数、tid→点击次数，各自 LRU 裁剪至 2000 条）、AUC 历史、评估缓冲、状态机状态；
- 写入时机（节流）：批次关闭 / AUC 评估后 / 正样本更新后合并为每分钟至多一次 + 状态变更立即写；
- 体积控制：持久化前清理 `|w| < 1e-4` 且 `n` 长期未增长的坐标；预估 < 1MB。

## 10. 代码改动清单

新增文件：

| 文件 | 内容                                                  |
|---|-----------------------------------------------------|
| `common/recommend/FeatureExtractor.ets` | 文本归一化、1+2-gram、FNV-1a 哈希、数值分桶、特征组标记、tid 文本特征 LRU 缓存 |
| `common/recommend/FtrlModel.ets` | FTRL-Proximal、sigmoid 打分、AUC                        |
| `common/recommend/RecommendManager.ets` | 单例：批次/样本/训练调度/激活状态机/持久化/配置缓存/查询 API                 |
| `pages/NavDest/RecommendPage.ets` | 三卡片页面 + RegisterBuilder + openRecommend             |
| `resources/base/media/recommend.svg` | 侧边栏图标，两个四角星星斜向排布，一大一小                               |

修改文件：

| 文件 | 改动 |
|---|---|
| `api/model/thread.ets` | `ForumThread` 增加可选 `message`、`reply` 字段 |
| `pages/NavProvider/ThreadList.ets` | 曝光埋点（processThreadList 内）、点击埋点（onClick :425 / 长按 :414）、左侧指示区渲染、查 topK 集合 |
| `pages/NavDest/ThreadPostList.ets` | 进入/离开详情页记录 dwell，回调 RecommendManager |
| `pages/NavProvider/SideMenu.ets` | "推荐系统"入口 |
| `pages/PageNameEnum.ets` | `Recommend` 枚举 |
| `resources/base/profile/route_map.json` | 注册 Recommend |
| `config/v1/default.ets` | §9.1 三个字段 + `RecommendWeights` class |
| `pages/NavProvider/NavigationPage.ets` | `PreferenceState.recommend_enabled` 三处（接口/初始化/readonly 同步） |
| `common/Events.ets` | `RecommendStateChanged`（开关切换通知列表清除高亮）、`RecommendModelUpdated`（页面打开时刷新状态，可选） |

## 11. 边界情况

| 场景 | 处理 |
|---|---|
| 未登录浏览 | uid 用 `guest`，功能照常 |
| 账号切换 | 加载对应 uid 模型，互相隔离 |
| 列表数据来自缓存 | 仍计曝光（用户确实看到了），批次照常 |
| 同 key 数据重复到达 | `generatePageKey` 去重，不重复建批 |
| 点击后直接杀进程（无 dwell） | 下次曝光批次关闭时以 w=1 兜底补生成正样本 |
| 模型文件损坏/解析失败 | 重置为初始模型，状态回 COLLECTING |
| 功能关闭 | 停止采集/训练/高亮，保留模型与历史 |
| 冷启动长期不达标 | 卡片1 持续显示进度，不报错；AUC 历史照常记录 |

## 12. 验收标准

1. 总开关默认关闭；开启后浏览行为无感知（列表加载无可感知卡顿，曝光打分 < 5ms/批）；
2. COLLECTING 阶段卡片1 可见采集进度；达到 §6.5 条件后自动进入 ACTIVE；
3. ACTIVE 后每次列表曝光至多 K 个高亮矩形，全部满足过滤规则（非置顶、非"已看过且无新增"）；
4. 卡片2 柱状图正确反映 AUC 历史与 0.65 阈值线；卡片3 权重与 K 调整后下次列表生效；
5. 重置模型后回到初始状态；
6. ArkTS 严格模式：无 `any`、对象字面量显式类型、`as` 断言精确；
7. 新页面三件套齐全（PageNameEnum / route_map / RecommendPage），`PreferenceManager.readonly` 回调内无修改。

## 附录：数据字段路径（forumdisplay v4）

```
GET <URL.BASE>index.php?module=forumdisplay&version=4&filter=typeid&fid=<fid>&page=<n>&typeid=&tpp=50

$.forum_threadlist[*].subject          # 帖子标题
$.forum_threadlist[*].message          # 楼主主帖内容
$.forum_threadlist[*].reply[0:3].message  # 前 3 楼回复内容
```

其余已有字段：`tid / fid / typeid / replies / displayorder` 等见 `api/model/thread.ets`。
