import { BluetoothManager, ScannedDevice } from '../utils/BluetoothManager';
import { PermissionManager } from '../utils/PermissionManager';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

@Component
export struct IndexPage {
  @State connectionStatus: string = "未连接";
  @State scannedDevices: Array<ScannedDevice> = [];

  // 【重要】这是你在蓝牙调试器里看到的真实地址！
  private targetMac: string = "74:0B:AE:27:43:EC";

  private btManager = new BluetoothManager();
  private context = getContext(this) as common.UIAbilityContext;

  build() {
    Column() {
      Text("智能门禁控制")
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 10 })

      Text(`状态: ${this.connectionStatus}`)
        .fontSize(16)
        .fontColor(this.connectionStatus.includes("已连接") ? Color.Green : Color.Gray)
        .margin({ bottom: 20 })

      // --- 新增：霸道总裁式直连按钮 ---
      Button(`直连第八组 (${this.targetMac})`)
        .width('90%')
        .height(60)
        .backgroundColor('#E91E63') // 醒目的颜色
        .margin({ bottom: 20 })
        .onClick(async () => {
          // 1. 还是要先申请权限
          let granted = await PermissionManager.requestBluetoothPermission(this.context);
          if (!granted) return;

          // 2. 停止可能存在的扫描
          this.btManager.stopScan();

          // 3. 直接发起连接
          this.connectionStatus = `正在直连 ${this.targetMac}...`;
          let isSuccess = await this.btManager.connect(this.targetMac);

          if (isSuccess) {
            this.connectionStatus = "已连接 (直连模式)";
          } else {
            this.connectionStatus = "直连失败 (请检查设备电量或重启设备)";
          }
        })

      // 下面保留扫描功能作为备用
      Button("扫描设备 (备用)")
        .width('80%')
        .backgroundColor(Color.Gray)
        .onClick(async () => {
          let granted = await PermissionManager.requestBluetoothPermission(this.context);
          if (granted) {
            this.scannedDevices = [];
            this.connectionStatus = "正在扫描...";
            this.btManager.startScan((device) => {
              let exists = this.scannedDevices.some(d => d.deviceId === device.deviceId);
              if (!exists) this.scannedDevices.push(device);
            });
          }
        })

      // 列表区域 (保留)
      List() {
        ForEach(this.scannedDevices, (item: ScannedDevice) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.deviceName || "未知设备").fontSize(18)
                Text(item.deviceId).fontSize(14).fontColor(Color.Gray)
              }
              Blank()
              Button("连接").height(32)
                .onClick(async () => {
                  this.btManager.stopScan();
                  this.connectionStatus = `正在连接 ${item.deviceId}...`;
                  await this.btManager.connect(item.deviceId);
                })
            }
            .width('100%').padding(10).backgroundColor('#F5F5F5').borderRadius(8).margin({ bottom: 5 })
          }
        })
      }
      .width('90%').height('25%').margin({ bottom: 20 })

      Divider().width('90%').color(Color.Gray)

      // 按钮区域
      Row({ space: 20 }) {
        Button("开 门 (1)")
          .type(ButtonType.Capsule).backgroundColor(Color.Blue).width(100)
          .onClick(() => this.btManager.openDoor())

        Button("关 门 (0)")
          .type(ButtonType.Capsule).backgroundColor(Color.Red).width(100)
          .onClick(() => this.btManager.closeDoor())
      }
      .margin({ top: 30 })
    }
    .width('100%').height('100%')
  }
}