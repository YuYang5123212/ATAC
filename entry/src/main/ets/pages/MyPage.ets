import { router, promptAction } from '@kit.ArkUI';
// 1. 记得引入工具类 (注意路径是否正确，根据你 utils 文件夹的位置)
import { PreferencesUtil } from '../utils/PreferencesUtil';

interface SavedDevice {
  deviceId: string;
  deviceName: string;
}

// --- 退出登录弹窗 ---
@CustomDialog
struct LogoutDialog {
  controller: CustomDialogController;
  confirmAction: () => void = () => {};
  userName: string = "";

  build() {
    Column() {
      Text("提示").fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ top: 20, bottom: 10 })
      Text(`是否确认退出当前帐号“${this.userName}”？`).fontSize(14).fontColor('#AAAAAA').margin({ bottom: 20 }).padding({ left: 20, right: 20 }).textAlign(TextAlign.Center)

      Row() {
        Button("取消").onClick(() => this.controller.close()).backgroundColor(Color.Transparent).fontColor('#AAAAAA').layoutWeight(1)

        Button("确认退出")
          .onClick(async () => { // 注意这里加了 async
            // 执行传入的确认逻辑
            this.confirmAction();
            this.controller.close();
          })
          .backgroundColor(Color.Transparent).fontColor('#FF5252').layoutWeight(1)
      }
      .margin({ top: 10, bottom: 10 }).width('100%')
    }
    .width('80%').backgroundColor('#1E1E1E').borderRadius(16)
  }
}

// --- 设备管理弹窗 ---
@CustomDialog
struct DeviceManageDialog {
  controller: CustomDialogController;
  @StorageLink('HistoryDevices_JSON') historyJson: string = '[]';
  @State historyDevices: SavedDevice[] = [];

  aboutToAppear() {
    try { this.historyDevices = JSON.parse(this.historyJson); } catch(e) {}
  }

  build() {
    Column() {
      Text("已配对设备管理").fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ top: 20, bottom: 10 })

      List() {
        ForEach(this.historyDevices, (item: SavedDevice, index: number) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.deviceName || "未知设备").fontSize(16).fontColor(Color.White)
                Text(item.deviceId).fontSize(12).fontColor('#AAAAAA')
              }.alignItems(HorizontalAlign.Start)
              Blank()

              // 删除按钮
              Button("删除").height(28).fontSize(12).backgroundColor('#C62828')
                .onClick(async () => { // 注意 async
                  // 1. 改内存数组
                  this.historyDevices.splice(index, 1);

                  // 2. 转成字符串
                  const newJson = JSON.stringify(this.historyDevices);

                  // 3. 更新 AppStorage (UI会自动刷新)
                  this.historyJson = newJson;

                  // 4. 【核心持久化】强制写入磁盘
                  await PreferencesUtil.put('HistoryDevices_JSON', newJson);

                  try { promptAction.showToast({ message: '已取消配对' }); } catch(e) {}
                  if (this.historyDevices.length === 0) this.controller.close();
                })
            }
            .width('100%').padding({ left: 15, right: 15, top: 10, bottom: 10 }).border({ width: { bottom: 1 }, color: '#333333' })
          }
        })
      }
      .width('100%').height(this.historyDevices.length > 5 ? 300 : 'auto').constraintSize({ minHeight: 100 })

      Button("关 闭").width('90%').margin({ top: 10, bottom: 20 }).backgroundColor('#333333').fontColor(Color.White)
        .onClick(() => { this.controller.close(); })
    }
    .backgroundColor('#1E1E1E').borderRadius(16).width('90%')
  }
}

// --- 主页面 ---
@Component
export struct MyPage {
  @StorageLink('HistoryDevices_JSON') historyJson: string = '[]';
  private userName: string = "管理员";

  dialogController: CustomDialogController = new CustomDialogController({
    builder: DeviceManageDialog(),
    autoCancel: true, alignment: DialogAlignment.Center, customStyle: true
  });

  logoutController: CustomDialogController = new CustomDialogController({
    builder: LogoutDialog({
      userName: this.userName,
      confirmAction: async () => {
        // 1. 清除内存状态
        AppStorage.setOrCreate('LoginTimestamp', 0);

        // 2. 【核心持久化】清除磁盘记录
        await PreferencesUtil.put('LoginTimestamp', 0);

        try { router.replaceUrl({ url: 'pages/LoginPage' }); } catch(e) {}
      }
    }),
    autoCancel: true, alignment: DialogAlignment.Center, customStyle: true
  });

  build() {
    Column() {
      // 头部
      Column() {
        Text('👤').fontSize(40).width(80).height(80).textAlign(TextAlign.Center).backgroundColor('#333333').borderRadius(40).margin({ bottom: 10 })
        Text(this.userName).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
        Text("ID: 88888888").fontSize(14).fontColor('#AAAAAA').margin({ top: 5 })
      }.width('100%').padding({ top: 50, bottom: 30 }).backgroundColor('#1E1E1E')

      // 菜单
      Column({ space: 15 }) {
        this.MenuButton("管理已配对设备", "查看或移除已连接过的蓝牙锁", '#448AFF', () => {
          let list: SavedDevice[] = [];
          try { list = JSON.parse(this.historyJson); } catch(e) {}
          if (list.length === 0) { try { promptAction.showToast({ message: '暂无配对设备' }); } catch(e) {} }
          else { this.dialogController.open(); }
        })
        this.MenuButton("门禁卡设置", "查看各设备的授权卡片信息", '#EF6C00', () => {
          try { router.pushUrl({ url: 'pages/CardManagePage' }); } catch (err) {}
        })
      }.width('100%').layoutWeight(1).padding(20)

      // 底部退出
      Button("退出登录").type(ButtonType.Capsule).width('85%').height(50).backgroundColor('#C62828').fontSize(18).fontWeight(FontWeight.Medium).margin({ bottom: 40 })
        .shadow({ radius: 10, color: '#4D000000', offsetY: 5 })
        .onClick(() => {
          this.logoutController.open();
        })
    }.width('100%').height('100%').backgroundColor('#111111')
  }

  @Builder
  MenuButton(title: string, subtitle: string, color: string, onClick: () => void) {
    Button() {
      Row() {
        Column().width(4).height(40).backgroundColor(color).borderRadius(2).margin({ right: 15 })
        Column() {
          Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
          Text(subtitle).fontSize(12).fontColor('#888888').margin({ top: 4 })
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Text(">").fontSize(16).fontColor('#666666')
      }.width('100%').padding(15)
    }.type(ButtonType.Normal).backgroundColor('#1E1E1E').borderRadius(12).onClick(onClick).shadow({ radius: 4, color: '#000000', offsetY: 2 })
  }
}