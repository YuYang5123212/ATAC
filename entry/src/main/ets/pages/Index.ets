import { BluetoothManager, ScannedDevice } from '../utils/BluetoothManager';
import { PermissionManager } from '../utils/PermissionManager';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

@Component
export struct IndexPage {
  @State connectionStatus: string = "未连接";
  @State scannedDevices: Array<ScannedDevice> = [];

  private btManager = new BluetoothManager();
  private context = getContext(this) as common.UIAbilityContext;

  build() {
    Column() {
      // 标题
      Text("智能门禁控制")
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 10 })

      Text(`状态: ${this.connectionStatus}`)
        .fontSize(16)
        .fontColor(this.connectionStatus.includes("已连接") ? Color.Green : Color.Gray)
        .margin({ bottom: 20 })

      // 扫描按钮
      Button("扫描设备")
        .width('80%')
        .onClick(async () => {
          let granted = await PermissionManager.requestBluetoothPermission(this.context);
          if (granted) {
            this.scannedDevices = [];
            this.connectionStatus = "正在扫描...";

            this.btManager.startScan((device) => {
              // 简单去重
              let exists = this.scannedDevices.some(d => d.deviceId === device.deviceId);
              if (!exists) {
                this.scannedDevices.push(device);
              }
            });
          }
        })

      // 列表区域
      List() {
        ForEach(this.scannedDevices, (item: ScannedDevice) => {
          ListItem() {
            Row() {
              Column() {
                // 显示名称，如果没有名称显示未知
                Text(item.deviceName || "未知设备")
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                // 必须显示 MAC 地址，方便确认
                Text(item.deviceId)
                  .fontSize(14)
                  .fontColor(Color.Gray)
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Button("连接")
                .height(32)
                .onClick(async () => {
                  this.btManager.stopScan();
                  this.connectionStatus = `正在连接 ${item.deviceName || item.deviceId}...`;
                  let isSuccess = await this.btManager.connect(item.deviceId);
                  if (isSuccess) {
                    this.connectionStatus = "已连接";
                    this.scannedDevices = [];
                  } else {
                    this.connectionStatus = "连接失败";
                  }
                })
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .margin({ bottom: 5 })
          }
        })
      }
      .width('90%')
      .height('40%')
      .margin({ bottom: 20 })

      Divider().width('90%').color(Color.Gray)

      // 按钮区域
      Row({ space: 20 }) {
        Button("开 门")
          .type(ButtonType.Capsule)
          .backgroundColor(Color.Blue)
          .width(100)
          .onClick(() => {
            this.btManager.openDoor();
          })

        Button("关 门")
          .type(ButtonType.Capsule)
          .backgroundColor(Color.Red)
          .width(100)
          .onClick(() => {
            this.btManager.closeDoor();
          })
      }
      .margin({ top: 30 })
    }
    .width('100%')
    .height('100%')
  }
}