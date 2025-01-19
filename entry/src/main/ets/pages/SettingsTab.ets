import { LogUtil } from "@pura/harmony-utils"
import { preferences } from '@kit.ArkData';
import { BusinessError } from "@kit.BasicServicesKit";
import { common } from "@kit.AbilityKit";
import { getConfigPreference } from "../utils/ReadConfig";

let dataPreferences = getConfigPreference()

@Component
@Preview
export struct SettingsTab {
  @State deviceAlias: string = ''
  @State deviceType: string = ''
  @State deviceModel: string = ''
  @State port: number = 0
  @State searchTimeout: number = 0
  @State encryptOn: boolean = false
  @State multicast: string = ''
  @State showRestartServerHind: boolean = false

  aboutToAppear() {
    let context = getContext(this) as common.UIAbilityContext
    LogUtil.info(`[*] pref path: ${context.getApplicationContext().preferencesDir}`)

    this.deviceAlias = dataPreferences.getSync('alias', 'default') as string
    this.deviceType = dataPreferences.getSync('deviceType', 'default') as string
    this.deviceModel = dataPreferences.getSync('deviceModel', 'default') as string
    this.port = dataPreferences.getSync('serverPort', 53317) as number
    this.searchTimeout = dataPreferences.getSync('searchTimeout', 1000) as number
    this.encryptOn = dataPreferences.getSync('encryptOn', 'default') as boolean
    this.multicast = dataPreferences.getSync('multicastAddress', 'default') as string
    this.showRestartServerHind = dataPreferences.getSync('showRestartServerHind', 'default') as boolean
  }

  build() {
    Column() {
      Row() {
        Text('别名')
          .width('20%')
        TextInput({ text: `${this.deviceAlias}` })
          .width('70%')
          .onChange((value: string) => {
            this.deviceAlias = value
          })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('设备类型')
          .width('20%')
        TextInput({ text: `${this.deviceType}` })
          .width('70%')
          .onChange((value: string) => {
            this.deviceType = value
          })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('设备型号')
          .width('20%')
        TextInput({ text: `${this.deviceModel}` })
          .width('70%')
          .onChange((value: string) => {
            this.deviceModel = value
          })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('端口')
          .width('20%')
        TextInput({ text: `${this.port}` })
          .width('70%')
          .onChange((value: string) => {
            this.port = parseInt(value)
          })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('搜索超时')
          .width('20%')
        TextInput({ text: `${this.searchTimeout}` })
          .width('70%')
          .onChange((value: string) => {
            this.searchTimeout = parseInt(value)
          })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('加密')
          .width('20%')
        Column() {
          Toggle({ type: ToggleType.Switch, isOn: this.encryptOn})
            .onChange((isOn: boolean) => {
              if (isOn) {
                LogUtil.info('SSL/TLS Enabled')
              } else {
                LogUtil.info('SSL/TLS Disabled')
              }
              this.encryptOn = isOn
            })
        }
        .width('70%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('多播地址')
          .width('20%')
        TextInput({ text: `${this.multicast}` })
          .width('70%')
          .onChange((value: string) => {
            this.multicast = value
          })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Button('保存')
        .width('90%')
        .margin({ bottom: '8vp' })
        .onClick(() => {
          dataPreferences.putSync('alias', this.deviceAlias)
          dataPreferences.putSync('deviceType', this.deviceType)
          dataPreferences.putSync('deviceModel', this.deviceModel)
          dataPreferences.putSync('serverPort', this.port)
          dataPreferences.putSync('searchTimeout', this.searchTimeout)
          dataPreferences.putSync('encryptOn', this.encryptOn)
          dataPreferences.putSync('multicastAddress', this.multicast)
          this.showRestartServerHind = true
          dataPreferences.flush((err: BusinessError) => {
            if (err) {
              LogUtil.error(`Preferences flush() error with code ${err.code}, message: ${err.message}`)
            } else {
              LogUtil.info('Preferences flush() successfully')
            }
          })
        })

      Column() {
        Text(`请重新启动应用使配置生效`)
          .fontColor('#ef6c00')
          .visibility(this.showRestartServerHind ? Visibility.Visible : Visibility.Hidden)
      }
      .width('90%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}