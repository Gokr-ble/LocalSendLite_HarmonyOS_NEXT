import { AnimatorOptions, AnimatorResult } from "@kit.ArkUI"
import { LogUtil } from "@pura/harmony-utils"
import { AnimController } from "../controller/AnimController"


@Component
export struct LogoIndicator {
  @State angle: number = 0
  @StorageLink('animatorOption') animatorOption: AnimatorOptions = {
    duration: 8000,
    delay: 0,
    easing: 'linear',
    iterations: -1,
    fill: 'forwards',
    direction: 'normal',
    begin: 0,
    end: 360
  }
  @StorageLink('animatorOptions') animatorOptions: AnimatorResult | undefined = undefined

  // @State animatorOptions: AnimatorResult | undefined = undefined
  // @State animatorOption: AnimatorOptions = {
  //   duration: 8000,
  //   delay: 0,
  //   easing: 'linear',
  //   iterations: -1,
  //   fill: 'forwards',
  //   direction: 'normal',
  //   begin: 0,
  //   end: 360
  // }
  // @State animatorStatus: string = '创建'

  // controller: AnimController = new AnimController()
  //
  // aboutToAppear(): void {
  //   if (this.controller) {
  //     this.controller.playAnimation = this.playAnimation
  //     this.controller.pauseAnimation = this.pauseAnimation
  //     this.controller.resetAnimation = this.resetAnimation
  //     this.controller.finishAnimation = this.finishAnimation
  //     this.controller.cancelAnimation = this.cancelAnimation
  //   }
  // }
  //
  // private playAnimation = () => {
  //   this.animatorOptions?.play()
  // }
  //
  // private pauseAnimation = () => {
  //   this.animatorOptions?.pause()
  // }
  //
  // private resetAnimation = () => {
  //   this.angle = 0
  // }
  //
  // private finishAnimation = () => {
  //   this.animatorOptions?.finish()
  // }
  //
  // private cancelAnimation = () => {
  //   this.animatorOptions?.cancel()
  // }
  //
  // onPageShow(): void {
  //   this.animatorOptions = this.getUIContext().createAnimator(this.animatorOption)
  //   this.animatorOptions.onFrame = (progress: number) => {
  //     this.angle = progress
  //   }
  //   this.animatorOptions.onCancel = () => {
  //     LogUtil.info('动画取消')
  //   }
  //   this.animatorOptions.onFinish = () => {
  //     LogUtil.info('动画完成')
  //   }
  //   this.animatorOptions.onCancel = () => {
  //     LogUtil.info('动画重复播放')
  //   }
  // }

  // onPageHide(): void {
  //   this.animatorOptions = undefined
  // }

  build() {
    Image($r("app.media.RecvPageLogo"))
      .width('300vp')
      .height('300vp')
      .margin({ top: '24vp', bottom: '24vp'})
      .rotate({ angle: this.angle })
  }
}
