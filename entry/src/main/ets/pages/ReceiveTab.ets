import Logger from "../utils/Logger";
import polka, { IncomingMessage, Request, ServerResponse } from '@ohos/polka'
import { CryptoJS } from '@ohos/crypto-js'
import { picker, fileIo as fs, Environment, fileUri } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from "@kit.BasicServicesKit";
import { url } from "@kit.ArkTS";
import { showToast } from "../utils/ToastUtil";
import { DialogUtil, LogUtil, NetworkUtil, ToastUtil } from "@pura/harmony-utils";

interface FileInfoSaved {
  fileName: string,
  token: string,
  fileSize: number
}

interface PrepareUploadResult {
  files: Record<string, string>,
  sessionId: string;
}

const app = polka()
const fileInfo: Map<string, FileInfoSaved> = new Map()
let fileSize: number = 0
let sessionId: string = ''
let fileId: string = ''
let fileToken: string = ''

let storage: LocalStorage = new LocalStorage()
storage.setOrCreate('serverHost', NetworkUtil.getIpAddress())
storage.setOrCreate('serverPort', 53317)
storage.setOrCreate('serverOn', true)

@Component
@Preview
export struct ReceiveTab {

  @State fileName: string = ''
  // @LocalStorageLink('serverHost') serverHost: string = '0.0.0.0'
  // @LocalStorageLink('serverPort') serverPort: number = 53317
  // @LocalStorageLink('serverOn') serverOn: boolean = false

  aboutToAppear(): void {
    storage.setOrCreate('context', getContext(this) as common.Context)
    startServer()
  }

  build() {
    Column() {
      Image($r("app.media.RecvPageLogo"))
        .width('300vp')
        .height('300vp')
        .margin({ top: '24vp', bottom: '24vp'})

      Column() {
        Text('别名')
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
        Text(`${storage.get('serverHost')}`)
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
        Text(`${storage.get('serverPort')}`)
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
        Toggle({ type: ToggleType.Switch, isOn: storage.get('serverOn')})
          .onChange((isOn: boolean) => {
            if (isOn) {
              ToastUtil.showToast("Server (pretend) On")
              startServer()
            } else {
              ToastUtil.showToast("Server (pretend) Off")
              stopServer()
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

function startServer() {
  app.listen(53317, _ => {
    Logger.info("Listening on 53317 successfully")
    storage.set('serverOn', true)
    storage.set('serverHost', NetworkUtil.getIpAddress())
  })

  app.get('/api/localsend/v1/info', (req, res) => {
    handleInfo(req, res)
  })

  app.post('/api/localsend/v2/prepare-upload', (req, res) => {
    handlePreUpload(req, res)
  })

  app.post('/api/localsend/v2/upload', (req, res) => {
    handleUpload(req, res, storage.get('context') as common.Context)
  })
}

function stopServer() {
  app.server?.stop()
}

function handleInfo(req: Request, res: ServerResponse) {
  res.writeHead(200, { 'Content-Type': 'application/json' })
  let info = JSON.stringify({
    "alias": "Mate 70 Pro+",
    "version": "2.1",
    "deviceModel": "Huawei",
    "deviceType": "mobile",
    "fingerprint": CryptoJS.SHA256("deviceInfo.serial"),
    "port": 53317,
    "protocol": "http",
    "download": false
  })
  res.end(info)
}

function handlePreUpload(req: Request, res: ServerResponse) {
  try {
    let postData = req.files.get('postData')
    if (postData && req.getBodySize() > 0) {
      let body: object = JSON.parse(postData.toString())
      // this.senderName = body['info']['alias']

      let fileInfoMap: Record<string, string> = {}
      let fileIds = Object.keys(body['files'])
      let fileListStr = ''
      fileIds.forEach(id => {
        let token = generateUUID()
        fileInfoMap[id] = token
        let tmp: FileInfoSaved = {
          fileName: body['files'][id]['fileName'],
          token: token,
          fileSize: body['files'][id]['size']
        }
        fileListStr = fileListStr + body['files'][id]['fileName'] + '\n'
        fileInfo.set(id, tmp)
      })

      // add user decision
      let sender: string = body['info']['alias']

      DialogUtil.showPrimaryDialog({
        title: `${sender} 发来以下文件：`,
        message: `${fileListStr.trim()}`,
        primaryButton: {
          value: '拒绝',
          action: () => {
            ToastUtil.showToast('已拒绝')
            res.writeHead(403)
            res.end('Rejected')
          }
        },
        secondaryButton: {
          value: '接收',
          action: () => {
            ToastUtil.showToast('已接受')
            sessionId = generateUUID()
            let resBody: PrepareUploadResult = {
              files: fileInfoMap,
              sessionId: sessionId
            }
            res.end(JSON.stringify(resBody))
          }
        },
        onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
            LogUtil.error(`onWillDismiss: ${JSON.stringify(dismissDialogAction)}`)
        }
      })
    }
  } catch (err) {
    Logger.error(err)
    res.writeHead(500)
    res.end('Server Error')
  }
}

function handleUpload(req: Request, res: ServerResponse, context: Context) {
  try {
    if (!req.search) {
      res.writeHead(403)
      res.end('Forbidden')
    } else {
      let search = new url.URLParams(req.search)
      let recvSessionId = search.get('sessionId')
      let recvFileId = search.get('fileId')
      let recvToken = search.get('token')
      if (!recvSessionId || !recvFileId || !recvToken || fileInfo.get(recvFileId)!!.token !== recvToken || sessionId !== recvSessionId) {
        res.writeHead(403)
        res.end('Forbidden')
      } else {
        let postData = req.files.get('postData')
        if (postData && req.getBodySize() > 0) {
          let uri: string = ''
          // let context = getContext(this) as common.Context
          const documentViewPicker = new picker.DocumentViewPicker(context)
          const documentSaveOptions = new picker.DocumentSaveOptions()
          documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
          documentViewPicker.save(documentSaveOptions).then((documentSaveResult: Array<string>) => {
            uri = documentSaveResult[0] + '/' + fileInfo.get(recvFileId!!)!!.fileName

            let path = new fileUri.FileUri(uri).path

            // if (!fileInfo || !recvFileId) {
            //   uri.concat(`/${generateUUID()}`)
            // } else {
            //   uri.concat(`/${fileInfo.get(recvFileId)!!.fileName}`)
            // }

            Logger.info(`[*] save succeed, uri: ${uri}`)

            let outputFile = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
            let writeLen = fs.writeSync(outputFile.fd, postData!!.buffer)
            Logger.info(`[*] write ${writeLen} bytes`)

            showToast(`saved ${fileInfo.size} files`)

            res.end('{}')
          }).catch((err: BusinessError) => {
            Logger.error(`[*] save failed, code: ${err.code}, message: ${err.message}`)
            res.writeHead(500)
            res.end('Server Error')
          })
        }
      }
    }
  } catch (err) {
    Logger.error(err)
    res.writeHead(500)
    res.end('Server Error')
  }
}

function generateUUID(): string {
  let uuidValue = "";
  for (let k = 0; k < 32;k++) {
    let randomValue = Math.random() * 16 | 0;
    if (k == 8 || k == 12 || k == 16 || k == 20) {
      uuidValue += "-"
    }
    uuidValue += (k == 12 ? 4 : (k == 16 ? (randomValue & 3 | 8) : randomValue)).toString(16);
  }
  return uuidValue;
}

function intToIp(int: number): string {
  // 将整数转换为无符号32位整数，防止负数和溢出
  const unsignedInt = int >>> 0;

  // 提取每个八位段并转换为十进制
  const part1 = unsignedInt >>> 24;
  const part2 = (unsignedInt >>> 16) & 0xFF;
  const part3 = (unsignedInt >>> 8) & 0xFF;
  const part4 = unsignedInt & 0xFF;

  // 将每个部分转换为字符串并拼接成点分十进制格式
  return `${part1}.${part2}.${part3}.${part4}`;
}