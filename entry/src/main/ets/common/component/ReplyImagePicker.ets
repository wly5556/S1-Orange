import { URL } from '../../api/base';
import request from '../../api/request';
import { Spring035s } from '../Animation';
import { AppThemeColor } from '../theme/basic/basic';
import { BottomSafeArea } from './BottomSafeArea';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { common } from '@kit.AbilityKit';
import { extractFileName } from '../TextUtil';
import { PreferenceState } from '../../pages/NavProvider/NavigationPage';
import { FontSizeEnum } from '../fontSize/FontSizeEnum';
import { promptAction } from '@kit.ArkUI';
import { PreferenceManager } from '../../config/UserConfig';
import { ArrayDataSource } from '../BasicDataSource';
import { RipImageItem, RipImageUpload } from '../../api/model/ripImage/sda1';
import { WriteHandler, WriteReplyMode } from '../../pages/NavDest/WriteReply';

const IMG_THUMBNAIL_HEIGHT = 150

interface ImageObjectVM {
  provider: number,
  id: string,
  url: string
}

interface UploaderState {
  errorMsg?: string
  available: boolean
  using?: string[]
  unused: string[]
}

@Component
export struct ReplyImagePicker {
  @Consume appTheme: AppThemeColor
  @Consume appState: PreferenceState
  context = getContext(this) as common.UIAbilityContext
  @State imgLoaded: Record<string, boolean> = {}
  uploaders: Uploader[] = [new AttachmentUploader(), new RipUploader()]
  uploadersDataSource: ArrayDataSource<Uploader> = new ArrayDataSource<Uploader>().reload(this.uploaders)
  @State uploaderCurrentIndex: number = 0
  @State swiperIndex: number = 0
  @State uploaderState: UploaderState[] = []
  @State imageList: ImageObjectVM[] = []
  @State unusedImage: Map<number, string[]> = new Map()
  @Prop currentMode: WriteReplyMode = WriteReplyMode.NEW_THREAD
  getWriteHandler?: () => WriteHandler
  onPicked: (text: string) => void = () => {
  }
  onRemoval: (text: string) => void = () => {
  }
  controller: SwiperController = new SwiperController()

  async upload(uris: string[]) {
    if (uris.length == 0) {
      return
    }
    this.getUIContext().getPromptAction().showToast({
      message: `正在上传，共${uris.length}张图片`
    })
    const uploaderIdx = this.uploaderCurrentIndex
    const uploader = this.uploaders[uploaderIdx]
    const limitInBytes = uploader.sizeLimitMB() << 20
    for (let i = 0; i < uris.length; i++) {
      const albumPath = uris[i]
      const file = await fs.open(albumPath, fs.OpenMode.READ_ONLY)
      const photoSize = fs.statSync(file.fd).size
      if (photoSize > limitInBytes) {
        this.getUIContext().getPromptAction().showToast({
          message: `第${i + 1}张图片超出${uploader.sizeLimitMB()}MB的大小限制，未被上传`
        })
        await fs.close(file)
        continue
      }
      const buffer = new ArrayBuffer(photoSize)
      await fs.read(file.fd, buffer)
      await fs.close(file)
      const id = await uploader.upload(extractFileName(albumPath) || 'image', photoSize, buffer)
      if (id) {
        this.addImage(id, uploaderIdx)
      }
    }
  }

  aboutToAppear(): void {
    PreferenceManager.readonly(conf => {
      let imgService = conf.image_upload_service
      imgService = Math.min(this.uploaders.length - 1, Math.max(0, imgService))
      this.swiperIndex = this.uploaderCurrentIndex = imgService
      this.initUploader(imgService)
    })
  }

  initUploader(index: number) {
    PreferenceManager.modify(conf => {
      conf.image_upload_service = index
    })
    if (this.uploaders[index].inited) {
      return
    }
    if (this.getWriteHandler) {
      this.uploaders[index].init(this.getWriteHandler(), this.currentMode).then(state => {
        this.uploaderState[index] = state
        this.unusedImage.set(index, state.unused)
        if (state.using) {
          for (const id of state.using) {
            this.addImage(id, index)
          }
        }
      })
    }
  }

  addImage(id: string, index: number) {
    this.uploaders[index].idToUrl(id).then(url => {
      this.imageList.push({
        id, url,
        provider: index
      })
    })
  }

  deleteImage(id: string, index: number) {
    return this.uploaders[index].remove(id, this.onRemoval)
  }

  build() {
    Scroll() {
      Column() {
        Tabs({ barPosition: BarPosition.Start, index: this.uploaderCurrentIndex }) {
          ForEach(this.uploaders, (item: Uploader, index: number) => {
            TabContent() {
            }.tabBar(SubTabBarStyle.of(item.getName())
              .labelStyle({ selectedColor: this.appTheme.fontEmphasize })
              .indicator({ color: '#00000000' })
            )
          })
        }.onAnimationStart((index, target) => {
          this.uploaderCurrentIndex = target
          this.controller.changeIndex(target, true)
          this.initUploader(target)
        })
        .barMode(BarMode.Scrollable)
        .scrollable(false)
        .height('auto')

        Swiper(this.controller) {
          LazyForEach(this.uploadersDataSource, (_: void, upIndex: number) => {
            if (this.uploaderState[upIndex] && this.uploaderState[upIndex].available) {
              Column() {
                if (this.unusedImage.get(upIndex)?.length) {
                  Row({ space: 8 }) {
                    Text(`您有 ${this.uploaderState[upIndex].unused.length} 个未使用的图片附件`)
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    Blank()
                    Text('查看')
                      .fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      .fontColor($r('sys.color.font_emphasize'))
                      .opacity(8)
                      .onClick(() => {
                        const unused = this.unusedImage.get(upIndex)
                        if (unused) {
                          unused.forEach((v): void => this.addImage(v, upIndex))
                          this.unusedImage.set(upIndex, [])
                        }
                      })
                    Divider().vertical(true).height(24)
                    Text('移除').fontColor(Color.Red).opacity(.8).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                      .onClick(() => {
                        const unused = this.unusedImage.get(upIndex)
                        if (unused) {
                          unused.forEach((v): Promise<boolean> => this.deleteImage(v, upIndex))
                          this.unusedImage.set(upIndex, [])
                        }
                      })
                  }
                  .margin(12)
                  .width('95%')
                  .padding(12)
                  .borderRadius(8)
                  .backgroundColor(this.appTheme.backgroundSecondary)
                }
                GridRow({
                  gutter: 24
                }) {
                  ForEach(this.imageList, (image: ImageObjectVM, index: number) => {
                    if (image.provider == upIndex) {
                      GridCol({
                        span: {
                          xs: 6,
                          md: 4,
                        }
                      }) {
                        Stack() {
                          if (!this.imgLoaded[image.id]) {
                            LoadingProgress()
                              .width(48)
                              .height(48)
                              .color($r('sys.color.ohos_id_color_emphasize'))
                              .transition(TransitionEffect.OPACITY.animation({ duration: 100 }))
                          } else {
                            Stack() {
                              Image($r('app.media.plus'))
                                .width(20)
                                .height(20)
                                .rotate({
                                  angle: 45
                                })
                            }
                            .width(30)
                            .height(30)
                            .position({ right: 10, top: 10 })
                            .zIndex(200)
                            .onClick(e => {
                              this.deleteImage(image.id, upIndex).then((confirm) => {
                                if (confirm) {
                                  animateTo(Spring035s, () => {
                                    this.imageList.splice(index, 1)
                                  })
                                }
                              })
                            })
                          }
                          Image(image.url)
                            .onComplete(() => {
                              this.imgLoaded[image.id] = true
                            })
                            .geometryTransition('attachment' + image.id, { follow: true })
                            .opacity(this.imgLoaded[image.id] ? 1 : 0)
                            .animation({ duration: 100 })
                            .objectFit(ImageFit.Contain)
                            .width('100%')
                            .height('100%')
                            .onClick(e => {
                              this.onPicked(this.uploaders[upIndex].pick(image.id))
                            })
                        }.width('100%')
                        .height('100%')
                      }.height(IMG_THUMBNAIL_HEIGHT)
                    }
                  }, (img: ImageObjectVM, index: number) => index + JSON.stringify(img))
                  GridCol({
                    span: {
                      xs: 6,
                      md: 4,
                    }
                  }) {
                    Stack() {
                      Stack() {
                        Image($r('app.media.plus'))
                          .width(60)
                          .height(60)
                          .fillColor(this.appTheme.fontPrimary)
                      }
                      .width('100%')
                      .height('100%')
                      .borderRadius(12)
                      .borderColor(this.appTheme.fontSecondary)
                      .borderWidth(2)
                      .borderStyle(BorderStyle.Dashed)
                    }
                    .padding(20)
                    .width('100%')
                    .height('100%')
                    .onClick(async () => {
                      const PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions()
                      PhotoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
                      PhotoSelectOptions.maxSelectNumber = 10
                      PhotoSelectOptions.recommendationOptions = {
                        textContextInfo: {
                          text: '文件最大' + this.uploaders[this.uploaderCurrentIndex].sizeLimitMB() + 'MB'
                        }
                      }
                      const photoPicker = new photoAccessHelper.PhotoViewPicker()
                      const photoSelectResult: photoAccessHelper.PhotoSelectResult =
                        await photoPicker.select(PhotoSelectOptions)
                      this.upload(photoSelectResult.photoUris)
                    })
                  }.height(IMG_THUMBNAIL_HEIGHT)
                }

                BottomSafeArea()
              }
            } else {
              Stack() {
                Column({ space: 12 }) {
                  if (this.uploaderState[upIndex]) {
                    Image($r('app.media.face_253_akarin')).width(40).height(40)
                    if (this.uploaderState[upIndex] && this.uploaderState[upIndex].errorMsg) {
                      Text(this.uploaderState[upIndex].errorMsg).fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    } else {
                      Text('当前不可用。请切换其它图床').fontSize(FontSizeEnum[this.appState.fontSize].vp16)
                    }
                  } else {
                    LoadingProgress()
                      .width(64)
                      .height(64)
                      .color($r('sys.color.ohos_id_color_emphasize'))
                  }
                }
              }.width('100%')
              .height('100%')
            }
          })
        }
        .index($$this.swiperIndex)
        .width('100%')
        .height('auto')
        .loop(false)
        .cachedCount(0)
        .disableSwipe(true)
        .indicator(false)
        .hitTestBehavior(HitTestMode.None)
      }.constraintSize({
        minHeight: '100%'
      })
    }.scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}

interface ReplyPageInfo {
  uid: string | null,
  tid: string | null,
  pid: string | null,
  hash: string | null,
  attachSizeLimit: string | null,
  unusedImage: string[],
  usingImage: Map<string, string>
}

export function extractReplyPageInfo(html: string): ReplyPageInfo {
  const uidRegex = /name="uid"\s+value="(\d+)"/
  const tidRegex = /name="tid"\s+value="(\d+)"/
  const pidRegex = /name="pid"\s+value="(\d+)"/
  const hashRegex = /name="hash"\s+value="([a-f0-9]+)"/
  const usingImageRegex = /<img src="(forum\.php\?[^"]+aid=(\d+)[^"]+)"/g
  const unusedImageRegex = /IMGUNUSEDAID\[(\d+)\]/g
  const attachSizeRegex = /<span class="xi1">小于 (\d+)MB <\/span>/
  const uidMatch = html.match(uidRegex);
  const uid = uidMatch ? uidMatch[1] : null
  const hashMatch = html.match(hashRegex)
  const hash = hashMatch ? hashMatch[1] : null
  const tidMatch = html.match(tidRegex)
  const tid = tidMatch ? tidMatch[1] : null
  const pidMatch = html.match(pidRegex)
  const pid = pidMatch ? pidMatch[1] : null
  const attachSizeMatch = html.match(attachSizeRegex)
  const attachSizeLimit = attachSizeMatch ? attachSizeMatch[1] : null
  let attachid: RegExpExecArray | null
  const unusedImage: string[] = []
  while (attachid = unusedImageRegex.exec(html)) {
    unusedImage.push(attachid[1])
  }
  const usingImage: Map<string, string> = new Map
  while (attachid = usingImageRegex.exec(html)) {
    usingImage.set(attachid[2], attachid[1]) // <id, url>
  }
  return {
    uid,
    tid,
    pid,
    hash,
    unusedImage,
    attachSizeLimit,
    usingImage
  }
}

function extractAttachUrl(html: string) {
  const imgSrcRegex = /<img src="(forum\.php\?[^"]+)"/
  const match = html.match(imgSrcRegex)
  return match ? match[1] : null
}

abstract class Uploader {
  inited: boolean = false

  getMime(buf: ArrayBuffer) {
    const uint8Array = new Uint8Array(buf.slice(0, 4))
    let magic = ''
    for (let i = 0; i < uint8Array.length; i++) {
      magic += uint8Array[i].toString(16).padStart(2, '0')
    }
    magic = magic.toUpperCase()
    switch (magic) {
      case 'FFD8FFE0':
      case 'FFD8FFE1':
      case 'FFD8FFE2':
        return 'image/jpeg'
      case '89504E47':
        return 'image/png'
      case '47494638':
        return 'image/gif'
      case '49492A00':
        return 'image/tiff'
      case '52494646':
        return 'image/webp'
      default:
        if (magic.startsWith('424D')) {
          return 'image/bmp'
        }
        promptAction.showToast({
          message: '未知的文件格式，上传中止'
        })
        return ''
    }
  }

  getExtName(mime: string) {
    const split = mime.split('/')
    return split.length > 1 ? split[1] : ''
  }

  abstract sizeLimitMB(): number

  abstract init(writeHandler: WriteHandler, mode: WriteReplyMode): Promise<UploaderState>

  abstract idToUrl(id: string): Promise<string>

  abstract remove(id: string, removeText: (text: string) => void): Promise<boolean>

  abstract upload(name: string, size: number, buf: ArrayBuffer): Promise<string>

  abstract getName(): string

  abstract pick(id: string): string
}

class AttachmentUploader extends Uploader {
  private pageInfo?: ReplyPageInfo
  private imgCounter: number = 0
  private sizeLimit: number = 4

  override getName() {
    return '论坛附件'
  }

  override sizeLimitMB(): number {
    return this.sizeLimit
  }

  override pick(id: string) {
    return `[attachimg]${id}[/attachimg]`
  }

  override async init(writeHandler: WriteHandler, mode: WriteReplyMode) {
    if (mode == WriteReplyMode.NEW_PM) {
      const state: UploaderState = {
        available: false,
        errorMsg: '不能在私信里发送附件图片，请使用其它图床',
        unused: []
      }
      this.inited = true
      return state
    }
    let html = await writeHandler.getWebpage()
    const info = extractReplyPageInfo(html)
    if (info.uid == null || info.hash == null) {
      const msg = html.match(/errorhandle_\('([\s\S]*?)'/)
      const state: UploaderState = {
        available: false,
        errorMsg: (msg && msg[1]) || '该帖子不允许添加附件图片',
        unused: []
      }
      this.inited = true
      return state
    }
    this.pageInfo = info
    this.sizeLimit = info.attachSizeLimit ? parseInt(info.attachSizeLimit) : 4
    const state: UploaderState = {
      available: true,
      unused: info.unusedImage,
      using: Array.from(info.usingImage.keys())
    }
    this.inited = true
    return state
  }

  override async idToUrl(id: string): Promise<string> {
    const usingImageUrl = this.pageInfo!.usingImage.get(id)
    if (usingImageUrl) {
      return URL.WEB_BASE + usingImageUrl
    }
    const htmlStr = await new request<string>(URL.IMAGELIST_VIEW, URL.WEB_BASE)
      .param('aids', id)
      .toText()
      .get()
    const imgUrl = URL.WEB_BASE + extractAttachUrl(htmlStr)
    return imgUrl
  }

  override async remove(id: string, removeText: (text: string) => void): Promise<boolean> {
    if (this.pageInfo!.usingImage.has(id)) {
      const result = await promptAction.showDialog({
        title: '提示',
        message: '这张图片正在回帖中被使用，如果确认删除，图片将立即不能显示，即使没有编辑回帖',
        buttons: [
          {
            text: '取消',
            color: $r('sys.color.font_primary')
          },
          {
            text: '确认删除',
            color: '#ff0000'
          }
        ]
      })
      if (result.index == 0) {
        promptAction.showToast({
          message: '操作已取消'
        })
        return false
      } else {
        new request<string>(URL.ATTACHMENT_DELETE, URL.WEB_BASE)
          .param('aids[]', id)
          .param('pid', this.pageInfo!.pid || '')
          .param('tid', this.pageInfo!.tid || '')
          .formHash()
          .toText()
          .get()
        removeText(`[attachimg]${id}[/attachimg]`)
        this.pageInfo!.usingImage.delete(id)
        return true
      }
    } else {
      new request<string>(URL.ATTACHMENT_DELETE, URL.WEB_BASE)
        .param('aids[]', id)
        .formHash()
        .toText()
        .get()
      return true
    }
  }

  override async upload(name: string, size: number, buf: ArrayBuffer): Promise<string> {
    const mime = this.getMime(buf)
    if (mime === '') {
      return ''
    }
    const uploader = new request<string>(URL.ATTACHMENT_UPLOAD, URL.WEB_BASE)
    uploader.sessionConfig.headers = {
      "content-type": 'multipart/form-data'
    }
    const multiForm = new rcp.MultipartForm({
      'Filedata': {
        contentType: this.getMime(buf),
        remoteFileName: name,
        contentOrPath: {
          content: buf
        }
      },
      'filetype': '.' + this.getExtName(mime),
      'size': size,
      'type': 'image',
      'id': 'WU_FILE_' + this.imgCounter++,
      'hash': this.pageInfo!.hash!,
      'uid': this.pageInfo!.uid!,
    })
    try {
      const attachId = await uploader
        .toText()
        .formData()
        .post(multiForm)
      return attachId
    } catch (e) {
      promptAction.showToast({
        message: '图片上传出错，请稍后重试'
      })
      return ''
    }
  }
}

class RipUploader extends Uploader {
  private imgs: Map<string, RipImageItem> = new Map()

  override sizeLimitMB(): number {
    return 5
  }

  override getName() {
    return '流浪图床'
  }

  override pick(id: string) {
    return `[img]${this.imgs.get(id)!.url}[/img]`
  }

  override async init(_: WriteHandler) {
    const state: UploaderState = {
      available: true,
      unused: []
    }
    this.inited = true
    return state
  }

  override async idToUrl(id: string): Promise<string> {
    const img = this.imgs.get(id)
    if (img) {
      return img.url
    }
    return ''
  }

  override async remove(id: string): Promise<boolean> {
    const img = this.imgs.get(id)
    if (img) {
      new request<string>(img.delete_url, '')
        .get()
      this.imgs.delete(id)
    }
    return true
  }

  override async upload(name: string, size: number, buf: ArrayBuffer): Promise<string> {
    const mime = this.getMime(buf)
    if (mime === '') {
      return ''
    }
    const uploader = new request<RipImageUpload>('https://p.sda1.dev/api/v1/upload_external_noform?', '')
    try {
      const img = await uploader
        .param('filename', name)
        .withoutCookie()
        .toJSON()
        .formData()
        .post(buf)
      if (img.success) {
        this.imgs.set(img.data.path, img.data)
        return img.data.path
      } else {
        promptAction.showToast({
          message: img.message
        })
        return ''
      }
    } catch (e) {
      promptAction.showToast({
        message: '图片上传出错，请稍后重试'
      })
      return ''
    }
  }
}