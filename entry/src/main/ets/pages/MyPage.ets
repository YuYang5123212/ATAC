import { router, promptAction } from '@kit.ArkUI';

// 【关键修复】定义接口
interface SavedDevice {
  deviceId: string;
  deviceName: string;
}

@CustomDialog
struct DeviceManageDialog {
  controller: CustomDialogController;
  // 【关键修复】使用接口类型
  @StorageLink('HistoryDevices') historyDevices: SavedDevice[] = [];

  build() {
    Column() {
      Text("已配对设备管理")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 10 })

      List() {
        // 【关键修复】ForEach 类型声明
        ForEach(this.historyDevices, (item: SavedDevice, index: number) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.deviceName || "未知设备")
                  .fontSize(16)
                  .fontColor('#333333')
                Text(item.deviceId)
                  .fontSize(12)
                  .fontColor('#999999')
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Button("删除")
                .height(28)
                .fontSize(12)
                .backgroundColor('#FF5252')
                .onClick(() => {
                  this.historyDevices.splice(index, 1);
                  try { promptAction.showToast({ message: '已取消配对' }); } catch(e) {}

                  if (this.historyDevices.length === 0) {
                    this.controller.close();
                  }
                })
            }
            .width('100%')
            .padding({ left: 15, right: 15, top: 10, bottom: 10 })
            .border({ width: { bottom: 1 }, color: '#F5F5F5' })
          }
        })
      }
      .width('100%')
      .height(this.historyDevices.length > 5 ? 300 : 'auto')
      .constraintSize({ minHeight: 100 })

      Button("关 闭")
        .width('90%')
        .margin({ top: 10, bottom: 20 })
        .backgroundColor('#F2F3F5')
        .fontColor('#666666')
        .onClick(() => {
          this.controller.close();
        })
    }
    .backgroundColor(Color.White)
    .borderRadius(16)
    .width('90%')
  }
}

@Component
export struct MyPage {
  // 【关键修复】使用接口类型
  @StorageLink('HistoryDevices') historyDevices: SavedDevice[] = [];

  dialogController: CustomDialogController = new CustomDialogController({
    builder: DeviceManageDialog(),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

  build() {
    Column() {
      // --- 头部 ---
      Column() {
        // 头像占位
        Text('👤')
          .fontSize(40)
          .width(80)
          .height(80)
          .textAlign(TextAlign.Center)
          .backgroundColor('#E0E0E0')
          .borderRadius(40)
          .margin({ bottom: 10 })

        Text("管理员")
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Text("ID: 88888888")
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 5 })
      }
      .width('100%')
      .padding({ top: 50, bottom: 30 })
      .backgroundColor(Color.White)

      // --- 菜单 ---
      Column({ space: 15 }) {

        this.MenuButton(
          "管理已配对设备",
          "查看或移除已连接过的蓝牙锁",
          '#007DFF',
          () => {
            if (this.historyDevices.length === 0) {
              try { promptAction.showToast({ message: '暂无配对设备' }); } catch(e) {}
            } else {
              this.dialogController.open();
            }
          }
        )

        this.MenuButton(
          "门禁卡设置",
          "查看各设备的授权卡片信息",
          '#FF9800',
          () => {
            try {
              router.pushUrl({ url: 'pages/CardManagePage' });
            } catch (err) {
              console.error(`跳转失败: ${JSON.stringify(err)}`);
            }
          }
        )

        this.MenuButton(
          "退出登录",
          "返回登录页面",
          '#FF5252',
          () => {
            try { router.replaceUrl({ url: 'pages/LoginPage' }); } catch(e) {}
          }
        )

      }
      .width('100%')
      .layoutWeight(1)
      .padding(20)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5')
  }

  @Builder
  MenuButton(title: string, subtitle: string, color: string, onClick: () => void) {
    Button() {
      Row() {
        Column()
          .width(4)
          .height(40)
          .backgroundColor(color)
          .borderRadius(2)
          .margin({ right: 15 })

        Column() {
          Text(title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
          Text(subtitle)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(">")
          .fontSize(16)
          .fontColor('#CCCCCC')
      }
      .width('100%')
      .padding(15)
    }
    .type(ButtonType.Normal)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .onClick(onClick)
    .shadow({ radius: 4, color: '#0D000000', offsetY: 2 })
  }
}