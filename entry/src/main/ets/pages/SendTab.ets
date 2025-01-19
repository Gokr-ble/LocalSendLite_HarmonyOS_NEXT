import { rcp } from '@kit.RemoteCommunicationKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { pickFile } from '../utils/PickFile'
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
import { tcpScan } from '../utils/ScanLocalNetwork'
import { getConfigPreference } from '../utils/ReadConfig'
import { sendFile } from '../utils/SendFile'

let dataPreferences = getConfigPreference()

@Component
@Preview
export struct SendTab {
  @State receiverIP: string = '未选择'
  @State fileName: string = '未选择'
  @State fileUriList: string[] = []
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
          .textOverflow({ overflow: TextOverflow.MARQUEE })
      }
      .width('85%')
      .margin({ bottom: '16vp' })

      Button('选择文件')
        .width('90%')
        .margin({ bottom: '16vp' })
        .onClick(async () => {
          let uriList: string[] = await pickFile()
          let displayName = ''
          for (let i = 0; i < uriList.length; i++) {
            displayName += decodeURI(uriList[i].substring(uriList[i].lastIndexOf('/') + 1, uriList[i].length))
            if (uriList.length > 1 && i < uriList.length - 1) {
              displayName += ','
            }
          }
          this.fileName = displayName
          this.fileUriList = uriList
        })

      Button('发送文件')
        .width('90%')
        .margin({ bottom: '16vp' })
        .onClick(async () => {
          if (this.fileUriList.length === 0) {
            ToastUtil.showToast("请选择文件")
          } else if (this.receiverIP === '') {
            ToastUtil.showToast("请输入接收IP")
          } else if (!validLocalIP(this.receiverIP)) {
            ToastUtil.showToast('接收IP非法')
          } else {
            sendFile(this.fileUriList, this.receiverIP)
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
                // loadType: SpinType.spinP,
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
                .margin({ right: '4vp' })
              Text(JSON.parse(item).deviceType)
                .margin({ right: '4vp' })
            }
            .width('90%')
            .height(64)
            .margin('8vp')
            .borderRadius($r('sys.float.corner_radius_level4'))
            .shadow({ radius: 8, color: Color.Gray })
            .justifyContent(FlexAlign.Center)
            .transition(TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0, y: 0 }).animation({ curve: curves.springMotion(0.6, 1.2) })))

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