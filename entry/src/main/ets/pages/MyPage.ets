import { router, promptAction } from '@kit.ArkUI';

// 定义接口
interface SavedDevice {
  deviceId: string;
  deviceName: string;
}

@CustomDialog
struct DeviceManageDialog {
  controller: CustomDialogController;
  @StorageLink('HistoryDevices') historyDevices: SavedDevice[] = [];

  build() {
    Column() {
      Text("已配对设备管理")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 10 })

      List() {
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
  @StorageLink('HistoryDevices') historyDevices: SavedDevice[] = [];

  // 定义当前用户名，方便弹窗调用
  private userName: string = "管理员";

  dialogController: CustomDialogController = new CustomDialogController({
    builder: DeviceManageDialog(),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

  build() {
    Column() {
      // --- 1. 头部个人信息 ---
      Column() {
        Text('👤')
          .fontSize(40)
          .width(80)
          .height(80)
          .textAlign(TextAlign.Center)
          .backgroundColor('#E0E0E0')
          .borderRadius(40)
          .margin({ bottom: 10 })

        Text(this.userName)
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

      // --- 2. 功能菜单区 (占据中间剩余空间) ---
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
      }
      .width('100%')
      .layoutWeight(1) // 【关键】让菜单区撑开，把退出按钮挤到底部
      .padding(20)

      // --- 3. 底部退出按钮 ---
      Button("退出登录")
        .type(ButtonType.Capsule) // 圆角矩形
        .width('85%')
        .height(50)
        .backgroundColor('#FF5252') // 红色
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 40 }) // 底部留白，略微偏上
        .shadow({ radius: 10, color: '#4DFF5252', offsetY: 5 }) // 添加阴影增加层次感
        .onClick(() => {
          // 弹窗确认
          AlertDialog.show({
            title: '提示',
            message: `是否确认退出当前帐号“${this.userName}”？`,
            autoCancel: true,
            alignment: DialogAlignment.Center,
            primaryButton: {
              value: '取消',
              fontColor: '#666666',
              action: () => {
                // 取消操作，什么都不做
              }
            },
            secondaryButton: {
              value: '确认退出',
              fontColor: '#FF5252',
              action: () => {
                // 确认退出，跳转回登录页
                try {
                  router.replaceUrl({ url: 'pages/LoginPage' });
                } catch(e) {}
              }
            }
          });
        })

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