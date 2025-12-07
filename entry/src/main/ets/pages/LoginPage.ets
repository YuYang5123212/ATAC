import router from '@ohos.router';
// 确保导入了所需的布局和类型
import { promptAction, window } from '@kit.ArkUI';

// 【自定义主题色】假设您的图标主色调为深蓝色
const THEME_COLOR = '#1976D2';
const ERROR_COLOR = '#FF3B30'; // 红色用于错误提示

const DEFAULT_ACCOUNT = "QiTongWei";
const DEFAULT_PASSWORD = "GaoXiaoQin";

@Entry
@Component
struct LoginPage {

  // 状态变量
  @State username: string = '';
  @State password: string = '';
  // 【新增状态】用于控制输入框的错误边框和提示文本
  @State usernameError: boolean = false;
  @State passwordError: boolean = false;
  @State errorMessage: string = '';

  // 登录逻辑
  login() {
    this.usernameError = false;
    this.passwordError = false;
    this.errorMessage = '';

    // 【核心修复 1：清理首尾空格】确保比较准确
    let cleanUsername = this.username.trim();
    let cleanPassword = this.password.trim();

    // 2. 核心登录逻辑
    if (cleanUsername === DEFAULT_ACCOUNT && cleanPassword === DEFAULT_PASSWORD) {
      // 成功路径
      promptAction.showToast({ message: '登录成功，正在跳转...', duration: 1000 });

      try {
        router.replace({ url: 'pages/MainContainer' });
      } catch (err) {
        promptAction.showToast({ message: `跳转失败: ${err.message}` });
      }


    } else {
      // 失败路径 (显示错误提示)
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
        .position({ x: 0, y: 0 }) // 强制从屏幕顶部开始布局
        //.opacity(0.75) // 设置透明度
        .objectFit(ImageFit.Cover)

      // 2. 内容层（叠加在背景之上）
      Column() {
        Scroll() {
          Column({ space: 0 }) {

            // --- 1. 应用图标 ---
            Image($r('app.media.app_icon'))
              .width(144)
              .height(144)
              .borderRadius(20)
              .margin({ top: 50, bottom: 5 })

            // 添加标题
            Stack(){
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
                .margin({ top: 5, bottom: 40 }) // 添加下边距，与输入框分离
            }

            // --- 账号输入框及其错误提示 ---
            Column({ space: 5 }) {
              TextInput({ placeholder: '账号提示: 祁同伟', text: this.username })
                .type(InputType.Normal)
                .placeholderColor(Color.Gray)
                .height(48)
                .borderRadius(8)
                .padding({ left: 15, right: 15 })
                .backgroundColor(0xF0F0F0)
                // 【请求 2 边框实现】根据状态变红
                .border({
                  width: this.usernameError ? 1 : 0,
                  color: this.usernameError ? ERROR_COLOR : Color.Transparent,
                  radius: 8
                })
                .onChange((value) => {
                  this.username = value;
                  this.usernameError = false; // 用户输入时清除错误
                })

              // 【请求 2 错误信息】
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
            .margin({ bottom: 20 }) // 确保账号框和密码框始终间隔 20vp

            // --- 密码输入框及其错误提示 ---
            Column({ space: 5 }) {
              TextInput({ placeholder: '密码提示: 高小琴', text: this.password })
                .type(InputType.Password)
                .placeholderColor(Color.Gray)
                .height(48)
                .borderRadius(8)
                .padding({ left: 15, right: 15 })
                .backgroundColor(0xF0F0F0)
                // 【请求 2 边框实现】根据状态变红
                .border({
                  width: this.passwordError ? 1 : 0,
                  color: this.passwordError ? ERROR_COLOR : Color.Transparent,
                  radius: 8
                })
                .onChange((value) => {
                  this.password = value;
                  this.passwordError = false; // 用户输入时清除错误
                })

              // 【请求 2 错误信息】
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
            .margin({ bottom: 20 }) // 确保密码框和辅助选项之间有间距


            // --- 辅助选项 (立即注册 / 忘记密码) ---
            Row() {
              Text('立即上岸')  //立即注册
                .fontColor(Color.Gray)
                .fontSize(14)
                .onClick(() => {
                  promptAction.showToast({ message: '暂未开放' });
                })

              Blank()

              Text('忘记初心？') //忘记密码？
                .fontColor(Color.Gray)
                .fontSize(14)
                .onClick(() => {
                  promptAction.showToast({ message: '暂未开放' });
                })
            }
            .width('80%')
            .margin({ top: 0, bottom: 0 })

            // --- 祁厅长名言 (页脚) ---
            Text('哪怕锁舌只是一根棉签，我也要胜天半子。\n\t--祁厅长')
              .fontSize(18)
              .fontColor(Color.Gray)
              .textAlign(TextAlign.Center)
              .margin({ top: 100 })


            Blank()
              .height(50)

          }
          .width('100%')
          .padding(0)
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1) // 赋予 Scroll 组件最大的权重，占据除底部按钮外的所有空间
        .width('100%')

        // 2. 底部按钮区：独立于 Scroll 组件
        // --- 登录按钮 ---
        Button('登 录')
          .width('80%')
          .height(50)
          .backgroundColor(THEME_COLOR)
          .borderRadius(8)
          .margin({ bottom: 20 }) // 底部留出间距
          // 【核心修复】将点击事件放在 Column 外部，确保它不会被 Scroll 拦截
          .onClick(() => {
            this.login();
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween) // 关键布局属性
      //.justifyContent(FlexAlign.Center)
      //.alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}