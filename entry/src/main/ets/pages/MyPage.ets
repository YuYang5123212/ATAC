// F:/Harmony/ArduinoandHarmony/entry/src/main/ets/pages/MyPage.ets
import router from '@ohos.router';
import { Button } from '@kit.ArkUI';

@Entry
@Preview
@Component
export struct MyPage {
  build() {
    Column() {
      Text('个人中心/管理界面')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 50, bottom: 20 })
      Column() {
        Row() {
          Text('管理蓝牙设备')
            .fontSize(18)
            .padding(10)
        }
        .width('100%')
        .height(60)
        .backgroundColor(Color.White)

        Row() {
          Text('门禁卡设置')
            .fontSize(18)
            .padding(10)
        }
        .width('100%')
        .height(60)
        .backgroundColor(Color.White)

        // ... 其他管理选项

      }
      .width('90%')
      .backgroundColor(Color.White)
      .borderRadius(12)

      // 【请求 4】退出登录按钮
      Button('退出登录')
        .width('80%')
        .height(48)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .backgroundColor('#F44336') // 使用红色作为警示色
        .borderRadius(8)
        .margin({ top: 50 })
        .onClick(() => {
          // 使用 replaceUrl 确保返回后无法通过返回键回到主界面
          router.replaceUrl({ url: 'pages/LoginPage' });
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}