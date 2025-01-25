export enum SafeArea {
  top = 'SafeAreaTop',
  bottom = 'SafeAreaBottom'
}

export enum PropKey {
  currentColorMode = 'currentColorMode',
  userId = 'storageUserId',   // string | undefined, 用户系统未初始化时为undefined， 未登录时为空字符串
  pathStack = 'pathStackProvide'
}