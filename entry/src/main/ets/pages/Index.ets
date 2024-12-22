import { DeviceUtil, LogUtil } from '@pura/harmony-utils';
import { ReceiveTab } from './ReceiveTab';
import { SendTab } from './SendTab';
import { SettingsTab } from './SettingsTab';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

let dataPreferences = preferences.getPreferencesSync(getContext(), { name: 'config.db' });

@Entry()
@Component
@Preview
struct Index {
  @State message: string = 'Hello World';

  aboutToAppear() {
    // 检查是否包含参数配置
    if (!dataPreferences.hasSync('alias')) {
      dataPreferences.putSync('alias', DeviceUtil.getDeviceId())
    }
    if (!dataPreferences.hasSync('deviceType')) {
      dataPreferences.putSync('deviceType', 'mobile')
    }
    if (!dataPreferences.hasSync('deviceModel')) {
      dataPreferences.putSync('deviceModel', DeviceUtil.getBrand())
    }
    if (!dataPreferences.hasSync('serverPort')) {
      dataPreferences.putSync('serverPort', 53317)
    }
    if (!dataPreferences.hasSync('searchTimeout')) {
      dataPreferences.putSync('searchTimeout', 1000)
    }
    if (!dataPreferences.hasSync('encryptOn')) {
      dataPreferences.putSync('encryptOn', false)
    }
    if (!dataPreferences.hasSync('multicastAddress')) {
      dataPreferences.putSync('multicastAddress', '224.0.0.167')
    }
    if (!dataPreferences.hasSync('showRestartServerHind')) {
      dataPreferences.putSync('showRestartServerHind', false)
    }
    dataPreferences.flush((err: BusinessError) => {
      if (err) {
        LogUtil.error(`Preferences flush() error with code ${err.code}, message: ${err.message}`)
      } else {
        LogUtil.info('Preferences flush() successfully')
      }
    })
  }

  build() {
    Column() {
      Column() {
        Text($r('app.string.title'))
          .width('90%')
          .textAlign(TextAlign.Start)
          .fontSize('30vp')
          .fontFamily('HarmonyHeiTi-Bold')
          .fontWeight(700)
          .margin({
            top: '7vp',
            bottom: '8vp',
            left: '24vp',
            right: '24vp'
          })
      }
      .width('90%')

      Tabs() {
        TabContent() {
          ReceiveTab()
        }
        .tabBar(new SubTabBarStyle($r('app.string.RecvBarTitle'))
          .indicator({ marginTop: '8vp' })
          .labelStyle({ font: { size: '16vp' } })
        )

        TabContent() {
          SendTab()
        }
        .tabBar(new SubTabBarStyle($r('app.string.SendBarTitle'))
          .indicator({ marginTop: '8vp' })
          .labelStyle({ font: { size: '16vp' }})
        )

        TabContent() {
          Scroll() {
            SettingsTab()
          }
          .width('100%')
        }
        .tabBar(new SubTabBarStyle($r('app.string.SettingsBarTitle'))
          .indicator({ marginTop: '8vp' })
          .labelStyle({ font: { size: '16vp' }})
        )
      }
      .barWidth('300vp')
      .width('100%')
    }
    .backgroundColor('#0D182431')
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }
}