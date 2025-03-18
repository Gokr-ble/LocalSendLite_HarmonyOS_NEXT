import { rcp } from '@kit.RemoteCommunicationKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { pickFile, pickMedia } from '../utils/PickFile'
import { fileIo } from '@kit.CoreFileKit'
import { CryptoJS } from '@ohos/crypto-js'
import { CryptoUtil, DeviceUtil, FileUtil, LogUtil, NetworkUtil, RandomUtil, ToastUtil } from '@pura/harmony-utils'
import { preferences } from '@kit.ArkData'
import { DialogAction, DialogHelper, SpinType } from '@pura/harmony-dialog'
import { socket } from '@kit.NetworkKit'
import { taskpool } from '@kit.ArkTS'
import axios, { AxiosError, AxiosResponse } from '@ohos/axios'
import { curves } from '@kit.ArkUI'
import { continuationManager } from '@kit.AbilityKit'
import { tcpScan } from '../utils/ScanLocalNetwork'
import { getConfigPreference } from '../utils/ReadConfig'
import { sendFile } from '../utils/SendFile'
import { ShareController } from '../controller/ShareController'

let dataPreferences = getConfigPreference()

@AnimatableExtend(LoadingProgress)
function animatableWidth(width: number) {
  .width(width)
}

@Component
@Preview
export struct SendTab {
  @State receiverIP: string = '未选择'
  @StorageLink('fileDisplayName') fileName: string = '未选择'
  @StorageLink('fileUriList') fileUriList: string[] = []
  @StorageLink('scanIPRange') scanIPRange: string = NetworkUtil.getIpAddress()
  @StorageLink('deviceList') localDevices: Array<string> = []
  @StorageLink('scanFinished') scanFinished: boolean = false;

  @State loadingProgressWidth: number = 0;
  private isText = false;

  aboutToAppear(): void {
    if (AppStorage.has('fileUriList')) {
      this.clearFileData()
      this.fileUriList = AppStorage.get('fileUriList') || []
      if (this.fileUriList.length > 0) {
        this.fileName = uriListToFileName(this.fileUriList)
      }
    }
    if (this.scanIPRange === '0.0.0.0')
      this.scanIPRange = '192.168.43.1'
  }

  private clearFileData = () => {
    this.fileName = '未选择'
    this.fileUriList = []
  }

  private setFileData = (uriList: string[]) => {
    if (uriList.length > 0) {
      this.fileUriList = uriList
      this.fileName = uriListToFileName(this.fileUriList)
    }
  }

  private parseDeviceTypeImage = (deviceType: string) => {
    let result = $r('app.media.device_type_unknown')
    if (deviceType === 'desktop') {
      result = $r('app.media.device_type_desktop')
    } else if (deviceType === 'mobile') {
      result = $r('app.media.device_type_mobile')
    }
    return result
  }

  private changeLoadingStatus = () => {
    this.loadingProgressWidth = this.loadingProgressWidth === 0 ? 24 : 0
  }

  build() {
    Column({ space: 16 }) {
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
      // .margin({ bottom: '16vp' })

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

      Row({ space: 4 }) {
        Button(){
          Row({ space: 4 }) {
            Image($r('app.media.file_type_media'))
              .width(30)
              .height(30)
              .margin(4)
            Text('媒体')
              .fontColor(0xFFFFFF)
          }
        }
          .width('32%')
          .onClick(async () => {
            this.isText = false
            let uriList: string[] = await pickMedia()
            this.fileName = uriListToFileName(uriList)
            this.fileUriList = uriList
          })
        Button(){
          Row({ space: 4 }) {
            Image($r('app.media.file_type_text'))
              .width(30)
              .height(30)
              .margin(4)
            Text('文本')
              .fontColor(0xFFFFFF)
          }
        }
          .width('32%')
          .onClick(async () => {
            this.isText = true
            DialogHelper.showTextAreaDialog({
              title: '发送文本',
              text: '',
              onChange: (text)=>{
                // sendText = text
              },
              onAction:(action, dialogId, content) => {
                if (action == DialogAction.SURE) {
                  // 确认发送
                  this.fileName = content
                  this.fileUriList = []
                  this.fileUriList.push(content)
                }
              }
            })
            // let uriList: string[] = await pickFile()
            // this.fileName = uriListToFileName(uriList)
            // this.fileUriList = uriList
          })
        Button() {
          Row({ space: 4 }) {
            Image($r('app.media.file_type_file'))
              .width(30)
              .height(30)
              .margin(4)
            Text('文件')
              .fontColor(0xFFFFFF)
          }

        }
          .width('32%')
          .onClick(async () => {
            this.isText = false
            let uriList: string[] = await pickFile()
            this.fileName = uriListToFileName(uriList)
            this.fileUriList = uriList
          })
      }
      .width('90%')

      Button('发送文件')
        .width('90%')
        // .margin({ bottom: '16vp' })
        .onClick(async () => {
          if (this.fileUriList.length === 0) {
            ToastUtil.showToast("请选择文件")
          } else if (this.receiverIP === '') {
            ToastUtil.showToast("请输入接收IP")
          } else if (!validLocalIP(this.receiverIP)) {
            ToastUtil.showToast('接收IP非法')
          } else {
            if (this.isText) {
              sendFile(this.fileUriList, this.receiverIP, true)
            } else {
              sendFile(this.fileUriList, this.receiverIP)
            }
          }
        })

      Text('请确保目标连接的是同一个Wi-Fi网络')
        .width('90%')
        // .margin({ bottom: '8vp' })
        .textAlign(TextAlign.Center)
      Text(`当前扫描范围：${this.scanIPRange}`)
        .width('90%')
        // .margin({ bottom: '16vp' })
        .textAlign(TextAlign.Center)

      Row({ space: 4 }) {
        TextInput({ placeholder: this.scanIPRange })
          .width('50%')
          .onChange((value: string) => {
            this.scanIPRange = value
          })
        Button() {
          Row() {
            LoadingProgress()
              .animatableWidth(this.loadingProgressWidth)
              .animation({ duration: 1000, curve: Curve.Ease })
              .height(24)
              .color(0xFFFFFF)
              // .enableLoading(!this.scanFinished)
            Text('扫描本地网络')
              .margin({ left: '4vp', right: '4vp' })
              .fontColor(0xFFFFFF)
          }.alignItems(VerticalAlign.Center)
        }
        .width('40%')
        .height('40vp')
        .onClick(async () => {
          if (!validLocalIP(this.scanIPRange)) {
            ToastUtil.showToast('扫描IP段非法')
          } else {
            // 开启加载弹窗
            // let dialogId = DialogHelper.showLoadingDialog({
            //   // loadType: SpinType.spinP,
            //   loadColor: Color.White,
            //   loadSize: 70,
            //   backgroundColor: '#BB000000',
            //   content: "扫描中……",
            //   fontSize: 16,
            //   padding: {
            //     top: 30,
            //     right: 50,
            //     bottom: 30,
            //     left: 50
            //   },
            //   autoCancel: false
            // })
            // AppStorage.setOrCreate('scanFinished', false)
            this.changeLoadingStatus()
            await tcpScan('', this.scanIPRange)
            this.changeLoadingStatus()
          }
        })
      }
      .alignItems(VerticalAlign.Center)

      List() {
        ForEach(this.localDevices, (item: string) => {
          ListItem() {
            Row() {
              Image(this.parseDeviceTypeImage(JSON.parse(item).deviceType))
                .width('48vp')
                .height('48vp')
                .objectFit(ImageFit.Contain)
                .margin('8vp')
              Column({ space: 4 }) {
                Text(JSON.parse(item).alias)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                Text(JSON.parse(item).ip)
                  .fontSize(14)
              }
            }
            .width('90%')
            .height(64)
            .margin('8vp')
            .borderRadius($r('sys.float.corner_radius_level4'))
            .shadow({ radius: 8, color: Color.Gray })
            .justifyContent(FlexAlign.Center)
            .transition(TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0, y: 0 }).animation({ curve: curves.springMotion(0.6, 1.2) })))
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

function uriToFileName(uri: string): string {
  return decodeURI(uri.substring(uri.lastIndexOf('/') + 1, uri.length))
}

function uriListToFileName(uriList: string[]): string {
  let displayName = ''
  for (let i = 0; i < uriList.length; i++) {
    displayName += decodeURI(uriList[i].substring(uriList[i].lastIndexOf('/') + 1, uriList[i].length))
    if (uriList.length > 1 && i < uriList.length - 1) {
      displayName += ','
    }
  }
  return displayName
}