import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { LogUtil } from '@pura/harmony-utils';
import { getDeviceInfo } from '../model/DeviceInfo';
import { util, buffer } from '@kit.ArkTS';


export function UDPBroadcast() {
  let udp: socket.UDPSocket = socket.constructUDPSocketInstance();
  let broadcastAddr : socket.NetAddress = {} as socket.NetAddress;
  broadcastAddr.address = "224.0.0.167";
  broadcastAddr.port = 53317;

  let udpSendOptions: socket.UDPSendOptions = {
    address: broadcastAddr,
    data: getDeviceInfo()
  }

  let localAddress: socket.NetAddress = {} as socket.NetAddress
  localAddress.address = '0.0.0.0'
  localAddress.port = 0

  udp.bind(localAddress).then(() => {
    LogUtil.info('bind 0.0.0.0 successfully')
    udp.send(udpSendOptions).then(() => {
      LogUtil.info('send 224.0.0.167:53317 successfully')
    }).catch((err: BusinessError) => {
      LogUtil.error(`send 224.0.0.167:53317 failed, err: ${err.message}`)
    })
  }).catch((err: BusinessError) => {
    LogUtil.error(`bind 0.0.0.0 failed, err: ${err.message}`)
  })

  udp.on('message', (value: socket.SocketMessageInfo) => {
    let msg = ArrayBufferToString(value.message)
    let remoteIp: string = value.remoteInfo.address
    let remotePort: number = value.remoteInfo.port
    LogUtil.info(`received udp message from ${remoteIp}:${remotePort}, ${msg}`)
  })

}

function ArrayBufferToString(buf: ArrayBuffer) {
  let msgArray = new Uint8Array(buf)
  let decoder = util.TextDecoder.create('utf-8')
  return decoder.decodeToString(msgArray)
}