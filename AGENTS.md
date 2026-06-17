# AGENTS.md

为 AI 协作者（以及新接手的开发者）梳理本项目的关键约定。本文件描述架构、目录职责，以及修改各类功能时必须遵守的模式。与代码不一致时，以代码为准。

## 项目概述

S1-Orange 是一个为 HarmonyOS Next 开发的 [stage1st.com](https://stage1st.com/) 论坛第三方客户端，使用 **ArkTS**（ArkUI 的 TS 方言，强制静态类型）与 stage 模型。最低 SDK 版本 12。无后端，所有数据来自论坛 web/app 接口或本地存储。

- 构建：`hvigorw`（DevEco Studio 工具链）。仓库根有 `hvigor`、`hvigorfile.ts`、`build-profile.json5`（根）与 `entry/build-profile.json5`（模块）。命令行构建需 Node + hvigorw，IDE 内构建即可。AI 协作者不要自行运行构建命令，除非用户明确要求。
- 版本信息：`BuildProfile`（ArkTS 编译期注入，`import BuildProfile from 'BuildProfile'`）提供 `VERSION_NAME`、`gitHeadHash`、`gitHeadDate`、`buildDate` 等。这些字段在 `entry/build-profile.json5` 的 `arkOptions.buildProfileFields` 中定义（当前为空对象，其余由 DevEco 默认注入）。

## 目录结构（`entry/src/main/ets`）

```
entryAbility/EntryAbility.ets   UIAbility 入口：初始化各存储/管理器、窗口与安全区
pages/
  NavProvider/                  Navigation 容器内的"首页/侧边栏"层
    NavigationPage.ets          @Entry。提供 pathStack / appTheme / appState(PreferenceState) / sideMenuShow
    ForumGroup.ets, ThreadList.ets  两个首页内容
    SideMenu.ets                侧边栏（账号、收藏、设置、关于 等）
  NavDest/                      NavDestination 子页面（每个对应 PageNameEnum + route_map.json 的一项）
    Preferences.ets  设置页   BlockList.ets  黑名单   DarkRoom.ets  小黑屋
    AboutApp.ets     关于     ThreadPostList.ets  帖子   UserSpace.ets  用户空间   …
  PageNameEnum.ets             所有 NavDest 页面名枚举（需与 route_map.json 的 name 对应）
config/
  UserConfig.ets                PreferenceManager：对 @kit.ArkData.preferences 的 Proxy 包装
  v1/default.ets                ApplicationConfig（全部配置字段 + 默认值）与各类枚举
api/
  base.ets                      URL 枚举（所有接口路径与域名）
  request.ets                   request<T> 链式请求封装（基于 @kit.RemoteCommunicationKit rcp）
  model/                        接口数据模型
common/
  component/                    可复用 UI 组件
    preference/                 设置项专用 SegmentButton 组件（见下"设置项模式"）
    TitleBar.ets, OuterScroller.ets, Avatar.ets, BottomSafeArea.ets …
  dataStore/                    本地持久化：HistoryData, DraftData, ApiCacheData, BlockUser, SmilyCache, JsonPersist…
  theme/basic/                  AppThemeColor 主题色（浅色/深色 + 多种配色）
  fontSize/FontSizeEnum.ets     按 16 为基准的字体倍率表
  Animation.ets, Events.ets, Constants.ets(PropKey/SafeArea), WantUitl.ets(浏览器跳转)
```

## 导航与新增页面

新增一个 NavDest 子页面的完整步骤：

1. 在 `pages/NavDest/` 新建 `XxxPage.ets`，`@Component export struct XxxPage`，并导出：
   - `@Builder export function RegisterBuilder() { XxxPage() }`
   - `export function openXxx(pathStack: NavPathStack)`，内部调用 `openOrJumpTo(pathStack, PageNameEnum.Xxx)`。
2. 在 `pages/PageNameEnum.ets` 增加枚举值 `Xxx = 'Xxx'`。
3. 在 `resources/base/profile/route_map.json` 的 `routerMap` 增加：`{ "name": "Xxx", "pageSourceFile": "src/main/ets/pages/NavDest/XxxPage.ets", "buildFunction": "RegisterBuilder" }`。
4. 页面结构以 `NavDestination() { OuterScroller() { TitleBar(...) ... } }.hideTitleBar(true).onReady(ctx => { this.pathStack = ctx.pathStack; ... })` 为模板（参考 `DarkRoom.ets`、`BlockList.ets`）。

## 配置体系（PreferenceManager）

- 单例：`import { PreferenceManager } from '../../config/UserConfig'`。
- **读**：`PreferenceManager.readonly(conf => { ... })` —— 仅读，**不要在回调里改 conf**，否则会与持久化不同步。
- **写**：`await PreferenceManager.modify(conf => { conf.xxx = v; this.someState = v })` —— 回调中对 `ApplicationConfig`（`conf`）的改动会自动 flush。`modify` 可被 await 以保证后续读到新值。
- 新增配置字段：在 `config/v1/default.ets` 的 `class ApplicationConfig` 加字段并给默认值。若需要 UI 实时联动，把字段也加进 `NavigationPage.ets` 的 `PreferenceState` 接口 + `appState` 初始化 + `aboutToAppear` 的 `readonly` 读取（参考 `updateCheckInterval`、`fontSize`、`hiddenPostDisplay`）。
- 配置版本迁移：在 `UserConfig.ets` 的 `init()` 中按 `version`（当前 `'3'`）写迁移分支。
- 个人数据导入导出：备份文件包含 `formatVersion` 与导出时的 `appVersion`。如果可导入导出的数据结构发生 breaking change，需要按情况为导入路径增加低版本 adapter；低版本缺失的配置项应继续由 `ApplicationConfig` 默认值静默补齐。

## 设置项模式（SegmentButton）

设置页 `Preferences.ets` 的每个分段选择项都遵循同一套件，**强烈建议照抄**：

1. 新建 `common/component/preference/XxxPref.ets`，仿 `AvatarCachePref.ets` / `HiddenPostPref.ets`：
   - 用 `@kit.ArkUI` 的 `SegmentButton` + `SegmentButtonOptions.capsule(...)`；
   - `@State @Watch('selectedChanged') xxxSelected: XxxEnum[] = []`；
   - `aboutToAppear` 里 `PreferenceManager.readonly(conf => this.xxxSelected.push(conf.xxx))`；
   - `selectedChanged` 里 `PreferenceManager.modify(conf => { this.xxxSelected.forEach(v => { conf.xxx = v; this.appState.xxx = v }) })`。
2. 在 `Preferences.ets` 用 `SettingGroupHeader` + `Column().attributeModifier(new RoundPanel(...))` 包一组，行用 `Row().attributeModifier(this.settingRow)`，描述文字用 `Text(...).attributeModifier(this.textSecondary)`。

## 请求层（api/request.ets）

`request<T>` 是链式 builder，基于 `rcp`：

```ts
const data = await new request<RespType>(URL.SOME_PATH)   // 第二参 base，默认 URL.BASE
  .param('key', 'value')        // query 参数
  .toText() | .toJSON() | .ensureJSON()   // 响应处理
  .formHash() | .appToken()     // 注入鉴权
  .cache(cb, updateCacheOnly?, fromCacheOnly?)  // 本地缓存
  .get() | .post(content)       // 发起请求
```

- `URL` 枚举（`api/base.ets`）列出所有接口路径与域名（`WEB_BASE` / `BASE` mobile api / `APP_BASE` app api）。
- 新增接口：在 `URL` 加路径常量，按返回类型选用 `.toJSON()` / `.toText()`；mobile api（`URL.BASE`）响应若含 `Variables.notice` 会自动更新全局通知。
- 会话数上限 16，框架内有用队列做重试，无需自行处理。

## 全局状态与跨组件通信

- `@Provide`/`@Consume`：`pathStack`（`PropKey.pathStack`）、`appTheme`（`AppThemeColor`）、`appState`（`PreferenceState`）、`sideMenuShow`、`forumInfo` 由 `NavigationPage` 提供，子页面 `@Consume` 即可。
- `AppStorage` + `@StorageProp`：用于跨 Ability 的值，如 `PropKey.userId`（`'storageUserId'`）、`PropKey.currentColorMode`、`SafeArea.top/bottom/keyboard`。
- **事件总线** `context.eventHub`：定义在 `common/Events.ets` 的 `Event` 枚举。发送 `context.eventHub.emit(Event.Xxx, payload)`，接收 `context.eventHub.on(Event.Xxx, (payload) => {...})`。新增事件记得加进 `Event` 枚举。

## UI 约定

- **主题色**：统一用 `@Consume appTheme: AppThemeColor`，取 `appTheme.backgroundPrimary/Secondary/Tertiary`、`appTheme.fontPrimary/Secondary`、`appTheme.titleBar/titleBarFont`、`appTheme.fontEmphasize`。勿硬编码颜色。
- **字体**：用 `FontSizeEnum[this.appState.fontSize]` 查表（`.vp12 ~ .vp56`、`.ratio`），保证随用户字号设置缩放。
- **标题栏**：`TitleBar({ titleContent, useRightMenu, clickLeftButton })`，支持尾部 `@BuilderParam contentBuilder`（渲染在标题与右侧菜单之间，参考 `FavoriteList.ets` 的分页器、`DarkRoom.ets` 的页数显示）。
- **页数/分页指示器**：标题栏右侧统一用 `common/component/PageSlider.ets`（`当前/总数`，点击弹 `SlideDialog` 跳转）。仅展示不可跳转时传 `clickable: false`；总页数未知时传 `hideTotal: true`（显示 `当前/...`）。不要为类似需求另造样式。
- **滚动嵌套**：长列表用 `List().nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.PARENT_FIRST })` 配合外层 `OuterScroller`。
- **懒加载列表**：继承 `BasicDataSource<T>`（`common/BasicDataSource.ets`），实现 `totalCount`/`getData`，在 `getData` 中按 `threshold` 触发 `loadMore`，加载完调 `notifyDataReload()`。
- **其它色彩**： 尽量避免使用hex颜色，优先查看项目内类似场景用法，或是系统内置色$r('sys.color.XXX')

## 其它注意事项

- **启动时序/初始化**：`EntryAbility.onCreate` 里调用各 `*Init`/`*DbInit`（包括 `PreferenceManager.init`），这些是异步的、`onCreate` 返回时**未必完成**。因此任何依赖存储已就绪的逻辑（如读配置、检查更新）**不要**放在 `EntryAbility` 中，否则会因首选项/数据库未初始化而报错。正确位置是 `NavigationPage.aboutToAppear` 内 `PreferenceManager.readonly` 的回调体——此时各存储已初始化完毕，且该回调保证读到的是已 flush 的配置。需要 UI 的弹窗也在此处可用（`promptAction` 等已就绪）。
- ArkTS 严格模式：避免 `any`、对象字面量需显式类型、`as` 断言要精确。
- Windows 环境：路径用 `\`，shell 为 `cmd.exe`；`findstr` 替代 `grep`，无 `head/tail`。
- 资源（图片/字符串）：`$r('app.media.xxx')`、`$r('app.string.xxx')`，文件在 `entry/src/main/resources/base/media|element`。
- 提交前自检：新增页面是否三处齐全（PageNameEnum / route_map.json / XxxPage.ets）；新增配置是否同时进了 `ApplicationConfig` 与（需要时）`PreferenceState`；`PreferenceManager.readonly` 内严禁修改。
- 非必要勿新增注释，通常变量名已足够表达代码逻辑。
