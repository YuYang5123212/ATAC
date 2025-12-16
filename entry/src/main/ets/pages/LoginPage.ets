import { router, promptAction } from '@kit.ArkUI';
import { PreferencesUtil } from '../utils/PreferencesUtil'; // 【新增】引入工具类

// 【自定义主题色】
const THEME_COLOR = '#1976D2';
const ERROR_COLOR = '#FF3B30';

const DEFAULT_ACCOUNT = "QiTongWei";
const DEFAULT_PASSWORD = "GaoXiaoQin";

@Entry
@Component
struct LoginPage {
  // 状态变量
  @State username: string = '';
  @State password: string = '';
  // 用于控制输入框的错误边框和提示文本
  @State usernameError: boolean = false;
  @State passwordError: boolean = false;
  @State errorMessage: string = '';

  // 登录逻辑
  async login() { // 【修改】增加 async 关键字
    this.usernameError = false;
    this.passwordError = false;
    this.errorMessage = '';

    // 清理首尾空格
    let cleanUsername = this.username.trim();
    let cleanPassword = this.password.trim();

    // 核心登录逻辑
    if (cleanUsername === DEFAULT_ACCOUNT && cleanPassword === DEFAULT_PASSWORD) {
      // --- 成功路径 ---
      try {
        promptAction.showToast({ message: '登录成功，正在跳转...', duration: 1000 });

        // 【核心新增】保存登录状态到磁盘
        const now = new Date().getTime();
        // 1. 更新内存
        AppStorage.setOrCreate('LoginTimestamp', now);
        // 2. 写入首选项 (持久化)
        await PreferencesUtil.put('LoginTimestamp', now);

        // 跳转
        router.replaceUrl({ url: 'pages/MainContainer' });
      } catch (err) {
        promptAction.showToast({ message: `跳转失败: ${JSON.stringify(err)}` });
      }

    } else {
      // --- 失败路径 ---
      this.errorMessage = '账号或密码错误。';
      if (cleanUsername !== DEFAULT_ACCOUNT) {
        this.usernameError = true;
      }
      if (cleanPassword !== DEFAULT_PASSWORD) {
        this.passwordError = true;
      }
      promptAction.showToast({ message: this.errorMessage, duration: 2000 });
    }
  }

  build() {
    Stack() { // 使用层叠布局容器
      // 1. 背景图层（最底层）
      Image($r('app.media.background'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 2. 内容层（叠加在背景之上）
      Column() {
        Scroll() {
          Column({ space: 0 }) {

            // --- 应用图标 ---
            Image($r('app.media.app_icon'))
              .width(144)
              .height(144)
              .borderRadius(20)
              .margin({ top: 50, bottom: 5 })

            // --- 标题 ---
            Stack() {
              // 描边层（通过阴影模拟）
              Text('AT门禁')
                .fontSize(35)
                .fontWeight(FontWeight.Bolder)
                .fontColor(Color.White)
                .margin({ top: 5, bottom: 42 })

              Text('AT门禁')
                .fontSize(32)
                .fontWeight(FontWeight.Bolder)
                .fontColor(Color.Black)
                .margin({ top: 5, bottom: 40 })
            }

            // --- 账号输入框 ---
            Column({ space: 5 }) {
              TextInput({ placeholder: '账号提示: 祁同伟', text: this.username })
                .type(InputType.Normal)
                .placeholderColor(Color.Gray)
                .height(48)
                .borderRadius(8)
                .padding({ left: 15, right: 15 })
                .backgroundColor(0xF0F0F0)
                .border({
                  width: this.usernameError ? 1 : 0,
                  color: this.usernameError ? ERROR_COLOR : Color.Transparent,
                  radius: 8
                })
                .onChange((value) => {
                  this.username = value;
                  this.usernameError = false;
                })

              if (this.usernameError) {
                Text('账号错误')
                  .fontSize(12)
                  .fontColor(ERROR_COLOR)
                  .width('100%')
                  .textAlign(TextAlign.Start)
                  .margin({ left: 5 })
              }
            }
            .width('80%')
            .margin({ bottom: 20 })

            // --- 密码输入框 ---
            Column({ space: 5 }) {
              TextInput({ placeholder: '密码提示: 高小琴', text: this.password })
                .type(InputType.Password)
                .placeholderColor(Color.Gray)
                .height(48)
                .borderRadius(8)
                .padding({ left: 15, right: 15 })
                .backgroundColor(0xF0F0F0)
                .border({
                  width: this.passwordError ? 1 : 0,
                  color: this.passwordError ? ERROR_COLOR : Color.Transparent,
                  radius: 8
                })
                .onChange((value) => {
                  this.password = value;
                  this.passwordError = false;
                })

              if (this.passwordError) {
                Text('密码错误')
                  .fontSize(12)
                  .fontColor(ERROR_COLOR)
                  .width('100%')
                  .textAlign(TextAlign.Start)
                  .margin({ left: 5 })
              }
            }
            .width('80%')
            .margin({ bottom: 20 })

            // --- 辅助选项 ---
            Row() {
              Text('立即上岸')
                .fontColor(Color.Gray)
                .fontSize(14)
                .onClick(() => {
                  promptAction.showToast({ message: '暂未开放' });
                })

              Blank()

              Text('忘记初心？')
                .fontColor(Color.Gray)
                .fontSize(14)
                .onClick(() => {
                  promptAction.showToast({ message: '暂未开放' });
                })
            }
            .width('80%')

            // --- 页脚名言 ---
            Text('哪怕锁舌只是一根棉签，我也要胜天半子。\n\t--祁厅长')
              .fontSize(18)
              .fontColor(Color.Gray)
              .textAlign(TextAlign.Center)
              .margin({ top: 100 })

            Blank().height(50)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')

        // --- 底部按钮区 ---
        Button('登 录')
          .width('80%')
          .height(50)
          .backgroundColor(THEME_COLOR)
          .borderRadius(8)
          .margin({ bottom: 20 })
          .onClick(() => {
            this.login();
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height('100%')
  }
}