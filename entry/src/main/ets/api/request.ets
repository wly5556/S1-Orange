import { BusinessError } from '@kit.BasicServicesKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { URL } from './base';
import { Queue, url } from '@kit.ArkTS';
import Account, { Notice } from './model/account';
import { promptAction } from '@kit.ArkUI';
import wrapper from './wrapper';
import { getCache, putCache } from '../common/dataStore/ApiCacheData';

const waitQueue: Queue<VoidCallback> = new Queue

function enqueueWait() {
  return new Promise<void>((res) => waitQueue.add(res))
}

async function createSession(sessionConfig: rcp.SessionConfiguration) {
  let session: rcp.Session | undefined = undefined
  while (session === undefined) {
    try {
      session = rcp.createSession(sessionConfig)
    } catch (e) {
      await enqueueWait()
      // 1007900994 会话数达到限制，当前最多可创建16个session实例。
    }
  }
  return session
}

export let userCookieString: string = ''

let userCookies: rcp.RequestCookies = {}
let userFormHash: string = ''
let userAppToken: string | undefined = undefined

interface reqError {
  type: 'Response' | 'BusinessError' | 'FromCacheOnly',
  data: rcp.Response | BusinessError | null
}

interface respError extends reqError {
  type: 'Response',
  data: rcp.Response
}

interface businessError extends reqError {
  type: 'BusinessError',
  data: BusinessError
}

interface fromCacheError extends reqError {
  type: 'FromCacheOnly',
  data: null
}

function rejectByCache() {
  const err: fromCacheError = {
    type: 'FromCacheOnly',
    data: null
  }
  return Promise.reject(err)
}

export type RequestError = respError | businessError

export default class request<T> {
  private base: string
  private path: string
  private paramString = new url.URLParams
  sessionConfig: rcp.SessionConfiguration
  private responseCookie: rcp.ResponseCookie[] | undefined;

  constructor(path: URL | string, base: URL | '' = URL.BASE) {
    this.base = base
    this.path = path
    this.sessionConfig = {
      baseAddress: base,
      cookies: userCookies,
      headers: {},
      requestConfiguration: {
        transfer: {
          autoRedirect: true,
          timeout: {
            connectMs: 3000
          }
        }
      }
    }
  }

  timeout(ms: number) {
    this.sessionConfig.requestConfiguration!.transfer!.timeout!.connectMs = ms
    return this
  }

  withoutCookie() {
    this.sessionConfig.cookies = undefined
    return this
  }

  updateCookie() {
    if (this.responseCookie) {
      this.responseCookie.forEach(c => c.value && (userCookies[c.name] = c.value))
      setUserCookieString(userCookies)
    }
  }

  resetCookie() {
    if (this.responseCookie) {
      const newUserCookies: rcp.RequestCookies = {}
      this.responseCookie.forEach(c => c.value && (newUserCookies[c.name] = c.value))
      setUserCookie(newUserCookies)
    }
    return userCookies
  }

  getCookie() {
    let cookieRecord: Record<string, string> = {}
    if (this.responseCookie) {
      this.responseCookie.forEach(c => c.value && (cookieRecord[c.name] = c.value))
      return cookieRecord
    }
    return cookieRecord
  }

  redirectLocation() {
    this.sessionConfig.requestConfiguration!.transfer!.autoRedirect = false
    return this
  }

  private respToText: boolean = false

  toText() {
    this.respToText = true
    return this
  }

  private respToJSON: boolean = false

  toJSON() {
    this.respToJSON = true
    return this
  }

  private processDirtyJson: boolean = false

  ensureJSON() {
    this.processDirtyJson = true
    return this
  }

  private withFormHash: boolean = false

  formHash() {
    this.withFormHash = true
    return this
  }

  private withAppToken: boolean = false

  appToken() {
    this.withAppToken = true
    return this
  }

  private cacheCallback?: (data: T) => void
  private cacheKey?: string
  private putCacheOnly = false
  private fromCacheOnly = false

  /**
   * 从本地文件中提前获取响应。仅支持json。不会立即查找缓存，而是直到get()或post()被调用时再查找
   * @param callback 回调，data与从get()或post()方法获得的响应类型一致
   * @param updateCacheOnly 仅更新缓存， callback不会被调用
   * @param fromCacheOnly 仅从本地缓存中获取，仍需调用get()或post()来开始请求缓存，但将返回Promise.reject(fromCacheError)
   */
  cache(callback: (data: T) => void, updateCacheOnly = false, fromCacheOnly = false) {
    this.putCacheOnly = updateCacheOnly
    this.cacheCallback = callback
    this.fromCacheOnly = fromCacheOnly
    return this
  }

  private wrapper(request: (session: rcp.Session) => Promise<rcp.Response>) {
    return new Promise<T>(async (fulfill, reject) => {
      const session = await createSession(this.sessionConfig)
      request(session).then(resp => {
        if (resp === undefined) {
          throw new Error('network error')
        }
        this.responseCookie = resp.cookies
        this.updateCookie()
        if (resp.statusCode == 200) {
          if (resp.headers['content-type']?.includes('application/json') || this.respToJSON) {
            let data: T
            if (this.processDirtyJson) {
              const jsonRegex = /\{.*?\}/s
              const respString = resp.toString()
              if (respString === null) {
                const err: reqError = {
                  type: 'Response',
                  data: resp
                }
                reject(err)
                return
              }
              const match = respString.match(jsonRegex)
              if (match && match.length == 1) {
                data = JSON.parse(match[0]) as T
              } else {
                const err: reqError = {
                  type: 'Response',
                  data: resp
                }
                reject(err)
                return
              }
            } else {
              data = resp.toJSON() as T
            }
            const webApiData = data as wrapper<Account>
            if (webApiData?.Variables?.notice) {
              setUserNotice(webApiData.Variables.notice)
            }
            if (webApiData?.Variables?.error) {
              promptAction.showToast({
                message: '论坛异常: ' + webApiData.Variables.error
              })
            }
            if (this.cacheKey) {
              putCache(this.cacheKey, data as Object)
            }
            fulfill(data)
          } else if (this.respToText) {
            fulfill(resp.toString() as T)
          } else {
            fulfill(resp.body as T)
          }
        } else if (this.sessionConfig.requestConfiguration!.transfer!.autoRedirect == false
          && resp.statusCode && (resp.statusCode == 301 || resp.statusCode == 302)) {
          fulfill(resp.headers.location as T)
        } else {
          const err: reqError = {
            type: 'Response',
            data: resp
          }
          reject(err)
        }
      }).catch((errObj: BusinessError) => {
        const err: reqError = {
          type: 'BusinessError',
          data: errObj as BusinessError
        }
        reject(err)
      }).finally(() => {
        session.close()
        if (waitQueue.length > 0) {
          waitQueue.getFirst()()
          waitQueue.pop()
        }
      })
    })
  }

  param(key: string, value: string) {
    this.paramString.append(key, value)
    return this
  }

  private addParams(url: string) {
    const query = this.paramString.toString()
    if (query) {
      if (!url.includes('?')) {
        url += '?'
      }
      if (!url.endsWith('?')) {
        url += '&'
      }
      url += query
    }
    return url
  }

  get(): Promise<T> {
    if (this.sessionConfig.headers && this.sessionConfig.headers['content-type'] == undefined) {
      this.sessionConfig.headers['content-type'] = 'application/json'
    }
    if (this.withFormHash) {
      this.param('formhash', userFormHash)
    }
    const path = this.addParams(this.path)
    if (this.cacheCallback) {
      this.cacheKey = this.base + path
      if (!this.putCacheOnly) {
        getCache(this.cacheKey).then(cached => this.cacheCallback && cached && this.cacheCallback(cached as T))
      }
    }
    if (this.fromCacheOnly) {
      return rejectByCache()
    }
    return this.wrapper((session: rcp.Session) => session.get(path))
  }

  private isFormData: boolean = false

  formData() {
    this.isFormData = true
    return this
  }

  post(content: rcp.RequestContent | string = ''): Promise<T> {
    if (this.sessionConfig.headers && this.sessionConfig.headers['content-type'] == undefined) {
      this.sessionConfig.headers['content-type'] = 'application/x-www-form-urlencoded'
    }
    if (this.withFormHash) {
      if (typeof content == 'string') {
        content += `&formhash=${userFormHash}`
      } else {
        (content as Record<string, string>)['formhash'] = userFormHash
      }
    }
    if (this.withAppToken) {
      if (typeof content == 'string') {
        content += `&sid=${userAppToken}`
      } else {
        (content as Record<string, string>)['sid'] = userAppToken || ''
      }
    }
    let payload: rcp.RequestContent | string
    if (typeof content == 'string') {
      payload = content
    } else if (this.isFormData) {
      payload = content
    } else {
      payload = new url.URLParams(content as Record<string, string>).toString()
    }
    const reqPath = this.addParams(this.path)
    if (this.cacheCallback) {
      let payloadString: string
      if (typeof content == 'string') {
        payloadString = content
      } else if (this.isFormData) {
        payloadString = JSON.stringify(payload)
      } else {
        payloadString = new url.URLParams(content as Record<string, string>).toString()
      }
      this.cacheKey = this.base + reqPath + payloadString
      if (!this.putCacheOnly) {
        getCache(this.cacheKey).then(cached => this.cacheCallback && cached && this.cacheCallback(cached as T))
      }
    }
    if (this.fromCacheOnly) {
      return rejectByCache()
    }
    return this.wrapper((session: rcp.Session) => session.post(reqPath, payload))
  }
}

function setUserCookieString(cookie: rcp.RequestCookies) {
  userCookieString = Object.entries(cookie)
    .filter(v => v[1] !== undefined)
    .map(v => `${v[0]}=${v[1]}`)
    .join('; ')
}

export function clearUserCookie() {
  userCookies = {}
}

export function setUserCookie(cookie: object) {
  userCookies = cookie as rcp.RequestCookies
  setUserCookieString(userCookies)
}

export function setFormHash(formhash: string) {
  userFormHash = formhash
}

export function clearFormHash() {
  userFormHash = ''
}

export function setAppToken(token: string) {
  userAppToken = token
}

export function clearAppToken() {
  userAppToken = undefined
}

let userNotice: Notice
clearUserNotice()

export function setUserNotice(notice: Notice) {
  userNotice = notice
}

export function getUserNotice() {
  return userNotice
}

export function clearUserNotice() {
  userNotice = {
    newpush: '0',
    newpm: '0',
    newprompt: '0',
    newmypost: '0'
  }
}