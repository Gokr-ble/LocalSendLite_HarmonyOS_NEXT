import { rcp } from '@kit.RemoteCommunicationKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { readFile } from '../utils/ReadFile'
import { fileIo } from '@kit.CoreFileKit'
import { CryptoJS } from '@ohos/crypto-js'
import { CryptoUtil, DeviceUtil, FileUtil, LogUtil, NetworkUtil, RandomUtil, ToastUtil } from '@pura/harmony-utils'
import { preferences } from '@kit.ArkData'
import { DialogHelper, SpinType } from '@pura/harmony-dialog'
import { socket } from '@kit.NetworkKit'
import { taskpool } from '@kit.ArkTS'
import axios, { AxiosError, AxiosResponse } from '@ohos/axios'
import { curves } from '@kit.ArkUI'
import { continuationManager } from '@kit.AbilityKit'

let dataPreferences = preferences.getPreferencesSync(getContext(), { name: 'config.db' });

let effect: object = TransitionEffect.OPACITY
  .combine(TransitionEffect.scale({ x: 0, y: 0 }).animation({ curve: curves.springMotion(0.6, 1.2) }))

let localIP = NetworkUtil.getIpAddress()

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
  @State receiverIP: string = '未选择'
  @State fileName: string = '未选择'
  @State fileUri: string = ''
  @State scanIPRange: string = NetworkUtil.getIpAddress()

  @StorageLink('deviceList') localDevices: Array<string> = []

  // aboutToAppear(): void {
  //   // 开启加载弹窗
  //   let dialogId = DialogHelper.showLoadingDialog({
  //     loadType: SpinType.spinP,
  //     loadColor: Color.White,
  //     loadSize: 70,
  //     backgroundColor: '#BB000000',
  //     content: "扫描中……",
  //     fontSize: 16,
  //     padding: {
  //       top: 30,
  //       right: 50,
  //       bottom: 30,
  //       left: 50
  //     },
  //     autoCancel: false
  //   })
  //   tcpScan(dialogId)
  //   this.localDevices = AppStorage.get('deviceList') || []
  // }

  build() {

    Column() {
      Row() {
        Text('接收IP')
          .margin({ right: '16vp' })
          .width('15%')

        TextInput({ text: this.receiverIP })
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
          .height('40vp')
          .padding({ left: '16vp' })
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
          if (this.fileUri == '') {
            ToastUtil.showToast("请选择文件")
          } else if (this.receiverIP == '') {
            ToastUtil.showToast("请输入接收IP")
          } else if (!validLocalIP(this.receiverIP)) {
            ToastUtil.showToast('接收IP非法')
          } else {
            sendFile(this.fileUri, this.receiverIP)
          }
        })

      Text('请确保目标连接的是同一个Wi-Fi网络')
        .width('90%')
        .margin({ bottom: '8vp' })
        .textAlign(TextAlign.Center)
      Text(`当前扫描范围：${this.scanIPRange}`)
        .width('90%')
        .margin({ bottom: '16vp' })
        .textAlign(TextAlign.Center)

      Row({ space: 4 }) {
        TextInput({ placeholder: this.scanIPRange })
          .width('50%')
          .onChange((value: string) => {
            this.scanIPRange = value
          })
        Button('扫描本地网络')
          .width('40%')
          .onClick(() => {
            if (!validLocalIP(this.scanIPRange)) {
              ToastUtil.showToast('扫描IP段非法')
            } else {
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
              tcpScan(dialogId, this.scanIPRange).then(() => {
                this.localDevices = AppStorage.get('deviceList') || []
              })
            }



          })
      }
      .alignItems(VerticalAlign.Center)


      List() {
        ForEach(this.localDevices, (item: string) => {
          ListItem() {
            Row() {
              Text(JSON.parse(item).ip)
                .margin({ right: '4vp' })
              Text(JSON.parse(item).alias)
                .margin({ right: '4vp'})
              Text(JSON.parse(item).deviceType)
                .margin({ right: '4vp'})
            }
            .width('90%')
            .height(64)
            .margin('8vp')
            .borderRadius($r('sys.float.corner_radius_level4'))
            .shadow({ radius: 8, color: Color.Gray })
            .justifyContent(FlexAlign.Center)
            .transition(effect)
            // .margin({ top: '8vp', left: '4vp', right: '4vp', bottom: '8vp'})
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .onClick(() => {
            LogUtil.info(`Selected IP: ${JSON.parse(item).ip}`)
            this.receiverIP = JSON.parse(item).ip
          })
        }, (item: string) => JSON.parse(item).fingerprint)
      }
      .alignListItem(ListItemAlign.Center)
      .width('90%')
      .height('200vp')
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
    fingerprint: CryptoUtil.digestSync(deviceId, 'SHA256'), // CryptoJS.SHA256(deviceId).toString(),
    port: port,
    protocol: proto,
    download: false
  })
}

@Concurrent
async function scanOneIp(remoteIp: string, deviceInfo: string, timeOut: number) {
  LogUtil.info(`${remoteIp} is scanning`)
  const url = `http://${remoteIp}:53317/api/localsend/v2/register`

  let result = ''
  try {
    const response: AxiosResponse<RegisteredDevice> = await axios.post<RegisteredDevice, AxiosResponse<RegisteredDevice>, string>(url, deviceInfo, { timeout: timeOut })
    result = JSON.stringify(response)
  } catch (error) {
    if (axios.isAxiosError(error)) {
      result = error.message
    } else {
      result = ''
    }
  }
  return result
}

/**
 * 使用http方式扫描指定的局域网段
 * @param dialogId
 * @param scanIPRange
 * @returns
 */
async function tcpScan(dialogId: string, scanIPRange: string = NetworkUtil.getIpAddress()): Promise<void> {
  let localIp = NetworkUtil.getIpAddress()
  // let lastTag = parseInt(localIp.substring(localIp.lastIndexOf('.') + 1))
  // let ipSeg = localIp.substring(0, localIp.lastIndexOf('.') + 1)

  let ipSeg = scanIPRange.substring(0, scanIPRange.lastIndexOf('.') + 1)

  let searchTime = dataPreferences.getSync('searchTimeout', 1000) as number
  // let deviceList: Array<string> = AppStorage.get('deviceList') || []
  let deviceList: Array<string> = []
  let taskGroup = new taskpool.TaskGroup()
  for (let i = 0; i < 255; i++) {
    let remoteIp = ipSeg + i
    if (remoteIp === localIp) continue
    let task: taskpool.Task = new taskpool.Task(scanOneIp, remoteIp, getDeviceInfo(), searchTime)
    taskGroup.addTask(task)
  }

  taskpool.execute(taskGroup).then((ret: object) => {
    for (let i = 0; i < (ret as Array<string>).length; i++) {
      let ip = ipSeg + i
      let rawData = (ret as Array<string>)[i]
      LogUtil.info(`${ip}: ${rawData}`)
      if (rawData.indexOf('data') !== -1) {
        // let deviceInfo: RegisteredDevice = JSON.parse(rawData).data
        let deviceInfo: RegisteredDevice = JSON.parse(rawData).data as RegisteredDevice
        deviceInfo.ip = ip
        deviceInfo.port = deviceInfo.port || 53317
        deviceInfo.protocol = deviceInfo.protocol || 'http'
        let deviceString = JSON.stringify(deviceInfo)

        LogUtil.info(`deviceInfo: ${deviceString}`)
        deviceList.push(deviceString)
      }
    }
    if (deviceList.length > 0) {
      AppStorage.setOrCreate('deviceList', deviceList)
      LogUtil.info(`scan finished, deviceList len=${deviceList.length}, data=${deviceList}`)
    } else {
      LogUtil.info(`scan finished, deviceList is Empty}`)
    }
  }).catch((error: BusinessError) => {
    LogUtil.error(error.message)
  }).finally(() => {
    DialogHelper.closeDialog(dialogId)
  })

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

async function sendFile(fileUri: string, receiverIP: string) {
  // check target reachable
  let testRcp = rcp.createSession()
  let testRequest = new rcp.Request(`http://${receiverIP}:53317/api/localsend/v2/info`)
  let timeout: rcp.Timeout = { inactivityMs: 3000 }
  testRequest.configuration = {
    transfer: {
      timeout: timeout
    }
  }
  try {
    await testRcp.fetch(testRequest)
  } catch (e) {
    LogUtil.error(`${receiverIP} is not reachable, err: ${e}`)
    ToastUtil.showToast(`${receiverIP} is not reachable`)
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
  let file = fileIo.openSync(fileUri, fileIo.OpenMode.READ_ONLY)
  let stat = fileIo.statSync(file.fd)
  let fileId = RandomUtil.generateUUID32()
  let fileName = decodeURI(fileUri.substring(fileUri.lastIndexOf('/') + 1, fileUri.length))
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

  let header: rcp.RequestHeaders = { 'content-type': 'application/json' }
  const preUploadSession = rcp.createSession({ headers: header })
  preUploadSession.post(`http://${receiverIP}:53317/api/localsend/v2/prepare-upload`,
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
            uploadSession.post(`http://${receiverIP}:53317/api/localsend/v2/upload?sessionId=${sessionId}&fileId=${fileId}&token=${fileToken}`,
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

}

function validLocalIP(ip: string): boolean {
  const ipFormat = /^(\d{1,3}\.){3}\d{1,3}$/
  if (!ipFormat.test(ip)) {
    return false
  }
  const parts = ip.split('.').map(Number)
  if (parts[0] === 10) {
    return true
  }
  if (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) {
    return true
  }
  if (parts[0] === 192 && parts[1] === 168) {
    return true
  }
  return false
}