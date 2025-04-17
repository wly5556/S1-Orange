import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { openUserSpaceByLink } from '../pages/NavDest/UserSpace';
import { openThreadPostByLink } from '../pages/NavDest/ThreadPostList';
import { ObsoleteDomain } from '../api/ObsoleteDomain';

export function openInBrowser(abilityContext: common.UIAbilityContext, url?: string) {
  if (url == undefined) {
    return
  }
  let want: Want = {
    action: 'ohos.want.action.viewData',
    entities: ['entity.system.browsable'],
    uri: url
  }
  abilityContext.startAbility(want).catch((err: BusinessError) => {
    promptAction.showToast({
      message: '跳转失败'
    })
  })
}

export function openS1LinkLike(href: string, pathStack: NavPathStack, context: common.UIAbilityContext,
  subject: string = '',
  replies: string = '1', fallbackToBrowser = true) {
  href = ObsoleteDomain.replace(href)
  openUserSpaceByLink(href, pathStack, (): void =>
  openThreadPostByLink(href, pathStack, (): void => {
    if (fallbackToBrowser) {
      openInBrowser(context, href)
    } else {
      promptAction.showToast({
        message: '未能解析链接'
      })
    }
  }, subject, replies
  ))
}