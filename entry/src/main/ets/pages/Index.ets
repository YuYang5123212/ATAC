import { BluetoothManager, ScannedDevice } from '../utils/BluetoothManager';
import { PermissionManager } from '../utils/PermissionManager';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

@Component
export struct IndexPage {
  // 状态变量
  @State connectionStatus: string = "未连接";
  @State scannedDevices: Array<ScannedDevice> = [];

  // 实例化管理器
  private btManager = new BluetoothManager();
  private context = getContext(this) as common.UIAbilityContext;

  build() {
    Column() {
      // 1. 标题区
      Text("智能门禁控制系统")
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 10 })

      Text(`当前状态: ${this.connectionStatus}`)
        .fontSize(16)
        .fontColor(this.connectionStatus.includes("已连接") ? Color.Green : Color.Gray)
        .margin({ bottom: 20 })

      // 2. 扫描按钮
      Button("扫描设备")
        .width('80%')
        .onClick(async () => {
          // 先申请权限
          let granted = await PermissionManager.requestBluetoothPermission(this.context);
          if (granted) {
            this.scannedDevices = []; // 清空旧列表
            this.connectionStatus = "正在扫描...";

            // 启动扫描
            this.btManager.startScan((device) => {
              // 简单的去重逻辑
              let exists = this.scannedDevices.some(d => d.deviceId === device.deviceId);
              if (!exists) {
                this.scannedDevices.push(device);
              }
            });
          }
        })

      // 3. 扫描结果列表
      List() {
        ForEach(this.scannedDevices, (item: ScannedDevice) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.deviceName).fontSize(18).fontWeight(FontWeight.Bold)
                Text(item.deviceId).fontSize(14).fontColor(Color.Gray)
              }
              Blank()
              Button("连接")
                .height(32)
                .onClick(async () => {
                  this.connectionStatus = `正在连接 ${item.deviceName}...`;
                  let isSuccess = await this.btManager.connect(item.deviceId);
                  if (isSuccess) {
                    this.connectionStatus = "已连接: " + item.deviceName;
                    this.scannedDevices = []; // 连接成功后清空列表，保持界面整洁
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
      .height('30%') // 限制列表高度
      .margin({ bottom: 20 })

      Divider().width('90%').color(Color.Gray)

      // 4. 控制按钮区
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