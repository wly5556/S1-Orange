@Builder
export function ErrorTips(text: string) {
  Column() {
    Image($r('app.media.face_253_akarin'))
      .width(50)
      .height(50)
      .opacity(0.4)
      .margin(20)
    Text(text).fontSize(20)
  }
}