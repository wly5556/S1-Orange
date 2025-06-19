import { PageNameEnum } from './PageNameEnum'
import { Callback } from '@kit.BasicServicesKit'
import { AniSpeed } from '../common/Animation'

/**
 * 打开新页面或跳转到已存在的目标页面
 *
 * @param pathStack: NavPathStack
 * @param pageName: PageNameEnum  目标页面名称，对应route_map.json中的name
 * @param param  （可选）页面所需参数
 * @param animated  （可选）转场动画，默认为true，当关闭动画（AniSpeed.ratio = 0）时强制为0
 * @param equalsTo  （可选）自定义参数匹配函数，详见下面的行为描述。仅指定了equalsTo时，能用该方法打开多个同名页面
 * @param callback  （可选）对应NavPathStack.pushPathByName方法的同名参数，用于页面出栈时触发该回调处理返回结果。仅pop中设置result参数后触发
 *
 * @abstract
 * 行为：
 * - 未指定param：若栈中不存在和pageName对应的同名页，则新建；否则置顶栈中现存页面（单例行为）
 * - 指定param：当不提供equalsTo时，会清空所有同名页面后新建页面（单例行为）;当提供equalsTo时，每次向equalsTo传递页面栈中1个同名页面的param，若equalsTo返回true，则置顶该页面并结束查找。若没有查找到任何页面，则新建页面（非单例行为）
 */
export function openOrJumpTo(pathStack: NavPathStack, pageName: PageNameEnum, param?: object, animated = true,
  equalsTo?: (obj: object) => boolean, callback?: Callback<PopInfo>) {
  if (AniSpeed.ratio === 0) {
    animated = false
  }
  const pgIndex = pathStack.getIndexByName(pageName)
  let pgExisted = false
  if (pgIndex.length > 0) {
    if (param == undefined) {
      pathStack.moveIndexToTop(pgIndex[0], animated) // 无参页面应该只开1个
      return
    } else { // 有参页面匹配
      if (equalsTo) {
        pgIndex.forEach(index => {
          const pgParam: object | undefined = pathStack.getParamByIndex(index) as (object | undefined)
          if (pgParam && equalsTo(pgParam)) {
            pathStack.moveIndexToTop(index, animated)
            pgExisted = true
            return
          }
        })
      } else {
        pathStack.removeByIndexes(pgIndex)
      }
    }
  }
  if (!pgExisted) {
    pathStack.pushPathByName(pageName, param, callback, animated)
  }
}
