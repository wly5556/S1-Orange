export enum SafeArea {
  top = 'SafeAreaTop',
  bottom = 'SafeAreaBottom', // 整个底部的避让区高度
  keyboard = 'SafeAreaKeyboard' // 仅包含软键盘部分的避让高度
}

export enum PropKey {
  currentColorMode = 'currentColorMode',
  userId = 'storageUserId',   // string | undefined, 用户系统未初始化时为undefined， 未登录时为空字符串
  pathStack = 'pathStackProvide'
}