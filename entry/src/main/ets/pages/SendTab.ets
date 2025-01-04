import { rcp } from '@kit.RemoteCommunicationKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { readFile } from '../utils/ReadFile'
import { fileIo } from '@kit.CoreFileKit'
import { CryptoJS } from '@ohos/crypto-js'
import { DeviceUtil, FileUtil, LogUtil, NetworkUtil, RandomUtil, ToastUtil } from '@pura/harmony-utils'
import { preferences } from '@kit.ArkData'
import { DialogHelper, SpinType } from '@pura/harmony-dialog'
import { socket } from '@kit.NetworkKit'
import { taskpool } from '@kit.ArkTS'
import axios, { AxiosResponse } from '@ohos/axios'

let dataPreferences = preferences.getPreferencesSync(getContext(), { name: 'config.db' });

class SocketInfo {
  message: ArrayBuffer = new ArrayBuffer(1);
  remoteInfo: socket.SocketRemoteInfo = {} as socket.SocketRemoteInfo
}

interface RegisteredDevice {
  ip: string
  alias: string
  version: string
  deviceModel: string
  deviceType: string
  fingerprint: string
  port: number
  protocol: string
  download: boolean
}

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
          .margin({ right: '16vp' })
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
          .margin({ right: '16vp' })
          .width('15%')

        Text(`${this.fileName}`)
          .backgroundColor($r('app.color.send_tab_file_name_background'))
          .borderRadius($r('sys.float.corner_radius_level12'))
          .width('85%')
          .height('36vp')
          .padding({ left: '8vp' })
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
              LogUtil.error(`${this.receiverIP} is not reachable, err: ${e}`)
              ToastUtil.showToast(`${this.receiverIP} is not reachable`)
              return
            } finally {
              testRcp.close()
            }

            // 开启加载弹窗
            let dialogId = DialogHelper.showLoadingDialog({
              loadType: SpinType.spinP,
              loadColor: Color.White,
              loadSize: 70,
              backgroundColor: '#BB000000',
              content: "传输中……",
              fontSize: 16,
              padding: {
                top: 30,
                right: 50,
                bottom: 30,
                left: 50
              },
              autoCancel: false
            })

            // Read File Info
            let file = fileIo.openSync(this.fileUri, fileIo.OpenMode.READ_ONLY)
            let stat = fileIo.statSync(file.fd)
            let fileId = RandomUtil.generateUUID32()
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

            let alias = dataPreferences.getSync('alias', 'default') as string
            let model = dataPreferences.getSync('deviceModel', 'default') as string
            let type = dataPreferences.getSync('deviceType', 'default') as string
            let proto = dataPreferences.getSync('encryptOn', 'default') as boolean ? 'https' : 'http'
            let port = dataPreferences.getSync('serverPort', 'default') as number

            let fileMetaData: IFileMetaData = {
              info: {
                alias: alias,
                version: "2.1",
                deviceModel: model,
                deviceType: 'mobile',
                fingerprint: CryptoJS.SHA256(deviceId).toString(CryptoJS.enc.Utf8),
                port: port,
                protocol: proto,
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

            let header: rcp.RequestHeaders = { 'content-type': 'application/json' }
            const preUploadSession = rcp.createSession({ headers: header })
            preUploadSession.post(`http://${this.receiverIP}:53317/api/localsend/v2/prepare-upload`,
              JSON.stringify(fileMetaData)).then((response) => {
              if (response.statusCode == 200) {
                LogUtil.info(`pre-upload succeed: [${response.statusCode}] ${response.reasonPhrase}`)

                let responseJson = response.toJSON()
                if (responseJson != null) {
                  let sessionId: string = responseJson['sessionId'];
                  let fileToken: string = responseJson['files'][fileId]

                  if (sessionId && sessionId != '' && fileToken && fileToken != '') {
                    const uploadSession = rcp.createSession()
                    let readBuff = new ArrayBuffer(stat.size)
                    let readBytes = fileIo.readSync(file.fd, readBuff)
                    if (readBytes > 0) {
                      uploadSession.post(`http://${this.receiverIP}:53317/api/localsend/v2/upload?sessionId=${sessionId}&fileId=${fileId}&token=${fileToken}`,
                        readBuff).then((response) => {
                        if (response.statusCode == 200) {
                          LogUtil.info(`upload succeed: [${response.statusCode}] ${response.reasonPhrase}`)
                          ToastUtil.showToast("上传完成")
                          DialogHelper.closeDialog(dialogId)
                        } else {
                          LogUtil.info(`upload failed: [${response.statusCode}] ${response.reasonPhrase}`)
                          ToastUtil.showToast("上传失败")
                          DialogHelper.closeDialog(dialogId)
                        }
                      })
                    }
                  }
                }
              } else {
                ToastUtil.showToast(`[${response.statusCode}] ${response.reasonPhrase}`)
                LogUtil.info(`pre-upload failed: [${response.statusCode}] ${response.reasonPhrase}`)
              }
            }).catch((err: BusinessError) => {
              LogUtil.error(`pre-upload BusinessError: ${JSON.stringify(err)}`)
            })

          } else {
            if (this.fileUri == '') {
              ToastUtil.showToast("Please select file first")
            }
            if (this.receiverIP == '') {
              ToastUtil.showToast("Please input receiver IP")
            }
          }
        })

      Text('请确保目标连接的是同一个Wi-Fi网络')
        .width('90%')
        .margin({ bottom: '16vp' })
        .textAlign(TextAlign.Center)

      Button('扫描本地网络')
        .width('90%')
        .margin({ bottom: '16vp' })
        .onClick(async () => {
          // 开启加载弹窗
          let dialogId = DialogHelper.showLoadingDialog({
            loadType: SpinType.spinP,
            loadColor: Color.White,
            loadSize: 70,
            backgroundColor: '#BB000000',
            content: "扫描中……",
            fontSize: 16,
            padding: {
              top: 30,
              right: 50,
              bottom: 30,
              left: 50
            },
            autoCancel: false
          })
          await tcpScan(dialogId)
        })
    }
    .width('100%')
    .height('100%')

  }
}

function getDeviceInfo() {
  let alias = dataPreferences.getSync('alias', 'default') as string
  let model = dataPreferences.getSync('deviceModel', 'default') as string
  let type = dataPreferences.getSync('deviceType', 'default') as string
  let proto = dataPreferences.getSync('encryptOn', 'default') as boolean ? 'https' : 'http'
  let port = dataPreferences.getSync('serverPort', 'default') as number
  let deviceId = DeviceUtil.getDeviceId(true)
  return JSON.stringify({
    alias: alias,
    version: "2.1",
    deviceModel: model,
    deviceType: type,
    fingerprint: CryptoJS.SHA256(deviceId).toString(CryptoJS.enc.Utf8),
    port: port,
    protocol: proto,
    download: false
  })
}

@Concurrent
function scanOneIp(remoteIp: string, deviceInfo: string) {
  LogUtil.info(`${remoteIp} is scanning`)
  let scanRcp = rcp.createSession({
    headers: { 'content-type': 'application/json' },
    requestConfiguration: { transfer: { timeout: { connectMs: 1000 }}}
  })
  let result = new Map<string, string>()
  scanRcp.post(`http://${remoteIp}:53317/api/localsend/v2/register`, deviceInfo).then((res) => {
    let regDevice: RegisteredDevice = res.toJSON() as RegisteredDevice
    regDevice.ip = remoteIp
    LogUtil.info(`${remoteIp} scan finished`)
    result.set(remoteIp, JSON.stringify(regDevice))
  }).catch((err: BusinessError) => {
    LogUtil.info(`${remoteIp} scan finished`)
    result.set(remoteIp, err.message)
  })
  return result
}

async function tcpScan(dialogId: string) {
  let localIp = NetworkUtil.getIpAddress()
  let lastTag = parseInt(localIp.substring(localIp.lastIndexOf('.') + 1))
  let taskGroup: taskpool.TaskGroup = new taskpool.TaskGroup()
  for (let i = 0; i < 255; i++) {
    if (i === lastTag) continue
    let remoteIp = localIp.substring(0, localIp.lastIndexOf('.') + 1) + i

    let task: taskpool.Task = new taskpool.Task(scanOneIp, remoteIp, getDeviceInfo())
    taskGroup.addTask(task)
  }
  await taskpool.execute(taskGroup, taskpool.Priority.HIGH).then((ret: Object) => {
    LogUtil.info(ret.toString())
  })

  LogUtil.info(`scan finished, AppStorage: ${AppStorage.get('deviceList')}`)
  DialogHelper.closeDialog(dialogId)
}

function udpBroadcast() {
  let udp: socket.UDPSocket = socket.constructUDPSocketInstance()
  let bindAddress: socket.NetAddress = {
    address: '0.0.0.0',
    port: 53317
  }
  let targetAddress: socket.NetAddress = {
    address: '224.0.0.167',
    port: 53317
  }
  udp.on('message', (value: SocketInfo) => {
    let buffer = value.message
    let dataView = new DataView(buffer)
    let str = ''
    for (let i = 0; i < dataView.byteLength; i++) {
      str += String.fromCharCode(dataView.getUint8(i))
    }
    LogUtil.info(`UDP message: ${str}`)
  })
  udp.bind(bindAddress, (err: BusinessError) => {
    if (err) {
      LogUtil.error(err.message)
      return
    }
    LogUtil.info('bind success')
    let udpExtraOptions: socket.UDPExtraOptions = {
      broadcast: true,
      socketTimeout: 3000,
      receiveBufferSize: 1000,
      sendBufferSize: 1000,
      reuseAddress: false
    }
    udp.setExtraOptions(udpExtraOptions, (err: BusinessError) => {
      if (err) {
        LogUtil.error(err.message)
        return
      }
      LogUtil.info('setExtraOptions success')
    })
  })

  let sendOptions: socket.UDPSendOptions = {
    data: getDeviceInfo(),
    address: targetAddress
  }
  udp.send(sendOptions).then(() => {
    LogUtil.info('send success')
  }).catch((err: BusinessError) => {
    LogUtil.error(`send failed: ${err.message}`)
  })
  // let localIp = NetworkUtil.getIpAddress()
  // for (let i = 0; i < 255; i++) {
  //   let remoteIp: socket.NetAddress = {} as socket.NetAddress
  //   remoteIp.address = localIp.substring(0, localIp.lastIndexOf('.') + 1) + i
  //   remoteIp.port = 53317
  //   let udpConnect: socket.UDPSendOptions = {} as socket.UDPSendOptions
  //   udpConnect.address = remoteIp
  // }
}