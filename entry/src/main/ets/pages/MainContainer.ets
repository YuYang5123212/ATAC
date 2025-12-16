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
      .backgroundColor('#111111') // 【修改】背景改为深黑
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
    .backgroundColor('#111111') // 【修改】背景改为深黑
    .padding({ top: 38, bottom: 12 })
  }

  @Builder
  TabBuilder(index: number, title: string, bgImage: Resource) {
    Stack({ alignContent: Alignment.TopStart }) {

      Image(bgImage)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(16)
        // 【修改】降低底图亮度，使其融合进黑暗背景
        .opacity(0.8)

      // 黑色遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000') // 纯黑遮罩
        .borderRadius(16)
        // 选中时稍微透一点亮(0.2)，未选中时较暗(0.7)
        .opacity(this.visualIndex === index ? 0.2 : 0.7)
        .animation({ duration: 200, curve: Curve.EaseOut })

      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White) // 白色文字
        .margin({ top: 12, left: 12 })
        .opacity(this.visualIndex === index ? 1.0 : 0.6)
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