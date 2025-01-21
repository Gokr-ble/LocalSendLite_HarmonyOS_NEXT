import axios, { AxiosResponse } from "@ohos/axios"
import { DialogHelper, SpinType } from "@pura/harmony-dialog"
import { DeviceUtil, FileUtil, LogUtil, RandomUtil, ToastUtil } from "@pura/harmony-utils"
import { RegisteredDevice } from "../model/RegisteredDevice"
import { fileIo } from "@kit.CoreFileKit"
import { preferences } from "@kit.ArkData"
import { getConfigPreference } from "./ReadConfig"
import { getDeviceInfo } from "../model/DeviceInfo"
import { PreUploadRequest, PreUploadResponse } from "../model/PreUploadResponse"
import { FileInfoSent } from "../model/FileInfo"

export async function sendFile(fileUriList: string[], receiverIP: string) {
  // 检测目标是否可达
  const url = `http://${receiverIP}:53317/api/localsend/v2/info`
  try {
    let response: AxiosResponse<RegisteredDevice> = await axios.get<RegisteredDevice, AxiosResponse<RegisteredDevice>, null>(url, {timeout: 3000})
    // 暂时忽略 response
    LogUtil.info(JSON.stringify(response))
    // 开启加载弹窗
    let dialogId = DialogHelper.showLoadingDialog({
      // loadType: SpinType.spinP,
      loadColor: Color.White,
      loadSize: 70,
      backgroundColor: '#BB000000',
      content: "传输中……",
      fontSize: 16,
      padding: {
        top: 30,
        right: 50,
        bottom: 30,
        left: 50
      },
      autoCancel: false
    })

    let preUploadRequest: PreUploadRequest = {
      info: JSON.parse(getDeviceInfo()),
      files: {}
    }

    let fileInfoSentList: FileInfoSent[] = []

    // 读取文件信息
    fileUriList.forEach((fileUri: string) => {
      let file = fileIo.openSync(fileUri, fileIo.OpenMode.READ_ONLY)
      let stat = fileIo.statSync(file.fd)
      let fileId = RandomUtil.generateUUID32()
      let fileName = decodeURI(fileUri.substring(fileUri.lastIndexOf('/') + 1, fileUri.length))
      let fileExt = FileUtil.getFileExtention(fileName)
      preUploadRequest.files[fileId] = {
        id: fileId,
        fileName: fileName,
        size: stat.size,
        fileType: fileExt == '' ? fileExt : 'application/octet-stream'
      }
      fileInfoSentList.push({
        fileUri: fileUri,
        fileId: fileId,
        fileToken: ''
      })
    })

    let preUploadUrl = `http://${receiverIP}:53317/api/localsend/v2/prepare-upload`
    try {
      let preUploadResp: AxiosResponse<PreUploadResponse> =
        await axios.post<PreUploadResponse, AxiosResponse<PreUploadResponse>, string>
        (preUploadUrl, JSON.stringify(preUploadRequest), { timeout: 3000, headers: { "Content-Type": "application/json" } })
      let sessionId: string = preUploadResp.data.sessionId
      fileInfoSentList.forEach(async (fileInfo) => {
        if (preUploadResp.data.files[fileInfo.fileId]) {
          fileInfo.fileToken = preUploadResp.data.files[fileInfo.fileId]
          let file = fileIo.openSync(fileInfo.fileUri, fileIo.OpenMode.READ_ONLY)
          let stat = fileIo.statSync(file.fd)
          let readBuff = new ArrayBuffer(stat.size)
          let readBytes = fileIo.readSync(file.fd, readBuff)
          if (readBytes > 0) {
            let uploadUrl = `http://${receiverIP}:53317/api/localsend/v2/upload?sessionId=${sessionId}&fileId=${fileInfo.fileId}&token=${fileInfo.fileToken}`
            try {
              let uploadResp: AxiosResponse<string> =
                await axios.post<string, AxiosResponse<string>, ArrayBuffer>(uploadUrl, readBuff, { timeout: 3000 })
              if (uploadResp.status == 200) {
                LogUtil.info(`upload succeed: [${response.status}] ${response.data}`)
                // ToastUtil.showToast('发送成功')
              } else {
                LogUtil.error(`upload failed: [${response.status}] ${response.data}`)
                // ToastUtil.showToast('发送失败')
              }
            } catch (error) {
              LogUtil.error(`upload Error: ${error}`)
            } finally {
              DialogHelper.closeDialog(dialogId)
            }
          }
        }
      })
      ToastUtil.showToast(`发送成功，共发送${fileInfoSentList.length}个文件`)
    } catch (error) {
      if (axios.isAxiosError(error)) {
        LogUtil.error(`pre-upload Error: ${error.message}`)
        ToastUtil.showToast(`发送失败：${error.message}`)
      }
      DialogHelper.closeDialog(dialogId)
    }

  } catch (error) {
    LogUtil.error(`${receiverIP} is not reachable`)
    ToastUtil.showToast(`${receiverIP} is not reachable`)
    if (axios.isAxiosError(error)) {
      LogUtil.error(error.message)
    }
  }
}