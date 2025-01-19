import { preferences } from "@kit.ArkData";
import { CryptoUtil, DeviceUtil } from "@pura/harmony-utils";
import { getConfigPreference } from "../utils/ReadConfig";

let dataPreferences = getConfigPreference()

export function getDeviceInfo() {
  let alias = dataPreferences.getSync('alias', 'default') as string
  let model = dataPreferences.getSync('deviceModel', 'default') as string
  let type = dataPreferences.getSync('deviceType', 'default') as string
  let proto = dataPreferences.getSync('encryptOn', 'default') as boolean ? 'https' : 'http'
  let port = dataPreferences.getSync('serverPort', 'default') as number
  let deviceId = DeviceUtil.getDeviceId(true)
  return JSON.stringify({
    alias: alias,
    version: "2.1",
    deviceModel: model,
    deviceType: type,
    fingerprint: CryptoUtil.digestSync(deviceId, 'SHA256'), // CryptoJS.SHA256(deviceId).toString(),
    port: port,
    protocol: proto,
    download: false
  })
}

export interface DeviceInfo {
  alias: string;
  version: string;
  deviceModel: string;
  deviceType: 'mobile' | 'desktop' | 'web' | 'headless' | 'server';
  fingerprint: string;
  port: number;
  protocol: string;
  download: boolean;
}