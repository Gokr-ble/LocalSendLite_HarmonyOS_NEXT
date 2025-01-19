import axios, { AxiosResponse } from '@ohos/axios'
import { LogUtil, NetworkUtil } from '@pura/harmony-utils'
import { RegisteredDevice } from '../model/RegisteredDevice'
import { taskpool } from '@kit.ArkTS'
import { preferences } from '@kit.ArkData';
import { getDeviceInfo } from '../model/DeviceInfo';
import { DialogHelper } from '@pura/harmony-dialog';
import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { getConfigPreference } from './ReadConfig';

let dataPreferences = getConfigPreference()

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
export async function tcpScan(dialogId: string, scanIPRange: string = NetworkUtil.getIpAddress()): Promise<void> {
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

class SocketInfo {
  message: ArrayBuffer = new ArrayBuffer(1);
  remoteInfo: socket.SocketRemoteInfo = {} as socket.SocketRemoteInfo
}

export function udpBroadcast() {
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