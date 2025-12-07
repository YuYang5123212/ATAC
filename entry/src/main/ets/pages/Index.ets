// F:/Harmony/ArduinoandHarmony/entry/src/main/ets/pages/Index.ets
import { BluetoothManager } from '../utils/BluetoothManager';
import { Button } from '@kit.ArkUI';
import { PermissionManager } from '../utils/PermissionManager';
import type common from '@ohos.app.ability.common';

@Entry
@Component
export struct IndexPage {
  @State connectionStatus: string = "未连接";
  private btManager: BluetoothManager = new BluetoothManager();

  private abilityContext: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  build() {
    Column({ space: 20 }) {

      Text("智能门禁控制 (HC-05)")
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 50 })

      Text(`状态: ${this.connectionStatus}`)
        .fontSize(18)
        .fontColor(this.connectionStatus === "已连接" ? Color.Green : Color.Red)

      Button("连接设备")
        .width('80%')
        .height(50)
        // 【关键修正】：给异步函数添加显式返回类型 'void' (解决 ERROR 1)
        .onClick(async (): Promise<void> => {
          this.connectionStatus = "权限检查...";

          // 核心修改：先请求权限
          let hasPermission = await PermissionManager.requestBluetoothPermission(this.abilityContext);

          if (!hasPermission) {
            this.connectionStatus = "未连接 (缺少权限)";
            return;
          }

          // 权限通过后，再执行连接逻辑
          this.connectionStatus = "连接中...";
          let isSuccess = await this.btManager.connectToHC05();

          if (isSuccess) {
            this.connectionStatus = "已连接";
          } else {
            this.connectionStatus = "连接失败";
          }
        })
      Divider()

      Button("开门 (发送 '1')")
        .width('80%')
        .height(60)
        .backgroundColor(Color.Orange)
        .onClick(() => {
          this.btManager.sendCommand("1");
        })

      Button("关门 (发送 '0')")
        .width('80%')
        .height(60)
        .backgroundColor(Color.Gray)
        .onClick(() => {
          this.btManager.sendCommand("0");
        })

    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }
}