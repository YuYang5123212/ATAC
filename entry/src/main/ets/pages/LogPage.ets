import { promptAction } from '@kit.ArkUI';

interface LogItem {
  timestamp: string;
  deviceName: string;
  content: string;
  type: 'SEND' | 'RECV';
}

@Component
export struct LogPage {
  // 【核心修复】添加 @Watch，监听字符串变化
  @StorageLink('AppLogs_JSON') @Watch('updateLogs') logsJson: string = '[]';
  @State appLogs: LogItem[] = [];

  // 初始化时解析
  aboutToAppear() {
    this.updateLogs();
  }

  // 当 logsJson 变化时自动调用
  updateLogs() {
    try {
      this.appLogs = JSON.parse(this.logsJson);
    } catch(e) {
      this.appLogs = [];
    }
  }

  build() {
    Column() {
      Row() {
        Text("运行日志")
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White)
        Blank()
        Button("清空").height(30).fontSize(12).backgroundColor('#C62828')
          .onClick(() => {
            this.appLogs = [];
            this.logsJson = '[]';
            try { promptAction.showToast({ message: '日志已清空' }); } catch(e) {}
          })
      }
      .width('100%').padding({ left: 20, right: 20, top: 20, bottom: 10 })

      List() {
        if (this.appLogs.length === 0) {
          ListItem() { Text("暂无日志记录").width('100%').textAlign(TextAlign.Center).fontColor('#666666').margin({ top: 50 }) }
        }

        ForEach(this.appLogs, (item: LogItem) => {
          ListItem() {
            Column() {
              Row() {
                Text(item.timestamp).fontSize(12).fontColor('#888888')
                Blank()
                Text(item.deviceName).fontSize(12).fontColor('#AAAAAA')
              }.width('100%').margin({ bottom: 4 })

              Row() {
                Text(item.type === 'SEND' ? "发送" : "收到")
                  .fontSize(10).fontColor(Color.White)
                  .backgroundColor(item.type === 'SEND' ? '#1565C0' : '#2E7D32')
                  .padding({ left: 4, right: 4, top: 2, bottom: 2 }).borderRadius(4).margin({ right: 8 })
                Text(item.content).fontSize(14).fontColor('#DDDDDD')
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .width('100%').padding(12)
            .backgroundColor('#1E1E1E')
            .borderRadius(8).margin({ bottom: 8 })
          }
        })
      }
      .layoutWeight(1).width('100%').padding({ left: 15, right: 15 }).edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%').backgroundColor('#111111')
  }
}