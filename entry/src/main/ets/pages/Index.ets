import { ReceiveTab } from './ReceiveTab';
import { SendTab } from './SendTab';
import { SettingsTab } from './SettingsTab';
import polka, { Polka, Request } from '@ohos/polka'


@Entry()
@Component
@Preview
struct Index {
  @State message: string = 'Hello World';

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