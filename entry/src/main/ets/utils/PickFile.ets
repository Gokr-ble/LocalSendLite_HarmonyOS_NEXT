import { picker } from "@kit.CoreFileKit"
import { BusinessError } from "@kit.BasicServicesKit"
import { LogUtil } from "@pura/harmony-utils"
import { photoAccessHelper } from "@kit.MediaLibraryKit"

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

export function pickMedia(): Promise<string[]> {
  return new Promise((resolve, reject) => {
    try {
      let mediaSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      let mediaViewPicker = new photoAccessHelper.PhotoViewPicker();
      mediaViewPicker.select(mediaSelectOptions).then((result: photoAccessHelper.PhotoSelectResult) => {
        let uris = result.photoUris
        LogUtil.info(`photoViewPicker select success, len: ${uris.length}, uri: ${JSON.stringify(uris)}`)
        resolve(uris)
      }).catch((err: BusinessError) => {
        LogUtil.error(`photoViewPicker select failed: ${err.message}`)
      })
    } catch (error) {
      let err = error as BusinessError
      LogUtil.error(`failed: ${err.message}`)
      reject(err)
    }
  })
}