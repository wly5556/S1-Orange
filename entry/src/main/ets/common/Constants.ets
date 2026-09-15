export enum SafeArea {
  top = 'SafeAreaTop',
  bottom = 'SafeAreaBottom', // 整个底部的避让区高度
  keyboard = 'SafeAreaKeyboard' // 仅包含软键盘部分的避让高度
}

export enum PropKey {
  currentColorMode = 'currentColorMode',
  userId = 'storageUserId',   // string | undefined, 用户系统未初始化时为undefined， 未登录时为空字符串
  pathStack = 'pathStackProvide',
  windowWidth = 'storageWindowWidth', // number, 主窗口宽度（px），用于双栏显示判定
  noticeNewReply = 'storageNoticeNewReply', // number, 未读提醒数（notice.newmypost），0表示无提醒
  statusBarHiddenByApp = 'storageStatusBarHiddenByApp' // boolean, 应用主动隐藏了状态栏（大图放大）期间冻结顶部安全区，避免下层页面跳动
}