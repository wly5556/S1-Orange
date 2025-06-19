import { URL } from '../../api/base'
import request from '../../api/request'
import { openPostRatingDetail, PostRatingDetailParam, PostRatingPopData } from '../../pages/NavDest/PostRatingDetail'
import { openUserSpace, UserSpaceParam } from '../../pages/NavDest/UserSpace'
import { PreferenceState } from '../../pages/NavProvider/NavigationPage'
import { AniSpeed } from '../Animation'
import { PropKey } from '../Constants'
import { blockUserList } from '../dataStore/BlockUser'
import { FontSizeEnum } from '../fontSize/FontSizeEnum'
import { AppThemeColor } from '../theme/basic/basic'
import { Avatar } from './Avatar'

export const POST_RATING_SLICE_SIZE = 10

@Component
export struct PostRating {
  @Consume(PropKey.pathStack) pathStack: NavPathStack
  pid: string = ''
  tid: string = ''
  @State rating: Rating[] = []
  @State totalRating: number = 0
  @State userCount: number = 0
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  @Consume postRatingInfo: Map<string, ThreadRatingInfo | undefined>
  compTransitionId = 'PostRating'

  aboutToAppear(): void {
    this.reload()
  }

  async reload(force = false) {
    const ratingItem = this.postRatingInfo.get(this.pid)
    let rating: ThreadRatingInfo
    if (ratingItem == undefined || force) {
      rating = await requestRating(this.pid, this.tid)
      this.postRatingInfo.set(this.pid, rating)
    } else {
      rating = ratingItem
    }
    this.rating = rating.rating
    this.totalRating = rating.totalRating
    this.userCount = rating.userCount
  }

  build() {
    if (this.userCount > 0) {
      PostRatingPanel({
        appTheme: this.appTheme,
        appState: this.appState,
        userCount: this.userCount,
        totalRating: this.totalRating,
        rating: this.rating,
        transitionIndex: this.compTransitionId,
        maxItem: POST_RATING_SLICE_SIZE,
        seeMoreButton: true,
        context: this.getUIContext(),
        pathStack: this.pathStack,
        seeMore: () => {
          const param: PostRatingDetailParam = {
            rating: this.rating,
            pid: this.pid,
            tid: this.tid,
            userCount: this.userCount,
            totalRating: this.totalRating,
            transitionId: this.compTransitionId
          }
          openPostRatingDetail(this.pathStack, param, (data: PopInfo) => {
            if ((data.result as PostRatingPopData).ratingChanged) {
              this.reload(true)
            }
          })
        }
      })
    }
  }
}


export interface PostRatingPanelData {
  appTheme: AppThemeColor,
  appState: PreferenceState,
  userCount: number,
  totalRating: number,
  rating: Rating[],
  maxItem?: number,
  seeMoreButton?: boolean,
  seeMore?: () => void,
  transitionIndex: string,
  context: UIContext,
  pathStack: NavPathStack
}

@Builder
export function PostRatingPanel(data: PostRatingPanelData) {
  Column({ space: 8 }) {
    Row() {
      Text('评分')
        .fontWeight(FontWeight.Bold)
        .fontSize(FontSizeEnum[data.appState.fontSize].vp22)
        .fontColor(data.appTheme.themeColorDarken)
      Text(`参与人数 ${data.userCount}`).opacity(0.6).fontSize(FontSizeEnum[data.appState.fontSize].vp16)
      Text(`战斗力 ${data.totalRating >= 0 ? '+' : ''}${data.totalRating}`)
        .opacity(0.6)
        .fontSize(FontSizeEnum[data.appState.fontSize].vp16)
      if (data.seeMoreButton) {
        Text('查看全部')
          .opacity(0.7)
          .fontColor(data.appTheme.fontEmphasize)
          .onClick(data.seeMore)
          .fontSize(FontSizeEnum[data.appState.fontSize].vp16)
      }
    }.justifyContent(FlexAlign.SpaceBetween)
    .width('100%')

    ForEach(data.rating, (item: Rating, index: number) => {
      if (!data.maxItem || index < data.maxItem) {
        Row() {
          Row({ space: 12 }) {
            Avatar({
              uid: item.uid,
              avatarSize: FontSizeEnum[data.appState.fontSize].vp22,
              transitionIndex: 'avatar' + index + data.transitionIndex
            })
            Text(item.username).width('25%').ratingText(FontSizeEnum[data.appState.fontSize].vp13).maxLines(1)
            Text(item.count).width('10%').ratingText(FontSizeEnum[data.appState.fontSize].vp13).maxLines(1)
          }.onClick(e => {
            const userSpaceParam: UserSpaceParam = {
              uid: item.uid,
              username: item.username,
              avatarTransitionIndex: 'avatar' + index + data.transitionIndex
            }
            openUserSpace(userSpaceParam, data.pathStack)
          }).constraintSize({
            minHeight: FontSizeEnum[data.appState.fontSize].vp22
          })

          Text(blockUserList[item.uid] ? '[已被屏蔽]' : item.comment)
            .layoutWeight(1)
            .ratingText(FontSizeEnum[data.appState.fontSize].vp13)
            .constraintSize({
              minHeight: FontSizeEnum[data.appState.fontSize].vp22
            })
        }.width('100%').alignItems(VerticalAlign.Top)
      }
    }, (item: Rating) => item.uid)
  }.margin({ top: 20 })
  .geometryTransition(data.transitionIndex, { follow: true })
  .alignSelf(ItemAlign.End)
  .transition(TransitionEffect.OPACITY.animation({ duration: AniSpeed.ms100 }))
}

@Extend(Text)
function ratingText(fontSize: number) {
  .fontSize(fontSize).opacity(0.7)
}

export interface Rating {
  count: string,
  uid: string,
  username: string,
  datetime: string,
  comment: string
}

const regex =
  /<tr>\s*<td>战斗力 (\+\d+|-\d+) 鹅<\/td>\s*<td><a href="space-uid-(\d+)\.html">([^<]+)<\/a><\/td>\s*<td>([^<]+)<\/td>\s*<td>([^<]*)<\/td>\s*<\/tr>/g

function extractRating(str: string) {
  let match: RegExpExecArray | null
  const result: Rating[] = []
  while ((match = regex.exec(str)) !== null) {
    result.push({
      count: match[1],
      uid: match[2],
      username: match[3],
      datetime: match[4],
      comment: match[5] || ''
    })
  }
  return result
}

export interface ThreadRatingInfo {
  rating: Rating[],
  totalRating: number,
  userCount: number
}

export async function requestRating(pid: string, tid: string) {
  const htmlStr = await new request<string>(URL.RATING_GET, URL.WEB_BASE)
    .param('pid', pid)
    .param('tid', tid)
    .toText()
    .get()

  const result: ThreadRatingInfo = {
    rating: extractRating(htmlStr),
    totalRating: 0,
    userCount: 0
  }

  result.rating.forEach(r => {
    if (!isNaN(parseInt(r.count))) {
      result.totalRating += parseInt(r.count)
    }
  })
  result.userCount = result.rating.length
  return result
}