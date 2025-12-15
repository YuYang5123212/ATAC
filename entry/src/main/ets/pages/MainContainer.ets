import { LogPage } from './LogPage';
import { IndexPage } from './Index';
import { MyPage } from './MyPage';

@Entry
@Component
export struct MainContainer {
  @State realIndex: number = 1;
  @State visualIndex: number = 1;

  build() {
    Column() {
      Tabs({ index: this.realIndex, barPosition: BarPosition.End }) {

        TabContent() {
          LogPage()
        }
        .tabBar(this.TabBuilder(0, "运行日志", $r('app.media.log')))

        TabContent() {
          IndexPage()
        }
        .tabBar(this.TabBuilder(1, "门禁控制", $r('app.media.bt')))

        TabContent() {
          MyPage()
        }
        .tabBar(this.TabBuilder(2, "个人中心", $r('app.media.mypage')))

      }
      .vertical(false)
      .scrollable(true)
      .barHeight(100)
      .backgroundColor('#F2F3F5')
      .animationDuration(400)
      .onAnimationStart((index: number, targetIndex: number) => {
        this.visualIndex = targetIndex;
      })
      .onChange((index: number) => {
        this.realIndex = index;
        this.visualIndex = index;
      })
      .padding({ left: 10, right: 10 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5')
    // 【说明】因为开启了 setWindowLayoutFullScreen(true)
    // 这里的 padding 是必须的，为了防止内容被摄像头/时间遮挡
    // 但因为 Column 背景色覆盖了全屏，所以看起来是“沉浸式”的
    .padding({ top: 38, bottom: 12 })
  }

  @Builder
  TabBuilder(index: number, title: string, bgImage: Resource) {
    Stack({ alignContent: Alignment.TopStart }) {

      // 1. 底图
      Image(bgImage)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(16)

      // 2. 黑色遮罩 (控制明暗)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .borderRadius(16)
        .opacity(this.visualIndex === index ? 0.0 : 0.5)
        .animation({ duration: 200, curve: Curve.EaseOut })

      // 3. 界面名称文本 (移除阴影，增大字号)
      Text(title)
        .fontSize(14) // 【修改】增大字号
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: 12, left: 12 })
        // 【修改】选中完全不透明，未选中稍微透明一点
        .opacity(this.visualIndex === index ? 1.0 : 0.7)
        .animation({ duration: 200, curve: Curve.EaseOut })
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 5,
      right: 5,
      top: 6,
      bottom: 16
    })
  }
}