import { LogPage } from './LogPage';
import { IndexPage } from './Index'; // 导入 Index.ets 文件中的 IndexPage 结构体
import { MyPage } from './MyPage';

const THEME_COLOR = '#1976D2';

@Entry
@Component
export struct MainContainer {
  @State selectedIndex: number = 1;

  build() {
    Column() {
      Tabs({ index: this.selectedIndex }) {
        // 1. 左侧按钮：日志界面
        TabContent() {
          LogPage()
        }
        // 【关键修正】：使用显式 return 关键字 (解决 ERROR 2)
        .tabBar((): void => {
          return this.TabBuilder(0, '日志', $r('app.media.normal'), $r('app.media.active'));
        })

        // 2. 中间按钮：主界面 (Index)
        TabContent() {
          IndexPage()
        }
        // 【关键修正】：使用显式 return 关键字 (解决 ERROR 3)
        .tabBar((): void => {
          return this.TabBuilder(1, '主页', $r('app.media.normal'), $r('app.media.active'));
        })

        // 3. 右侧按钮：“我的”界面
        TabContent() {
          MyPage()
        }
        // 【关键修正】：使用显式 return 关键字 (解决 ERROR 4)
        .tabBar((): void => {
          return this.TabBuilder(2, '我的', $r('app.media.normal'), $r('app.media.active'));
        })

      }
      .vertical(false)
      .barPosition(BarPosition.End)
      .barHeight(76)
      .backgroundColor(Color.White)
      .onChange((index: number) => {
        this.selectedIndex = index;
      })

    }
    .margin({ top: 50, bottom:20 })
  }

  // 导航栏 Tab 样式构建器
  @Builder
  TabBuilder(index: number, name: string, normalIcon: Resource, activeIcon: Resource) {
    Column() {
      Image(this.selectedIndex === index ? activeIcon : normalIcon)
        .width(24)
        .height(24)
      Text(name)
        .fontColor(this.selectedIndex === index ? THEME_COLOR : Color.Gray)
        .fontSize(12)
    }
    .height(56)
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }
}