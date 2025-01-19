import polka, { IncomingMessage, Request, ServerResponse } from '@ohos/polka'
import { CryptoJS } from '@ohos/crypto-js'
import { picker, fileIo as fs, Environment, fileUri, ReadOptions, WriteOptions } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from "@kit.BasicServicesKit";
import { url } from "@kit.ArkTS";
import { DialogUtil, FileUtil, LogUtil, NetworkUtil, RandomUtil, ToastUtil } from "@pura/harmony-utils";
import { preferences } from "@kit.ArkData";
import { DialogHelper, SpinType } from '@pura/harmony-dialog';
import { LogoIndicator } from '../utils/LogoIndicator';
import { RegisteredDevice } from '../model/RegisteredDevice';
import { PreUploadResponse } from '../model/PreUploadResponse';
import { FileInfoSaved } from '../model/FileInfo';
import { AnimatorOptions, AnimatorResult } from '@kit.ArkUI';
import { getDeviceInfo } from '../model/DeviceInfo';
import { MyServer } from '../utils/Server';
import { getConfigPreference } from '../utils/ReadConfig';


let dataPreferences = getConfigPreference()
// let registeredDeviceList: Array<RegisteredDevice> = []

let animatorOptions: AnimatorResult | undefined = undefined
let animatorOption: AnimatorOptions = {
  duration: 4000,
  delay: 0,
  easing: 'linear',
  iterations: -1,
  fill: 'forwards',
  direction: 'normal',
  begin: 0,
  end: 360
}

// const app = polka()
// const fileInfo: Map<string, FileInfoSaved> = new Map()
// let sessionId: string = ''
// let savingDialogId: string = ''

// let storage: LocalStorage = new LocalStorage()
// storage.setOrCreate('alias', dataPreferences.getSync('alias', 'default') as string)
// storage.setOrCreate('serverOn', true)

@Component
@Preview
export struct ReceiveTab {

  @State fileName: string = ''
  @State angle: number = 0
  @State serverHost: string = '0.0.0.0'

  @StorageLink('serverOn') serverOn: boolean = false
  @StorageLink('serverAlias') alias: string = 'Default'
  @StorageLink('CurrentIPAddress') currentIP: string = '0.0.0.0'

  server: MyServer = new MyServer()

  aboutToAppear(): void {
    this.serverHost = NetworkUtil.getIpAddress()
    AppStorage.setOrCreate('context', getContext(this) as common.Context)
    this.server.startServer()
    // 注册网络状态变化回调
    // NetworkUtil.register((netHandle) => {
    //   LogUtil.info(`网络可用: ${JSON.stringify(netHandle)}`)
    // }, () => {
    //   LogUtil.error('网络不可用')
    //   ToastUtil.showToast('网络不可用')
    // }, (netCapabilityInfo) => {
    //   LogUtil.info(`网络能力变化: ${JSON.stringify(netCapabilityInfo)}`)
    // }, (netConnectionPropertyInfo) => {
    //   LogUtil.info(`网络连接信息变化: ${JSON.stringify(netConnectionPropertyInfo)}`)
    //   ToastUtil.showToast('网络环境发生变化')
    //   this.serverHost = NetworkUtil.getIpAddress()
    // }, (netBlockStatusInfo) => {
    //   LogUtil.info(`网络阻塞状态: ${JSON.stringify(netBlockStatusInfo)}`)
    // }, (netHandle) => {
    //   LogUtil.info(`网络丢失: ${JSON.stringify(netHandle)}`)
    // })
  }

  onPageShow(): void {
    animatorOptions = this.getUIContext().createAnimator(animatorOption)
    animatorOptions.onFrame = (progress: number) => {
      this.angle = progress
    }
    animatorOptions.onCancel = () => {
      LogUtil.info('动画取消')
    }
    animatorOptions.onFinish = () => {
      LogUtil.info('动画完成')
    }
    animatorOptions.onCancel = () => {
      LogUtil.info('动画重复播放')
    }
  }

  build() {
    Column() {
      Image($r("app.media.RecvPageLogo"))
        .width('300vp')
        .height('300vp')
        .margin({ top: '24vp', bottom: '24vp'})
        .rotate({ angle: this.angle })

      Column() {
        Text(`${this.alias}`)
          .fontSize('36vp')
          .fontWeight('Bold')
      }
      .width('90%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: '16vp' })

      Row() {
        Text('主机IP')
          // .margin({right: '8vp'})
          .width('36%')
          .textAlign(TextAlign.Start)
        Text(`${this.currentIP}`)
          .width('60%')
          .height('36vp')
          .textAlign(TextAlign.Start)
          .backgroundColor($r('app.color.send_tab_file_name_background'))
          .borderRadius($r('sys.float.corner_radius_level9'))
          .padding({left: '8vp'})
          // .margin({ left: '16vp', top: '8vp', right: '16vp'})
      }
      .width('90%')
      .margin({ left: '16vp', top: '16vp', right: '16vp', bottom: '8vp'})

      Row() {
        Text('主机端口')
          // .margin({ right: '8vp', bottom: '8vp' })
          .width('36%')
          .textAlign(TextAlign.Start)
        Text(`${AppStorage.get('serverPort')}`)
          .width('60%')
          .height('36vp')
          // .margin({ left: '16vp', right: '16vp'})
          .textAlign(TextAlign.Start)
          .backgroundColor($r('app.color.send_tab_file_name_background'))
          .borderRadius($r('sys.float.corner_radius_level9'))
          .padding({left: '8vp'})
      }
      .width('90%')
      .margin({ left: '16vp', top: '8vp', right: '16vp', bottom: '8vp'})

      Row() {
        Text('服务器状态')
          // .margin({ right: '8vp', bottom: '8vp' })
          .width('36%')
          .height('36vp')
          .textAlign(TextAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.serverOn})
          .onChange((isOn: boolean) => {
            if (isOn) {
              ToastUtil.showToast("服务开启")
              this.server.startServer()
              this.alias = dataPreferences.getSync('alias', 'Default') as string
            } else {
              ToastUtil.showToast("服务关闭")
              this.server.stopServer()
            }
          })
        // Text(!this.serverOn ? 'Off' : 'On')
        //   .width('15%')
        //   .height('36vp')
        //   .backgroundColor(!this.serverOn ? '#BDBDBD' : '#43A047')
        //   .borderRadius($r('sys.float.corner_radius_level9'))
        //   .padding({left: '8vp', right: '8vp'})
        //   .textAlign(TextAlign.Center)
      }
      .width('90%')
      .margin({ left: '16vp', top: '8vp', right: '16vp', bottom: '8vp'})
    }
    .width('100%')
    .height('100%')
  }
}

// function startServer() {
//   dataPreferences.putSync('showRestartServerHind', false)
//
//   animatorOptions?.play()
//
//   let port = dataPreferences.getSync('serverPort', 'default') as number
//
//   if (port < 10000) {
//     ToastUtil.showToast('请选择大于10000的端口号')
//     return
//   }
//
//   AppStorage.setOrCreate('serverPort', port)
//
//   app.listen(port, _ => {
//     LogUtil.info(`Listening on ${port} successfully`)
//     AppStorage.set('serverOn', true)
//     AppStorage.set('serverHost', NetworkUtil.getIpAddress())
//   })
//
//   app.get('/api/localsend/v1/info', (req, res) => {
//     handleInfo(req, res)
//   })
//
//   app.get('/api/localsend/v2/info', (req, res) => {
//     handleInfo(req, res)
//   })
//
//   app.post('/api/localsend/v2/prepare-upload', (req, res) => {
//     handlePreUpload(req, res)
//   })
//
//   app.post('/api/localsend/v2/upload', (req, res) => {
//     handleUpload(req, res, AppStorage.get('context') as common.Context)
//   })
//
//   app.post('/api/localsend/v2/register', (req, res) => {
//     handleRegister(req, res)
//   })
// }
//
// function stopServer() {
//   app.server?.stop()
//   NetworkUtil.unregister()
//   animatorOptions?.finish()
// }
//
// function handleInfo(req: Request, res: ServerResponse) {
//   try {
//     res.writeHead(200, { 'Content-Type': 'application/json' })
//     let info = getDeviceInfo()
//     res.end(info)
//   } catch (err) {
//     LogUtil.error(err)
//     res.writeHead(500)
//     res.end('Server Error')
//   }
// }
//
// function handlePreUpload(req: Request, res: ServerResponse) {
//   try {
//     let postData = req.files.get('postData')
//     if (postData && req.getBodySize() > 0) {
//       let body: object = JSON.parse(postData.toString())
//       // this.senderName = body['info']['alias']
//
//       let fileInfoMap: Record<string, string> = {}
//       let fileIds = Object.keys(body['files'])
//       let fileListStr = ''
//       let fileTotalSize = 0
//       fileIds.forEach(id => {
//         let token = RandomUtil.generateUUID32()
//         fileInfoMap[id] = token
//         let tmp: FileInfoSaved = {
//           fileName: body['files'][id]['fileName'],
//           token: token,
//           fileSize: body['files'][id]['size']
//         }
//         fileTotalSize += body['files'][id]['size']
//         fileListStr = fileListStr + body['files'][id]['fileName'] + '\n'
//         fileInfo.set(id, tmp)
//       })
//
//       // 弹窗使用户决定是否接收
//       let sender: string = body['info']['alias']
//
//       DialogUtil.showPrimaryDialog({
//         title: `${sender} 发来以下文件：`,
//         message: `${fileListStr.trim()}`,
//         primaryButton: {
//           value: '拒绝',
//           action: () => {
//             ToastUtil.showToast('已拒绝')
//             res.writeHead(403)
//             res.end('Rejected')
//           }
//         },
//         secondaryButton: {
//           value: '接收',
//           action: () => {
//             // ToastUtil.showToast('已接受')
//             sessionId = RandomUtil.generateUUID32()
//             let resBody: PreUploadResponse = {
//               files: fileInfoMap,
//               sessionId: sessionId
//             }
//
//             // 计算预估时间
//             let bandwidth = 10000000
//             let estimatedTime = fileTotalSize / bandwidth
//             let updateInterval = 500
//             // 保留两位小数
//             let tickTime = (updateInterval / (estimatedTime * 10))
//
//             LogUtil.info(`estimate time: ${estimatedTime}`)
//             LogUtil.info(`tick time: ${tickTime}`)
//
//             let saveProgress = 0
//             savingDialogId = DialogHelper.showLoadingProgress({
//               // uiContext: storage.get('uiContext'),
//               progress: saveProgress,
//               content: '保存中……',
//               loadColor: Color.White,
//               autoCancel: false,
//               backCancel: false
//             })
//
//             let intervalId = setInterval(() => {
//               if (saveProgress < 100) {
//                 saveProgress = Math.round((saveProgress + tickTime) * 10) / 10
//                 LogUtil.info(`saveProgress: ${saveProgress}`)
//                 DialogHelper.updateLoading(savingDialogId, undefined, saveProgress)
//               } else {
//                 clearInterval(intervalId)
//               }
//             }, updateInterval)
//             res.end(JSON.stringify(resBody))
//           }
//         },
//         onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
//             LogUtil.error(`onWillDismiss: ${JSON.stringify(dismissDialogAction)}`)
//         }
//       })
//     }
//   } catch (err) {
//     LogUtil.error(err)
//     res.writeHead(500)
//     res.end('Server Error')
//   }
// }
//
// function handleUpload(req: Request, res: ServerResponse, context: Context) {
//   try {
//     if (!req.search) {
//       res.writeHead(403)
//       res.end('Forbidden')
//     } else {
//       let search = new url.URLParams(req.search)
//       let recvSessionId = search.get('sessionId')
//       let recvFileId = search.get('fileId')
//       let recvToken = search.get('token')
//       let fileName = fileInfo.get(recvFileId!!)!!.fileName
//       let fileSize = fileInfo.get(recvFileId!!)!!.fileSize
//
//       if (!recvSessionId || !recvFileId || !recvToken || fileInfo.get(recvFileId)!!.token !== recvToken || sessionId !== recvSessionId) {
//         res.writeHead(403)
//         res.end('Forbidden')
//       } else {
//         let postData = req.files.get('postData')
//         if (postData && req.getBodySize() > 0) {
//
//           let uri: string = ''
//           const documentViewPicker = new picker.DocumentViewPicker(context)
//           const documentSaveOptions = new picker.DocumentSaveOptions()
//           documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
//           documentViewPicker.save(documentSaveOptions).then(async (documentSaveResult: Array<string>) => {
//             // 添加重复文件判断
//             uri = documentSaveResult[0] + '/' + fileName
//             if (await FileUtil.access(FileUtil.getFilePath(uri))) {
//               let date = new Date()
//               let dateString = `${date.getFullYear()}${date.getMonth()}${date.getDay()}${date.getHours()}${date.getMinutes()}${date.getSeconds()}`
//               if (fileName.includes('.')) {
//                 let newName = fileName.substring(0, fileName.lastIndexOf('.')) + `_${dateString}.` + FileUtil.getFileExtention(fileName)
//                 uri = documentSaveResult[0] + '/' + newName
//               } else {
//                 uri = uri + '_' + dateString
//               }
//             }
//
//             let path = new fileUri.FileUri(uri).path
//
//             // let outputFile = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
//
//             let outputStream = await fs.createStream(path, "w+")
//             let bufSize = 40960
//             let buf = postData!!.buffer
//             let batchNum = Math.ceil(fileSize / bufSize)
//             let remainSize = fileSize - bufSize * (batchNum - 1)
//
//             for (let i = 0; i < batchNum; i++) {
//               let writeOptions: WriteOptions = {
//                 offset: bufSize * i,
//                 length: (i + 1) == batchNum ? remainSize : bufSize
//               }
//               let writeBuf = buf.slice(bufSize * i, Math.min(fileSize, bufSize * (i + 1)))
//               await outputStream.write(writeBuf, writeOptions)
//               // saveProgress++
//               // DialogHelper.updateLoading(dialogId, undefined, saveProgress)
//             }
//
//             // let writeLen = fs.writeSync(outputFile.fd, postData!!.buffer)
//             // LogUtil.info(`[*] write ${writeLen} bytes`)
//
//             LogUtil.info(`[*] save succeed, uri: ${uri}`)
//             ToastUtil.showToast(`已保存${fileInfo.size}个文件`)
//             // 关闭保存进度条弹窗
//             DialogHelper.closeDialog(savingDialogId)
//             // 关闭预备加载弹窗
//             // DialogHelper.closeDialog(preDialogId)
//             fileInfo.clear()
//             outputStream.close()
//
//             res.end('{}')
//           }).catch((err: BusinessError) => {
//             LogUtil.error(`[*] save failed, code: ${err.code}, message: ${err.message}`)
//             res.writeHead(500)
//             res.end('Server Error')
//           })
//         }
//       }
//     }
//   } catch (err) {
//     LogUtil.error(err)
//     res.writeHead(500)
//     res.end('Server Error')
//   }
// }
//
// function handleRegister(req: Request, res: ServerResponse) {
//   try {
//     let postData = req.files.get('postData')
//     if (postData && req.getBodySize() > 0) {
//       let body: RegisteredDevice = JSON.parse(postData.toString())
//       // let deviceInfo: RegisteredDevice = {
//       //   alias: body['alias'],
//       //   ip: '',
//       //   version: body['version'],
//       //   deviceModel: body['deviceModel'],
//       //   deviceType: body['deviceType'],
//       //   fingerprint: body['fingerprint'],
//       //   port: body['port'],
//       //   protocol: body['protocol'],
//       //   download: body['download']
//       // }
//       registeredDeviceList.push(body)
//       AppStorage.setOrCreate('deviceList', registeredDeviceList)
//     }
//     res.end('{}')
//   } catch (err) {
//     LogUtil.error(err)
//   }
// }