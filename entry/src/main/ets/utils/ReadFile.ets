import { picker } from "@kit.CoreFileKit"
import { BusinessError } from "@kit.BasicServicesKit"
import { LogUtil } from "@pura/harmony-utils"

export async function readFile(): Promise<string> {
  let srcUri = ''
  try {
    let documentSelectOptions = new picker.DocumentSelectOptions()
    let documentPicker = new picker.DocumentViewPicker()
    await documentPicker.select(documentSelectOptions).then((result: Array<string>) => {
      LogUtil.info(`documentPicker.select success, uri: ${JSON.stringify(result)}`)
      srcUri = result[0]
    }).catch((err: BusinessError) => {
      LogUtil.error(`documentPicker.select failed: ${JSON.stringify(err)}`)
    })
  } catch (error) {
    let err = error as BusinessError
    LogUtil.error(`documentPicker.select failed: ${err.message}`)
  }
  return srcUri;
}