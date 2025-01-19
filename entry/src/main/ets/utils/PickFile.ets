import { picker } from "@kit.CoreFileKit"
import { BusinessError } from "@kit.BasicServicesKit"
import { LogUtil } from "@pura/harmony-utils"

export function pickFile(): Promise<string[]> {
  return new Promise((resolve, reject) => {
    try {
      let documentSelectOptions = new picker.DocumentSelectOptions()
      let documentPicker = new picker.DocumentViewPicker()
      documentPicker.select(documentSelectOptions).then((result: Array<string>) => {
        LogUtil.info(`documentPicker.select success, len: ${result.length}, uri: ${JSON.stringify(result)}`)
        resolve(result)
      }).catch((err: BusinessError) => {
        LogUtil.error(`documentPicker.select failed: ${JSON.stringify(err)}`)
      })
    } catch (error) {
      let err = error as BusinessError
      LogUtil.error(`documentPicker.select failed: ${err.message}`)
      reject(err)
    }
  })
  let srcUriList: string[] = []
  try {
    let documentSelectOptions = new picker.DocumentSelectOptions()
    let documentPicker = new picker.DocumentViewPicker()
    documentPicker.select(documentSelectOptions).then((result: Array<string>) => {
      LogUtil.info(`documentPicker.select success, len: ${result.length}, uri: ${JSON.stringify(result)}`)
      srcUriList = result
    }).catch((err: BusinessError) => {
      LogUtil.error(`documentPicker.select failed: ${JSON.stringify(err)}`)
    })
  } catch (error) {
    let err = error as BusinessError
    LogUtil.error(`documentPicker.select failed: ${err.message}`)
  }
  return Promise.resolve(srcUriList);
}