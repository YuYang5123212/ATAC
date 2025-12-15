import { LogPage } from './LogPage';
import { IndexPage } from './Index';
import { MyPage } from './MyPage';

@Entry
@Component
export struct MainContainer {
  // 【核心修改】分离两个状态
  // realIndex: 只有页面完全切换过去后才更新，保证 Tabs 内部动画不被打断
  @State realIndex: number = 1;
  // visualIndex: 动画一开始就更新，保证按钮立刻变亮
  @State visualIndex: number = 1;

  build() {
    Column() {
      // 绑定的是 realIndex，确保滑动过程由系统物理引擎接管，不被代码强制干扰
      Tabs({ index: this.realIndex, barPosition: BarPosition.End }) {

        // 1. 左侧：日志
        TabContent() {
          LogPage()
        }
        .tabBar(this.TabBuilder(0, $r('app.media.log')))

        // 2. 中间：门禁
        TabContent() {
          IndexPage()
        }
        .tabBar(this.TabBuilder(1, $r('app.media.bt')))

        // 3. 右侧：我的
        TabContent() {
          MyPage()
        }
        .tabBar(this.TabBuilder(2, $r('app.media.mypage')))

      }
      .vertical(false)
      .scrollable(true)
      .barHeight(100)
      .backgroundColor('#F2F3F5')
      // 设置一个流畅的动画曲线和时长
      .animationDuration(400)

      // 【关键逻辑 A】动画开始时，只更新按钮样式 (visualIndex)
      // 绝对不要在这里更新 realIndex，否则会打断滑动惯性！
      .onAnimationStart((index: number, targetIndex: number) => {
        this.visualIndex = targetIndex;
      })

      // 【关键逻辑 B】动画真正结束时，同步逻辑索引 (realIndex)
      .onChange((index: number) => {
        this.realIndex = index;
        // 双重保险：防止动画意外中断导致视觉索引不对齐
        this.visualIndex = index;
      })

      .padding({ left: 10, right: 10 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5')
    .padding({ top: 38 })
  }

  @Builder
  TabBuilder(index: number, bgImage: Resource) {
    Stack({ alignContent: Alignment.Top }) {

      // 底图
      Image(bgImage)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(16)

      // 黑色遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .borderRadius(16)
        // 【关键】这里绑定的是 visualIndex，保证极速响应
        .opacity(this.visualIndex === index ? 0.0 : 0.5)
        // 按钮自身的明暗渐变动画
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