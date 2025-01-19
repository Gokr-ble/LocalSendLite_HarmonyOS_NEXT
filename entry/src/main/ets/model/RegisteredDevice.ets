export interface RegisteredDevice {
  ip: string
  alias: string
  version: string
  deviceModel: string
  deviceType: string
  fingerprint: string
  port: number
  protocol: string
  download: boolean
}