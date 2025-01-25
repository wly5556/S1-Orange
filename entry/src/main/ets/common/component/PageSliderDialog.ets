import { common } from '@kit.AbilityKit'

@CustomDialog
export struct SlideDialog {
  @Prop pageIndex: number
  @Prop totalPage: number
  jump: (page: number) => void = () => {
  }
  context = getContext(this) as common.UIAbilityContext
  controller: CustomDialogController

  isPageValid(value: string) {
    let page = -1
    if (isNaN(parseInt(value))) {
      page = 1
    }
    page = parseInt(value)
    if (page < 1) {
      page = 1
    }
    if (page > this.totalPage) {
      page = this.totalPage
    }
    this.pageIndex = page
  }

  build() {
    Column({ space: 16 }) {
      Text('跳转到指定页')
        .width('100%')
        .fontSize(20)
      TextInput({ text: `${this.pageIndex.toString()}` })
        .type(InputType.Number)
        .fontSize(28)
        .width('auto')
        .onChange(page => this.isPageValid(page))
        .onSubmit(() => {
          const page = this.pageIndex.toString()
          this.pageIndex = -1
          this.isPageValid(page)
        })
        .onBlur(() => {
          const page = this.pageIndex.toString()
          this.pageIndex = -1
          this.isPageValid(page)
        })
      Slider({
        value: $$this.pageIndex,
        min: 1,
        max: this.totalPage,
        style: SliderStyle.InSet
      })
      Row() {
        Button('取消', { buttonStyle: ButtonStyleMode.TEXTUAL }).onClick(() => this.controller.close())
          .margin({ right: 10 })
          .layoutWeight(1)
        Button('跳转', { buttonStyle: ButtonStyleMode.TEXTUAL })
          .margin({ left: 10 })
          .layoutWeight(1)
          .onClick(e => {
            this.jump(this.pageIndex)
            this.controller.close()
          })
      }.width('100%')
    }.padding(24)
  }
}