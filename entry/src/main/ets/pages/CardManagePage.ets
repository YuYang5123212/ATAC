import { router } from '@kit.ArkUI';

interface SavedDevice {
  deviceId: string;
  deviceName: string;
}

@Entry
@Component
struct CardManagePage {
  @StorageLink('HistoryDevices_JSON') historyJson: string = '[]';
  @State historyDevices: SavedDevice[] = [];

  aboutToAppear() { try { this.historyDevices = JSON.parse(this.historyJson); } catch(e) {} }

  build() {
    Column() {
      // 标题栏
      Row() {
        Button("< 返回")
          .type(ButtonType.Normal).backgroundColor(Color.Transparent).fontColor('#FFFFFF')
          .onClick(() => { try { router.back(); } catch(e) {} })

        Text("门禁卡管理").fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center).margin({ right: 40 })
      }
      .width('100%').padding({ top: 10, bottom: 10 }).backgroundColor('#1E1E1E')

      List() {
        ForEach(this.historyDevices, (device: SavedDevice) => {
          ListItem() {
            Column() {
              Row() {
                Text(device.deviceName || "未知设备").fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
                Blank()
                Text(device.deviceId).fontSize(12).fontColor('#AAAAAA')
              }
              .width('100%').padding({ bottom: 10 }).border({ width: { bottom: 1 }, color: '#333333' })

              Column() {
                this.CardRow("UID: 93 4F 22 F8", "管理员")
                this.CardRow("UID: XX XX XX XX", "预留卡位")
              }.width('100%').padding({ top: 10 })
            }
            .width('100%').backgroundColor('#1E1E1E').borderRadius(12).padding(15).margin({ bottom: 15 })
          }
        })
      }
      .width('100%').layoutWeight(1).padding(15)
    }
    .width('100%').height('100%')
    .backgroundColor('#111111') // 【暗色】
    .padding({ top: 36 })
  }

  @Builder
  CardRow(cardId: string, remark: string) {
    Row() {
      Text('💳').fontSize(20).margin({ right: 10 })
      Column() {
        Text(cardId).fontSize(14).fontColor(Color.White)
        Text(remark).fontSize(12).fontColor('#888888')
      }.alignItems(HorizontalAlign.Start)
      Blank()
      Text("默认").fontSize(12).fontColor('#69F0AE').backgroundColor('#1B5E20')
        .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(4)
    }
    .width('100%').margin({ bottom: 10 })
  }
}