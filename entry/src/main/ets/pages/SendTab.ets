import { rcp } from '@kit.RemoteCommunicationKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { readFile } from '../utils/ReadFile'
import { fileIo } from '@kit.CoreFileKit'
import Logger from '../utils/Logger'
import { showToast } from '../utils/ToastUtil'
import { CryptoJS } from '@ohos/crypto-js'
import { DeviceUtil, FileUtil } from '@pura/harmony-utils'

@Component
@Preview
export struct SendTab {
  @State receiverIP: string = ''
  @State fileName: string = 'Empty'
  @State fileUri: string = ''

  build() {

    Column() {
      Row() {
        Text('接收IP')
          .margin({right: '16vp'})
          .width('15%')

        TextInput()
          .width('85%')
          .onChange((value: string) => {
            this.receiverIP = value
          })
      }
      .width('85%')
      .margin({ bottom: '16vp' })

      Row() {
        Text('文件')
          .margin({right: '16vp'})
          .width('15%')

        Text(`${this.fileName}`)
          .backgroundColor($r('app.color.send_tab_file_name_background'))
          .borderRadius($r('sys.float.corner_radius_level12'))
          .width('85%')
          .height('36vp')
          .padding({ left: '8vp'})
      }
      .width('85%')
      .margin({ bottom: '16vp' })

      Button('选择文件')
        .width('90%')
        .margin({ bottom: '16vp' })
        .onClick(async () => {
          await readFile().then((value: string) => {
            let fileName = decodeURI(value.substring(value.lastIndexOf('/') + 1, value.length))
            this.fileName = fileName
            this.fileUri = value
          })
        })

      Button('发送文件')
        .width('90%')
        .margin({ bottom: '16vp' })
        .onClick(async () => {
          if (this.fileUri != '' && this.receiverIP != '') {
            // check target reachable
            let testRcp = rcp.createSession()
            let testRequest = new rcp.Request(`http://${this.receiverIP}:53317/api/localsend/v2/info`)
            let timeout: rcp.Timeout = { inactivityMs: 3000 }
            testRequest.configuration = {
              transfer: {
                timeout: timeout
              }
            }
            try {
              await testRcp.fetch(testRequest)
            } catch (e) {
              Logger.error(`${this.receiverIP} is not reachable, err: ${e}`)
              showToast(`${this.receiverIP} is not reachable`)
              return
            } finally {
              testRcp.close()
            }

            // Read File Info
            let file = fileIo.openSync(this.fileUri, fileIo.OpenMode.READ_ONLY)
            let stat = fileIo.statSync(file.fd)
            let fileId = generateFileId()
            let fileName = decodeURI(this.fileUri.substring(this.fileUri.lastIndexOf('/') + 1, this.fileUri.length))
            let fileExt = FileUtil.getFileExtention(fileName)

            let deviceId = DeviceUtil.getDeviceId(true)

            interface Info {
              alias: string;
              version: string;
              deviceModel: string;
              deviceType: 'mobile' | 'desktop' | 'web' | 'headless' | 'server';
              fingerprint: string;
              port: number;
              protocol: string;
              download: boolean;
            }

            interface File {
              id: string;
              fileName: string;
              size: number;
              fileType: string;
            }

            interface IFileMetaData {
              info: Info;
              files: Record<string, File>;
            }

            let fileMetaData: IFileMetaData = {
              info: {
                alias: "Mate70 Pro+",
                version: "2.1",
                deviceModel: "Huawei",
                deviceType: "mobile",
                fingerprint: CryptoJS.SHA256(deviceId).toString(CryptoJS.enc.Utf8),
                port: 53317,
                protocol: "http",
                download: false
              },
              files: {}
            }

            fileMetaData.files[fileId] = {
              id: fileId,
              fileName: fileName,
              size: stat.size,
              fileType: fileExt == '' ? fileExt : 'application/octet-stream'
            }

            // let fileMetaData: string = `{"info":{"alias":"Mate70Pro+","version":"2.1","deviceModel":"Huawei1","deviceType":"mobile","fingerprint":"${CryptoJS.SHA256(deviceId)}","port":53317,"protocol":"http","download":false},"files":{"${fileId}":{"id":"${fileId}","fileName":"${fileName}","size":${stat.size},"fileType":"application/octet-stream"}}}`

            let header: rcp.RequestHeaders = {'content-type':'application/json'}
            const preUploadSession = rcp.createSession({headers: header})
            preUploadSession.post(`http://${this.receiverIP}:53317/api/localsend/v2/prepare-upload`, JSON.stringify(fileMetaData)).then((response) => {
              if (response.statusCode == 200) {
                Logger.info(`pre-upload succeed: [${response.statusCode}] ${response.reasonPhrase}`)

                let responseJson = response.toJSON()
                if (responseJson != null) {
                  let sessionId: string = responseJson['sessionId'];
                  let fileToken: string = responseJson['files'][fileId]

                  if (sessionId && sessionId != '' && fileToken && fileToken != '') {
                    const uploadSession = rcp.createSession()
                    let readBuff = new ArrayBuffer(stat.size)
                    let readBytes = fileIo.readSync(file.fd, readBuff)
                    if (readBytes > 0) {
                      uploadSession.post(`http://${this.receiverIP}:53317/api/localsend/v2/upload?sessionId=${sessionId}&fileId=${fileId}&token=${fileToken}`, readBuff).then((response) => {
                        if (response.statusCode == 200) {
                          Logger.info(`upload succeed: [${response.statusCode}] ${response.reasonPhrase}`)
                          showToast("upload complete")
                        } else {
                          Logger.info(`upload failed: [${response.statusCode}] ${response.reasonPhrase}`)
                          showToast("upload failed")
                        }
                      })
                    }
                  }
                }

              } else {
                showToast(`[${response.statusCode}] ${response.reasonPhrase}`)
                Logger.info(`pre-upload failed: [${response.statusCode}] ${response.reasonPhrase}`)
              }
            }).catch((err: BusinessError) => {
              Logger.error(`pre-upload BusinessError: ${JSON.stringify(err)}`)
            })
          } else {
            if (this.fileUri == '') {
              showToast("Please select file first")
            }
            if (this.receiverIP == '') {
              showToast("Please input receiver IP")
            }
          }

        })

      Text('请确保目标连接的是同一个Wi-Fi网络')
        .width('90%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')

  }
}

function generateFileId(): string {
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
