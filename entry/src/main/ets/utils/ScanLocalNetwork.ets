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
export async function tcpScan(dialogId: string, scanIPRange: string = NetworkUtil.getIpAddress()) {
  let localIp = NetworkUtil.getIpAddress()
  if (localIp === '0.0.0.0')
    localIp = '192.168.43.1'
  let ipSeg = scanIPRange.substring(0, scanIPRange.lastIndexOf('.') + 1)

  let searchTime = dataPreferences.getSync('searchTimeout', 1000) as number
  // let deviceList: Array<string> = AppStorage.get('deviceList') || []
  let deviceList: Array<string> = []
  let taskGroup = new taskpool.TaskGroup()
  for (let i = 0; i < 255; i++) {
    let remoteIp = ipSeg + i
    if (remoteIp === localIp || remoteIp === '192.168.43.1') continue
    let task: taskpool.Task = new taskpool.Task(scanOneIp, remoteIp, getDeviceInfo(), searchTime)
    taskGroup.addTask(task)
  }

  try {
    const ret = await taskpool.execute(taskGroup)
    for (let i = 0; i < (ret as Array<string>).length; i++) {
      let ip = ipSeg + i
      if (scanIPRange.includes('192.168.43'))
        ip = ipSeg + (i + 1)
      let rawData = (ret as Array<string>)[i]
      // LogUtil.info(`${ip}: ${rawData}`)
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
  } catch (error) {
    LogUtil.error(error.message)
  } finally {
    DialogHelper.closeDialog(dialogId)
  }
}

function tcpScanPromise(dialogId: string, scanIPRange: string = NetworkUtil.getIpAddress()): Promise<void> {
  return new Promise((resolve, reject) => {
    let localIp = NetworkUtil.getIpAddress();
    if (localIp === '0.0.0.0')
      localIp = '192.168.43.1';
    let ipSeg = scanIPRange.substring(0, scanIPRange.lastIndexOf('.') + 1);

    let searchTime = dataPreferences.getSync('searchTimeout', 1000) as number;
    let deviceList: Array<string> = [];
    let taskGroup = new taskpool.TaskGroup();

    for (let i = 0; i < 255; i++) {
      let remoteIp = ipSeg + i;
      if (remoteIp === localIp || remoteIp === '192.168.43.1') continue;
      let task: taskpool.Task = new taskpool.Task(scanOneIp, remoteIp, getDeviceInfo(), searchTime);
      taskGroup.addTask(task);
    }

    taskpool.execute(taskGroup)
      .then((ret) => {
        for (let i = 0; i < (ret as Array<string>).length; i++) {
          let ip = ipSeg + i;
          if (scanIPRange.includes('192.168.43'))
            ip = ipSeg + (i + 1);
          let rawData = (ret as Array<string>)[i];

          if (rawData.indexOf('data') !== -1) {
            let deviceInfo: RegisteredDevice = JSON.parse(rawData).data as RegisteredDevice;
            deviceInfo.ip = ip;
            deviceInfo.port = deviceInfo.port || 53317;
            deviceInfo.protocol = deviceInfo.protocol || 'http';
            let deviceString = JSON.stringify(deviceInfo);

            LogUtil.info(`deviceInfo: ${deviceString}`);
            deviceList.push(deviceString);
          }
        }

        if (deviceList.length > 0) {
          AppStorage.setOrCreate('deviceList', deviceList);
          LogUtil.info(`scan finished, deviceList len=${deviceList.length}, data=${deviceList}`);
        } else {
          LogUtil.info(`scan finished, deviceList is Empty}`);
        }
        resolve();
      })
      .catch((error: BusinessError) => {
        LogUtil.error(error.message);
        reject(error);
      })
      .finally(() => {
        DialogHelper.closeDialog(dialogId);
      });
  });
}
