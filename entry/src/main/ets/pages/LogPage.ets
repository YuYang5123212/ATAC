import { promptAction } from '@kit.ArkUI';

// 1. 初始化日志存储 (保留最近的日志)
PersistentStorage.persistProp('AppLogs', []);

// 日志数据结构
export interface LogItem {
  timestamp: string;  // 时间 (HH:mm:ss)
  deviceName: string; // 设备名
  content: string;    // 内容
  type: 'SEND' | 'RECV'; // 类型：发送还是接收
}

@Component
export struct LogPage {
  // 双向绑定存储
  @StorageLink('AppLogs') appLogs: LogItem[] = [];

  build() {
    Column() {
      // 标题栏
      Row() {
        Text("运行日志")
          .fontSize(24)
          .fontWeight(FontWeight.Bold)

        Blank()

        // 清空按钮
        Button("清空")
          .height(30)
          .fontSize(12)
          .backgroundColor('#FF5252')
          .onClick(() => {
            this.appLogs = [];
            try { promptAction.showToast({ message: '日志已清空' }); } catch(e) {}
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 10 })

      // 日志列表
      List() {
        if (this.appLogs.length === 0) {
          ListItem() {
            Text("暂无日志记录")
              .width('100%')
              .textAlign(TextAlign.Center)
              .fontColor('#999999')
              .margin({ top: 50 })
          }
        }

        ForEach(this.appLogs, (item: LogItem) => {
          ListItem() {
            Column() {
              Row() {
                // 时间
                Text(item.timestamp)
                  .fontSize(12)
                  .fontColor('#999999')

                Blank()

                // 设备名
                Text(item.deviceName)
                  .fontSize(12)
                  .fontColor('#666666')
              }
              .width('100%')
              .margin({ bottom: 4 })

              // 内容区域
              Row() {
                // 标签 (发送/接收)
                Text(item.type === 'SEND' ? "发送" : "收到")
                  .fontSize(10)
                  .fontColor(Color.White)
                  .backgroundColor(item.type === 'SEND' ? '#007DFF' : '#4CAF50')
                  .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                  .borderRadius(4)
                  .margin({ right: 8 })

                // 具体文本
                Text(item.content)
                  .fontSize(14)
                  .fontColor('#333333')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .width('100%')
            .padding(12)
            .backgroundColor(Color.White)
            .borderRadius(8)
            .margin({ bottom: 8 })
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 15, right: 15 })
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5')
  }
}