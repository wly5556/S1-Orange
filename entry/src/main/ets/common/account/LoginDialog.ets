import { AniSpeed, AppearDisappearAni } from '../Animation';
import { login, LoginResult } from './AccountManager';
import { common } from '@kit.AbilityKit';


enum safeQuestionIndex {
  NO_QUESTION = 0,
  MOTHER_NAME = 1,
  GRANDFATHER_NAME = 2,
  FATHER_BIRTH_CITY = 3,
  TEACHER_NAME = 4,
  COMPUTER_MODEL = 5,
  FAVORITE_RESTAURANT = 6,
  DRIVING_LICENSE_LAST_FOUR = 7
}

const safeQuestionText: string[] = [];
safeQuestionText[safeQuestionIndex.NO_QUESTION] = "无安全提问";
safeQuestionText[safeQuestionIndex.MOTHER_NAME] = "母亲的名字";
safeQuestionText[safeQuestionIndex.GRANDFATHER_NAME] = "爷爷的名字";
safeQuestionText[safeQuestionIndex.FATHER_BIRTH_CITY] = "父亲出生的城市";
safeQuestionText[safeQuestionIndex.TEACHER_NAME] = "您其中一位老师的名字";
safeQuestionText[safeQuestionIndex.COMPUTER_MODEL] = "您个人计算机的型号";
safeQuestionText[safeQuestionIndex.FAVORITE_RESTAURANT] = "您最喜欢的餐馆名称";
safeQuestionText[safeQuestionIndex.DRIVING_LICENSE_LAST_FOUR] = "驾驶执照最后四位数字";

@CustomDialog
export struct LoginDialog {
  context = getContext(this) as common.UIAbilityContext
  controller: CustomDialogController
  @State username: string = ''
  @State password: string = ''
  @State waitingLoginResult: boolean = false
  @State invalidLoginMessage: string = ''
  @State safeQuestionSelected: number = -1
  @State safeQuestionAnswer: string = ''
  @State safeQuestionText: string = '安全提问(未设置请忽略)'
  lastTriedUsername: string = ''
  lastTriedPassword: string = ''

  readyToLogin() {
    return this.username.length > 0 && this.password.length > 0
      && (this.username != this.lastTriedUsername
      || this.password != this.lastTriedPassword)
      && (this.safeQuestionSelected <= 0 || this.safeQuestionSelected > 0 && this.safeQuestionAnswer.length > 0)
  }

  build() {
    Stack() {
      Column({ space: 16 }) {
        Row() {
          Text('登录')
            .fontSize(24)
        }.justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
        .padding({ left: 12, right: 12 })
        if (this.invalidLoginMessage.length > 0) {
          Text(this.invalidLoginMessage)
            .fontSize(16)
            .fontColor(Color.Red)
            .maxLines(2)
            .width('100%')
        }
        TextInput({
          placeholder: '用户名',
          text: $$this.username
        })
          .maxLength(50)
          .type(InputType.USER_NAME)
          .width('100%')
          .placeholderFont({ size: 16, weight: FontWeight.Regular })
          .defaultFocus(true)
          .tabIndex(0)
          .enterKeyType(EnterKeyType.Next)
        TextInput({
          placeholder: '密码',
          text: $$this.password
        })
          .maxLength(50)
          .type(InputType.Password)
          .width('100%')
          .placeholderFont({ size: 16, weight: FontWeight.Regular })
          .tabIndex(1)
        Select(safeQuestionText.map(text => ({ value: text } as SelectOption)))
          .value($$this.safeQuestionText)
          .selected($$this.safeQuestionSelected)
          .width('100%')
        if (this.safeQuestionSelected > 0) {
          TextInput({
            placeholder: '答案',
            text: $$this.safeQuestionAnswer
          }).maxLength(50)
            .type(InputType.Normal)
            .width('100%')
            .placeholderFont({ size: 16, weight: FontWeight.Regular })
        }
        Row() {
          Button('取消', { buttonStyle: ButtonStyleMode.TEXTUAL }).onClick(() => this.controller.close())
            .margin({ right: 10 })
            .layoutWeight(1)
          Button('登录', { buttonStyle: ButtonStyleMode.EMPHASIZED })
            .margin({ left: 10 })
            .layoutWeight(1)
            .opacity(this.readyToLogin() ? 1 : 0.4)
            .animation({ duration: AniSpeed.ms120 })
            .enabled(this.readyToLogin())
            .tabIndex(2)
            .onClick(e => {
              this.waitingLoginResult = true
              let questionId: number | undefined = undefined
              let answer: string | undefined = undefined
              if (this.safeQuestionSelected > 0) {
                questionId = this.safeQuestionSelected
                answer = this.safeQuestionAnswer
              }
              login(this.username, this.password, questionId, answer).then(v => {
                if (v == LoginResult.SUCCEED) {
                  this.controller.close()
                } else if (v == LoginResult.STRIKE) {
                  this.invalidLoginMessage = '错误登录次数过多，请15分钟后再试'
                } else {
                  this.invalidLoginMessage = '登录验证未通过'
                }
                this.lastTriedUsername = this.username
                this.lastTriedPassword = this.password
                this.username = this.lastTriedUsername // 触发readyToLogin的刷新
                this.waitingLoginResult = false
              })
            })
        }
      }.visibility(this.waitingLoginResult ? Visibility.Hidden : Visibility.Visible)

      if (this.waitingLoginResult) {
        LoadingProgress()
          .width(64)
          .height(64)
          .color($r('sys.color.ohos_id_color_emphasize'))
          .transition(AppearDisappearAni)
          .offset({ top: 30 })
      }
    }.padding(24)
    .alignContent(Alignment.Top)
  }
}