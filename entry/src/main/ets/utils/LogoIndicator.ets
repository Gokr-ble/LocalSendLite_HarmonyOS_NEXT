import { AnimatorOptions, AnimatorResult } from "@kit.ArkUI"
import { LogUtil } from "@pura/harmony-utils"


@Component
export struct LogoIndicator {
  @State angle: number = 0
  @State animatorOptions: AnimatorResult | undefined = undefined
  @State animatorStatus: string = '创建'
  private begin: number = 0
  private end: number = 360
  animatorOption: AnimatorOptions = {
    duration: 4000,
    delay: 0,
    easing: 'linear',
    iterations: -1,
    fill: 'forwards',
    direction: 'normal',
    begin: this.begin,
    end: this.end
  }

  pauseAnimation() {
    this.animatorOptions?.pause()
  }

  resetAnimation() {
    this.angle = 0
  }

  finishAnimation() {
    this.animatorOptions?.finish()
  }

  cancelAnimation() {
    this.animatorOptions?.cancel()
  }

  onPageShow(): void {
    this.animatorOptions = this.getUIContext().createAnimator(this.animatorOption)
    this.animatorOptions.onFrame = (progress: number) => {
      this.angle = progress
    }
    this.animatorOptions.onCancel = () => {
      LogUtil.info('动画取消')
    }
    this.animatorOptions.onFinish = () => {
      LogUtil.info('动画完成')
    }
    this.animatorOptions.onCancel = () => {
      LogUtil.info('动画重复播放')
    }
  }

  onPageHide(): void {
    this.animatorOptions = undefined
  }

  build() {
    Image($r("app.media.RecvPageLogo"))
      .width('300vp')
      .height('300vp')
      .margin({ top: '24vp', bottom: '24vp'})
      .rotate({ angle: this.angle })
  }
}
