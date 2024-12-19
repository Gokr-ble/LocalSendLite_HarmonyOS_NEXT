import { socket } from "@kit.NetworkKit"
import Logger from "../utils/Logger";
import { wifiManager } from '@kit.ConnectivityKit'
import polka, {IncomingMessage, ServerResponse, statik, Request, } from '@ohos/polka'
import { CryptoJS } from '@ohos/crypto-js'
import { picker, fileIo as fs, Environment, fileUri } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from "@kit.BasicServicesKit";
import { url } from "@kit.ArkTS";
import { showToast } from "../utils/ToastUtil";

@Component
@Preview
export struct ReceiveTab {

  @State fileName: string = ''
  @State fileSize: number = 0
  @State sessionId: string = ''
  @State fileId: string = ''
  @State fileToken: string = ''
  @State senderName: string = ''

  @State serverHost: string = '0.0.0.0'
  @State serverPort: number = 53317
  @State serverOn: boolean = false

  aboutToAppear(): void {

    interface FileInfoSaved {
      fileName: string,
      token: string,
      fileSize: number
    }

    const app = polka()
    // const tuple = (fileName: string, token: string, fileSize: number) => ({fileName, token, fileSize})
    const fileInfo: Map<string, FileInfoSaved> = new Map()

    interface PrepareUploadResult {
      files: Record<string, string>,
      sessionId: string;
    }

    app.listen(53317, _ => {
      // if (err) {
      //   Logger.error(`Listening on 53317 Error: ${err}`)
      // }
      Logger.info("Listening on 53317 successfully")
      this.serverOn = true
      this.serverHost = intToIp(wifiManager.getIpInfo().ipAddress)
    })

    app.get('/api/localsend/v1/info', (req, res) => {
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
    })

    app.post('/api/localsend/v2/prepare-upload', (req, res) => {
      try {
        let postData = req.files.get('postData')
        if (postData && req.getBodySize() > 0) {
          let body: object = JSON.parse(postData.toString())
          this.senderName = body['info']['alias']

          let fileInfoMap: Record<string, string> = {}
          let fileIds = Object.keys(body['files'])
          fileIds.forEach(id => {
            let token = generateUUID()
            fileInfoMap[id] = token
            let tmp: FileInfoSaved = {
              fileName: body['files'][id]['fileName'],
              token: token,
              fileSize: body['files'][id]['size']
            }
            fileInfo.set(id, tmp)
          })

          this.sessionId = generateUUID()

          let resBody: PrepareUploadResult = {
            files: fileInfoMap,
            sessionId: this.sessionId
          }

          // this.fileId = Object.keys(body['files'])[0]
          // this.fileName = body[this.fileId]['id']
          // this.fileSize = body[this.fileId]['size']

          // this.fileToken = generateUUID()
          // Logger.info(`SenderName:${this.senderName},fileName:${this.fileName},fileSize:${this.fileSize},SessionId:${this.sessionId},Token:${this.fileToken}`)
          // res.end(`{"sessionId":"${this.sessionId}","files":{"${this.fileId}":"${this.fileToken}"}}`)
          res.end(JSON.stringify(resBody))
        }

      } catch (err) {
        Logger.error(err)
        res.writeHead(500)
        res.end('Server Error')
      }
    })

    app.post('/api/localsend/v2/upload', (req, res) => {
      try {
        if (!req.search) {
          res.writeHead(403)
          res.end('Forbidden')
        } else {
          let search = new url.URLParams(req.search)
          let recvSessionId = search.get('sessionId')
          let recvFileId = search.get('fileId')
          let recvToken = search.get('token')
          if (!recvSessionId || !recvFileId || !recvToken || fileInfo.get(recvFileId)!!.token !== recvToken || this.sessionId !== recvSessionId) {
            res.writeHead(403)
            res.end('Forbidden')
          } else {
            let postData = req.files.get('postData')
            if (postData && req.getBodySize() > 0) {
              let uri: string = ''
              let context = getContext(this) as common.Context
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
    })

  }
  build() {
    Column() {
      Row() {
        Text('Listening Host')
          // .margin({right: '8vp'})
          .width('36%')
          .textAlign(TextAlign.Start)
        Text(`${this.serverHost}`)
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
        Text('Listening Port')
          // .margin({ right: '8vp', bottom: '8vp' })
          .width('36%')
          .textAlign(TextAlign.Start)
        Text(`${this.serverPort}`)
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
        Text('Server Status')
          // .margin({ right: '8vp', bottom: '8vp' })
          .width('36%')
          .height('36vp')
          .textAlign(TextAlign.Start)
        Text(!this.serverOn ? 'Off' : 'On')
          .width('15%')
          .height('36vp')
          .backgroundColor(!this.serverOn ? '#BDBDBD' : '#43A047')
          .borderRadius($r('sys.float.corner_radius_level9'))
          .padding({left: '8vp', right: '8vp'})
          .textAlign(TextAlign.Center)
      }
      .width('90%')
      .margin({ left: '16vp', top: '8vp', right: '16vp', bottom: '8vp'})
    }
    .width('100%')
    .height('100%')
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