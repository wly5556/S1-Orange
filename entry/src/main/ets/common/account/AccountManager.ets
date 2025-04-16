import { URL } from '../../api/base'
import { LoginResult as LoginResponse } from '../../api/model/login'
import request, {
  clearAppToken,
  clearFormHash,
  clearUserCookie,
  clearUserNotice,
  setAppToken,
  setFormHash,
  setUserCookie
} from '../../api/request'
import wrapper, { wrapperApp } from '../../api/wrapper'
import { PreferenceManager } from '../../config/UserConfig'
import { createOrUpdateAsset, queryAsset, removeAsset } from '../AssetStore'
import { clearThreadViewHistory, HistoryDbSetUser } from '../dataStore/HistoryData'
import Account from '../../api/model/account'
import { rcp } from '@kit.RemoteCommunicationKit'
import { LoginResultApp } from '../../api/model/app/login'
import { BlockListSetUser, clearBlockList } from '../dataStore/BlockUser'
import { promptAction } from '@kit.ArkUI'
import { clearDraft, DraftDbSetUser } from '../dataStore/DraftData'
import { waitFor } from '../AwaitUtil'
import { Event } from '../Events'
import { PropKey } from '../Constants'
import { ApiCacheSetUser, clearApiCache } from '../dataStore/ApiCacheData'
import json from '@ohos.util.json'

export enum LoginResult {
  SUCCEED,
  INVALID,
  STRIKE
}

class AssetAlias {
  prefix: string
  static list: AssetAlias[] = []

  constructor(prefix: string) {
    this.prefix = prefix
    AssetAlias.list.push(this)
  }

  get(str: string) {
    return this.prefix + ',' + str
  }
}

const cookieAssetAlias = new AssetAlias('userTokenAsset')
const appTokenAssetAlias = new AssetAlias('userAppTokenAsset')
const formhashAssetAlias = new AssetAlias('userFormhashAsset')

export async function login(username: string, password: string, questionid?: number,
  answer?: string): Promise<LoginResult> {
  let loginData: rcp.RequestContent
  if (questionid != undefined) {
    loginData = {
      username,
      password,
      questionid,
      answer
    }
  } else {
    loginData = {
      username,
      password,
    }
  }
  const appLoginResult = await new request<wrapperApp<LoginResultApp>>(URL.LOGIN_APP, URL.APP_BASE)
    .withoutCookie()
    .post(loginData)
    .then(handleAppLoginResponse)
  const req: request<wrapper<LoginResponse>> = new request(URL.LOGIN)
  const v: wrapper<LoginResponse> = await req.withoutCookie().post(loginData)
  const webLoginResult = await handleLoginResponse(v, JSON.stringify(req.getCookie()))
  if (appLoginResult == LoginResult.SUCCEED && webLoginResult == LoginResult.SUCCEED) {
    PreferenceManager.modify(conf => {
      if (conf.account_list[v.Variables.member_uid] == undefined) {
        conf.account_list[v.Variables.member_uid] = {
          name: v.Variables.member_username,
          lastSign: 0
        }
      }
    }).then(async (): Promise<void> => {
      switchAccount(v.Variables.member_uid)
    })
    return LoginResult.SUCCEED
  } else {
    return webLoginResult
  }
}

async function handleAppLoginResponse(v: wrapperApp<LoginResultApp>) {
  if (v.success) {
    await createOrUpdateAsset(appTokenAssetAlias.get(v.data.uid), v.data.sid)
    return LoginResult.SUCCEED
  }
  return LoginResult.INVALID
}

async function handleLoginResponse(v: wrapper<LoginResponse>, cookie: string) {
  if (v.Variables.auth && v.Variables.member_uid && v.Variables.member_uid.length > 0) {
    await createOrUpdateAsset(cookieAssetAlias.get(v.Variables.member_uid), cookie)
    await createOrUpdateAsset(formhashAssetAlias.get(v.Variables.member_uid), v.Variables.formhash)
    return LoginResult.SUCCEED
  } else if (v.Message.messageval == 'login_strike') {
    return LoginResult.STRIKE
  }
  return LoginResult.INVALID
}

function clearAccountState() {
  clearUserCookie()
  clearFormHash()
  clearAppToken()
  clearUserNotice()
}

export async function removeAccount(uidToRemove: string) {
  await PreferenceManager.modify(conf => {
    if (conf.account_list[uidToRemove] != undefined) {
      const accountList = conf.account_list
      conf.account_list = {}
      Object.keys(accountList).forEach(u => {
        if (u != uidToRemove) {
          conf.account_list[u] = accountList[u]
        }
      })
    }
  })
  clearThreadViewHistory(uidToRemove)
  clearDraft(uidToRemove)
  clearBlockList(uidToRemove)
  clearApiCache(uidToRemove)
  AssetAlias.list.forEach((v): Promise<void> => removeAsset(v.get(uidToRemove)))
}

export async function logout() {
  clearAccountState()
  await PreferenceManager.modify(conf => {
    conf.user_name = ''
    conf.user_uid = ''
  })
  initAccountManager()
}

export async function accountInvalid() {
  PreferenceManager.readonly(conf => {
    if (conf.user_uid) {
      promptAction.showToast({
        message: '当前登陆状态失效，请重新登录'
      })
      logout()
      getContext().eventHub.emit(Event.OpenLoginDialog)
    }
  })
}

export async function switchAccount(uid: string) {
  let switched: boolean = false
  clearAccountState()
  await PreferenceManager.modify(conf => {
    if (conf.account_list[uid] != undefined) {
      conf.user_name = conf.account_list[uid].name
      conf.user_uid = uid
      switched = true
    }
  })
  if (switched) {
    initAccountManager()
    await restoreAccountPromise
  }
}

let restoreAccountFinished: () => void = () => {
}
let restoreAccountPromise: Promise<void>

function accountPromiseReset() {
  restoreAccountPromise = new Promise(resolve => restoreAccountFinished = async () => {
    await PreferenceManager.readonly(async conf => {
      await HistoryDbSetUser(conf.user_uid)
      await DraftDbSetUser(conf.user_uid)
      await BlockListSetUser(conf.user_uid)
      await ApiCacheSetUser(conf.user_uid)
      AppStorage.setOrCreate<string>(PropKey.userId, conf.user_uid)
    })
    resolve()
  })
}

accountPromiseReset()

export function initAccountManager() {
  accountPromiseReset()
  PreferenceManager.readonly((conf): Promise<void> => (async () => {
    if (conf.user_uid && conf.user_uid.length > 0) {
      const cookie = await queryAsset(cookieAssetAlias.get(conf.user_uid))
      const appToken = await queryAsset(appTokenAssetAlias.get(conf.user_uid))
      const formhash = await queryAsset(formhashAssetAlias.get(conf.user_uid))
      if (cookie && cookie.length > 0 && appToken && appToken.length > 0 && formhash && formhash.length > 0) {
        setUserCookie(JSON.parse(cookie[0]))
        setAppToken(appToken[0])
        setFormHash(formhash[0])
        try {
          const account = await new request<wrapper<Account>>(URL.FORUM_GROUP).timeout(3000).get()
          setFormHash(account.Variables.formhash)
          await createOrUpdateAsset(formhashAssetAlias.get(conf.user_uid), account.Variables.formhash)
          dailySign()
          await PreferenceManager.modify(conf => {
            const readaccess = parseInt(account.Variables.readaccess)
            conf.readaccess = isNaN(readaccess) ? 0 : readaccess
          })
        } catch (e) {
          promptAction.showToast({
            message: '连接网络超时'
          })
        }
      }
    }
  })().finally(() => restoreAccountFinished()))
}

async function dailySign() {
  // 如果走app接口签到，还能同时更新sid，一举两得
  // 可惜app签到在sid格式改了之后就不能用了
  const now = new Date()
  const todayAtMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0)
  PreferenceManager.readonly(async conf => {
    const uidList = Object.keys(conf.account_list)
    for (const uid of uidList) {
      const user = conf.account_list[uid]
      if (user.lastSign == undefined || user.lastSign < todayAtMidnight.getTime()) {
        const formhash = await queryAsset(formhashAssetAlias.get(uid))
        const cookie = await queryAsset(cookieAssetAlias.get(uid))
        if (formhash && formhash.length > 0 && cookie && cookie.length > 0) {
          const req = new request<string>(URL.ATTENDANCE_WEB, URL.WEB_BASE)
          if (cookie && cookie.length > 0) {
            req.overrideCookie(json.parse(cookie[0]))
          }
          try {
            const sign = await req.param('formhash', formhash[0])
              .toText()
              .get()
            const signResult = extractSucceedMsg(sign)
            if (signResult || sign.includes('已签到')) {
              if (signResult) {
                promptAction.showToast({
                  message: `${conf.account_list[uid].name}: ${signResult}`,
                  duration: 2000
                })
              }
              await PreferenceManager.modify(conf => {
                conf.account_list[uid].lastSign = now.getTime()
              })
              await waitFor(2500)
            }
          } catch (e) {
          }
        }
      }
    }
  })
}

function extractSucceedMsg(input: string): string | null {
  const pattern = /succeedhandle_\w*?\('[^']*', '([^']*)',/
  const match = input.match(pattern)
  if (match && match[1]) {
    return match[1]
  } else {
    return null
  }
}
