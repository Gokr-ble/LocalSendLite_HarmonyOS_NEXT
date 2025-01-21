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
import { AnimController } from '../controller/AnimController';


let dataPreferences = getConfigPreference()
// let registeredDeviceList: Array<RegisteredDevice> = []

let animatorOptions: AnimatorResult | undefined = undefined
let animatorOption: AnimatorOptions = {
  duration: 8000,
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

  animControllerRef = new AnimController()

  server: MyServer = new MyServer()

  aboutToAppear(): void {
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
    AppStorage.setOrCreate('animatorOptions', animatorOptions)
    AppStorage.setOrCreate('animatorOption', animatorOption)

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

  build() {
    Column() {
      Image($r("app.media.RecvPageLogo"))
        .width('300vp')
        .height('300vp')
        .margin({ top: '24vp', bottom: '24vp'})
        .rotate({ angle: this.angle })

      // LogoIndicator({ controller: this.animControllerRef })

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
