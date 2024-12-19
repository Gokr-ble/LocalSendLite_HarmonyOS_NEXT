import { promptAction } from "@kit.ArkUI";

export function showToast(msg: string | Resource) {
  promptAction.showToast({
    message: msg,
    duration: 2000
  })
}