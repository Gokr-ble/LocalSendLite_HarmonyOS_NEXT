import { Logger } from "@ohos/polka/src/main/ets/common/util/log"
import { DeviceUtil, LogUtil } from "@pura/harmony-utils"

@Component
@Preview
export struct SettingsTab {
  build() {
    Column() {
      Row() {
        Text('别名')
          .width('20%')
        TextInput({ text: 'Mate 70 Pro+' })
          .width('70%')
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('设备类型')
          .width('20%')
        TextInput({ text: 'mobile' })
          .width('70%')
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('设备型号')
          .width('20%')
        TextInput({ text: 'Huawei' })
          .width('70%')
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('端口')
          .width('20%')
        TextInput({ text: '53317' })
          .width('70%')
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('搜索超时')
          .width('20%')
        TextInput({ text: '1000' })
          .width('70%')
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })

      Row() {
        Text('加密')
          .width('20%')
        Column() {
          Toggle({ type: ToggleType.Switch, isOn: false})
            .onChange((isOn: boolean) => {
              if (isOn) {
                LogUtil.info('SSL/TLS Enabled')
              } else {
                LogUtil.info('SSL/TLS Disabled')
              }
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
        TextInput({ text: '224.0.0.167' })
          .width('70%')
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: '8vp' })
    }
    .width('100%')
    .height('100%')
  }
}