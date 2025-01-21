import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppUtil, LogUtil } from '@pura/harmony-utils';
import { DialogHelper, Orientation } from '@pura/harmony-dialog';
import { systemShare } from '@kit.ShareKit';
import { BusinessError } from '@kit.BasicServicesKit';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    // 工具类初始化
    AppUtil.init(this.context)
    LogUtil.init(0x1010, 'LocalSendLog', true)
    DialogHelper.setDefaultConfig((config) => {
      config.uiAbilityContext = this.context;
    })
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    LogUtil.info(JSON.stringify(want))
    if (want.action === "ohos.want.action.sendData") {
      systemShare.getSharedData(want)
        .then((data: systemShare.SharedData) => {
          let fileUriList: string[] = []
          data.getRecords().forEach((record: systemShare.SharedRecord) => {
            // 处理分享数据
            LogUtil.info(`SharedRecord:${record.uri}`)
            if (record.uri) {
              fileUriList.push(record.uri)
            }
          })
          if (fileUriList.length > 0) {
            AppStorage.setOrCreate('fileUriList', fileUriList)
            let displayName = ''
            for (let i = 0; i < fileUriList.length; i++) {
              displayName += decodeURI(fileUriList[i].substring(fileUriList[i].lastIndexOf('/') + 1, fileUriList[i].length))
              if (fileUriList.length > 1 && i < fileUriList.length - 1) {
                displayName += ','
              }
            }
            AppStorage.setOrCreate('fileDisplayName', displayName)
          }
        })
        .catch((error: BusinessError) => {
          LogUtil.error(`Failed to getSharedData, code:${error.code}, msg:${error.message}`)
          this.context.terminateSelf()
        })
    }
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}