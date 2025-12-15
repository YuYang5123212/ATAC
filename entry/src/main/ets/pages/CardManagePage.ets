import { router } from '@kit.ArkUI';

interface AccessCard {
  cardId: string;
  owner: string;
}

interface SavedDevice {
  deviceId: string;
  deviceName: string;
}

@Entry
@Component
struct CardManagePage {
  @StorageLink('HistoryDevices') historyDevices: SavedDevice[] = [];

  build() {
    Column() {
      // 1. 标题栏
      Row() {
        Button("< 返回")
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor('#333333')
          .onClick(() => {
            try { router.back(); } catch(e) {}
          })

        Text("门禁卡管理")
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 40 })
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
      .backgroundColor(Color.White)

      // 2. 设备卡片列表
      List() {
        ForEach(this.historyDevices, (device: SavedDevice) => {
          ListItem() {
            Column() {
              // 设备头
              Row() {
                Text(device.deviceName || "未知设备")
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                Blank()
                Text(device.deviceId)
                  .fontSize(12)
                  .fontColor('#999999')
              }
              .width('100%')
              .padding({ bottom: 10 })
              .border({ width: { bottom: 1 }, color: '#F0F0F0' })

              // 卡片列表 (模拟数据)
              Column() {
                this.CardRow("UID: 93 4F 22 F8", "管理员")
                this.CardRow("UID: XX XX XX XX", "预留卡位")
              }
              .width('100%')
              .padding({ top: 10 })
            }
            .width('100%')
            .backgroundColor(Color.White)
            .borderRadius(12)
            .padding(15)
            .margin({ bottom: 15 })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding(15)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5')
    .padding({ top: 36 }) // 【核心修复】增加顶部避让距离
  }

  @Builder
  CardRow(cardId: string, remark: string) {
    Row() {
      Text('💳')
        .fontSize(20)
        .margin({ right: 10 })

      Column() {
        Text(cardId).fontSize(14)
        Text(remark).fontSize(12).fontColor('#999999')
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text("默认")
        .fontSize(12)
        .fontColor('#4CAF50')
        .backgroundColor('#E8F5E9')
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(4)
    }
    .width('100%')
    .margin({ bottom: 10 })
  }
}