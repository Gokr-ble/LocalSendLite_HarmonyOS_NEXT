import polka, { Request, ServerResponse } from '@ohos/polka'
import { DialogUtil, FileUtil, LogUtil, NetworkUtil, PasteboardUtil, RandomUtil, ToastUtil } from '@pura/harmony-utils'
import { FileInfoSaved } from '../model/FileInfo'
import { getConfigPreference } from './ReadConfig'
import { common } from '@kit.AbilityKit'
import { getDeviceInfo } from '../model/DeviceInfo'
import { PreUploadResponse } from '../model/PreUploadResponse'
import { DialogHelper } from '@pura/harmony-dialog'
import { url } from '@kit.ArkTS'
import { fileUri, picker, fileIo as fs, WriteOptions } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { RegisteredDevice } from '../model/RegisteredDevice'
import { AnimatorResult } from '@kit.ArkUI'
import { AnimController } from '../controller/AnimController'

export class MyServer {
  app = polka()
  // 结构<fileId, {fileName, token, fileSize}>
  fileInfo: Map<string, FileInfoSaved> = new Map()
  registeredDeviceList: Array<RegisteredDevice> = []
  sessionId: string = ''
  savingDialogId: string = ''
  dataPreferences = getConfigPreference()
  animController: AnimController | undefined = undefined

  // constructor(animControllerRef: AnimController) {
  //   this.animController = animControllerRef
  // }

  startServer() {
    this.dataPreferences.putSync('showRestartServerHind', false)

    let animatorOptions: AnimatorResult | undefined = AppStorage.get('animatorOptions')
    animatorOptions?.play()
    LogUtil.info(`animatorOptions: ${animatorOptions}`)

    let port = this.dataPreferences.getSync('serverPort', 'default') as number

    if (port < 10000) {
      ToastUtil.showToast('请选择大于10000的端口号')
      return
    }

    AppStorage.setOrCreate('serverPort', port)

    this.app
      .get('/api/localsend/v1/info', (req, res) => {
        this.handleInfo(req, res)
      })
      .get('/api/localsend/v2/info', (req, res) => {
        this.handleInfo(req, res)
      })
      .post('/api/localsend/v2/prepare-upload', (req, res) => {
        this.handlePreUpload(req, res)
      })
      .post('/api/localsend/v2/upload', (req, res) => {
        this.handleUpload(req, res, AppStorage.get('context') as common.Context)
      })
      .post('/api/localsend/v2/register', (req, res) => {
        this.handleRegister(req, res)
      })
      .post('/api/localsend/v2/cancel', (req, res) => {
        this.handleCancel(req, res)
      })
      .listen(port, _ => {
      LogUtil.info(`Listening on ${port} successfully`)
      AppStorage.set('serverOn', true)
      AppStorage.set('serverHost', NetworkUtil.getIpAddress())
    })
  }

  stopServer() {
    this.app.server?.stop()
    NetworkUtil.unregister()
    let animatorOptions: AnimatorResult | undefined = AppStorage.get('animatorOptions')
    animatorOptions?.finish()

    // this.animController?.pauseAnimation()
  }

  handleInfo(req: Request, res: ServerResponse) {
    try {
      res.writeHead(200, { 'Content-Type': 'application/json' })
      let info = getDeviceInfo()
      res.end(info)
    } catch (err) {
      LogUtil.error(err)
      res.writeHead(500, 'Internal Server Error')
      res.end('{"message":"Internal Server Error"}')
    }
  }

  handlePreUpload(req: Request, res: ServerResponse) {
    try {
      let postData = req.files.get('postData')
      if (postData && req.getBodySize() > 0) {
        let body: object = JSON.parse(postData.toString())

        let fileInfoMap: Record<string, string> = {}
        let fileIds = Object.keys(body['files'])
        let fileListStr = ''
        let fileTotalSize = 0
        fileIds.forEach(id => {
          let token = RandomUtil.generateUUID32()
          fileInfoMap[id] = token
          let tmp: FileInfoSaved = {
            fileName: body['files'][id]['fileName'],
            token: token,
            fileSize: body['files'][id]['size']
          }
          fileTotalSize += body['files'][id]['size']
          fileListStr = fileListStr + body['files'][id]['fileName'] + '\n'
          this.fileInfo.set(id, tmp)
        })
        // 构造prepare-upload需要的返回参数
        this.sessionId = RandomUtil.generateUUID32()
        let resBody: PreUploadResponse = {
          files: fileInfoMap,
          sessionId: this.sessionId
        }
        // 弹窗使用户决定是否接收
        let sender: string = body['info']['alias']

        // 处理文本类型数据
        if (fileIds.length === 1 && body['files'][fileIds[0]]['fileType'] === 'text/plain' && body['files'][fileIds[0]]['preview'] !== '') {
          let previewText = body['files'][fileIds[0]]['preview'] as string
          DialogUtil.showPrimaryDialog({
            title: `${sender} 发来以下文本：`,
            message: previewText,
            primaryButton: {
              value: '关闭',
              action: () => {
                // ToastUtil.showToast('已拒绝')
                res.writeHead(204, 'No Content')
                res.end('{}')
              }
            },
            secondaryButton: {
              value: '复制',
              action: () => {
                // 将文本复制到剪贴板
                PasteboardUtil.setDataText(previewText).then(() => {
                  ToastUtil.showToast('已复制到剪贴板')
                })
                res.writeHead(204, 'No Content')
                res.end('{}')
              }
            }
          })
        } else {
          DialogUtil.showPrimaryDialog({
            title: `${sender} 发来以下文件：`,
            message: `${fileListStr.trim()}`,
            primaryButton: {
              value: '拒绝',
              action: () => {
                ToastUtil.showToast('已拒绝')
                res.writeHead(403, 'Forbidden')
                res.end('{"message":"File request declined by recipient"}')
              }
            },
            secondaryButton: {
              value: '接收',
              action: () => {
                // 计算预估时间
                let bandwidth = 10000000
                let estimatedTime = fileTotalSize / bandwidth
                let updateInterval = 500
                // 保留两位小数
                let tickTime = (updateInterval / (estimatedTime * 10))

                LogUtil.info(`estimate time: ${estimatedTime}`)
                LogUtil.info(`tick time: ${tickTime}`)

                let saveProgress = 0
                this.savingDialogId = DialogHelper.showLoadingProgress({
                  // uiContext: storage.get('uiContext'),
                  progress: saveProgress,
                  content: '保存中……',
                  loadColor: Color.White,
                  autoCancel: false,
                  backCancel: false
                })

                let intervalId = setInterval(() => {
                  if (saveProgress < 100) {
                    saveProgress = Math.round((saveProgress + tickTime) * 10) / 10
                    LogUtil.info(`saveProgress: ${saveProgress}`)
                    DialogHelper.updateLoading(this.savingDialogId, undefined, saveProgress)
                  } else {
                    clearInterval(intervalId)
                  }
                }, updateInterval)
                res.end(JSON.stringify(resBody))
              }
            },
            onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
              LogUtil.error(`onWillDismiss: ${JSON.stringify(dismissDialogAction)}`)
            }
          })
        }
      }
    } catch (err) {
      LogUtil.error(err)
      res.writeHead(500, 'Internal Server Error')
      res.end('{"message":"Internal Server Error"}')
    }
  }

  handleUpload(req: Request, res: ServerResponse, context: Context) {
    try {
      if (!req.search) {
        res.writeHead(403, 'Forbidden')
        res.end('{"message":"File request declined by recipient"}')
      } else {
        let search = new url.URLParams(req.search)
        let recvSessionId = search.get('sessionId')
        let recvFileId = search.get('fileId')
        let recvToken = search.get('token')
        let fileName = this.fileInfo.get(recvFileId!!)!!.fileName
        let fileSize = this.fileInfo.get(recvFileId!!)!!.fileSize

        if (!recvSessionId || !recvFileId || !recvToken || this.fileInfo.get(recvFileId)!!.token !== recvToken ||
          this.sessionId !== recvSessionId) {
          res.writeHead(403, 'Forbidden')
          res.end('{"message":"File request declined by recipient"}')
        } else {
          let postData = req.files.get('postData')
          if (postData && req.getBodySize() > 0) {

            let uri: string = ''
            const documentViewPicker = new picker.DocumentViewPicker(context)
            const documentSaveOptions = new picker.DocumentSaveOptions()
            documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
            documentViewPicker.save(documentSaveOptions).then(async (documentSaveResult: Array<string>) => {
              // 添加重复文件判断
              uri = documentSaveResult[0] + '/' + fileName
              if (await FileUtil.access(FileUtil.getFilePath(uri))) {
                let date = new Date()
                let dateString =
                  `${date.getFullYear()}${date.getMonth()}${date.getDay()}${date.getHours()}${date.getMinutes()}${date.getSeconds()}`
                if (fileName.includes('.')) {
                  let newName = fileName.substring(0, fileName.lastIndexOf('.')) + `_${dateString}.` +
                  FileUtil.getFileExtention(fileName)
                  uri = documentSaveResult[0] + '/' + newName
                } else {
                  uri = uri + '_' + dateString
                }
              }

              let path = new fileUri.FileUri(uri).path

              // let outputFile = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)

              let outputStream = await fs.createStream(path, "w+")
              let bufSize = 40960
              let buf = postData!!.buffer
              let batchNum = Math.ceil(fileSize / bufSize)
              let remainSize = fileSize - bufSize * (batchNum - 1)

              for (let i = 0; i < batchNum; i++) {
                let writeOptions: WriteOptions = {
                  offset: bufSize * i,
                  length: (i + 1) == batchNum ? remainSize : bufSize
                }
                let writeBuf = buf.slice(bufSize * i, Math.min(fileSize, bufSize * (i + 1)))
                await outputStream.write(writeBuf, writeOptions)
              }

              // let writeLen = fs.writeSync(outputFile.fd, postData!!.buffer)
              // LogUtil.info(`[*] write ${writeLen} bytes`)

              LogUtil.info(`[*] save succeed, uri: ${uri}`)
              ToastUtil.showToast(`已保存${this.fileInfo.size}个文件`)
              // 关闭保存进度条弹窗
              DialogHelper.closeDialog(this.savingDialogId)
              // 关闭预备加载弹窗
              // DialogHelper.closeDialog(preDialogId)
              this.fileInfo.clear()
              outputStream.close()

              res.end('{}')
            }).catch((err: BusinessError) => {
              LogUtil.error(`[*] save failed, code: ${err.code}, message: ${err.message}`)
              res.writeHead(500, 'Internal Server Error')
              res.end('{"message":"Internal Server Error"}')
            })
          }
        }
      }
    } catch (err) {
      LogUtil.error(err)
      res.writeHead(500, 'Internal Server Error')
      res.end('{"message":"Internal Server Error"}')
    }
  }

  handleRegister(req: Request, res: ServerResponse) {
    try {
      let postData = req.files.get('postData')
      if (postData && req.getBodySize() > 0) {
        let body: RegisteredDevice = JSON.parse(postData.toString())
        this.registeredDeviceList.push(body)
        AppStorage.setOrCreate('deviceList', this.registeredDeviceList)
      }
      res.end('{}')
    } catch (err) {
      LogUtil.error(err)
    }
  }

  handleCancel(req: Request, res: ServerResponse) {
    this.sessionId = ''
    LogUtil.error('File request declined by recipient')
    res.writeHead(403, 'Forbidden')
    res.end('{"message":"No permission"}')
  }
}

