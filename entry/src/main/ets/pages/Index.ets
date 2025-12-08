import { BluetoothManager, ScannedDevice } from '../utils/BluetoothManager';
import { PermissionManager } from '../utils/PermissionManager';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

// 定义按钮状态枚举，让逻辑更清晰
enum ConnectState {
  IDLE_CONNECT = 0,   // 闲置状态（显示：连接，蓝色）
  CONNECTING = 1,     // 连接中（显示：连接中...，灰色）
  SUCCESS = 2,        // 连接成功（显示：已连接，绿色）
  CONNECTED_IDLE = 3, // 已连接待机（显示：断开，蓝色）
  FAILED = 4          // 连接失败（显示：连接失败，红色）
}

// 【新增】子组件：专门管理列表中的每一行设备
@Component
struct DeviceItem {
  device: ScannedDevice = { deviceId: '', deviceName: '', rssi: 0 };
  btManager: BluetoothManager | null = null;

  // 每个按钮独立管理自己的状态
  @State btnState: ConnectState = ConnectState.IDLE_CONNECT;

  build() {
    Row() {
      Column() {
        // 显示名称，如果没有名称显示未知
        Text(this.device.deviceName || "未知设备")
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        // 显示 MAC 地址
        Text(this.device.deviceId)
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      // 动态按钮
      Button(this.getButtonText())
        .height(36)
        .fontSize(14)
        .backgroundColor(this.getButtonColor())
        .enabled(this.btnState !== ConnectState.CONNECTING) // 连接中禁用点击
        .onClick(async () => {
          this.handleButtonClick();
        })
        .animation({ duration: 300 }) // 添加颜色渐变动画
    }
    .width('100%')
    .padding({ left: 15, right: 15, top: 12, bottom: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12) // 圆角卡片风格
    .margin({ bottom: 10 })
    .shadow({ radius: 4, color: '#1A000000', offsetY: 2 }) // 轻微阴影
  }

  // 获取按钮文字
  getButtonText(): string {
    switch (this.btnState) {
      case ConnectState.IDLE_CONNECT: return "连 接";
      case ConnectState.CONNECTING: return "连接中...";
      case ConnectState.SUCCESS: return "已连接";
      case ConnectState.CONNECTED_IDLE: return "断 开";
      case ConnectState.FAILED: return "连接失败";
      default: return "连 接";
    }
  }

  // 获取按钮颜色
  getButtonColor(): ResourceColor {
    switch (this.btnState) {
      case ConnectState.IDLE_CONNECT: return '#007DFF'; // 华为蓝
      case ConnectState.CONNECTING: return '#CCCCCC';   // 灰色
      case ConnectState.SUCCESS: return '#4CAF50';      // 绿色
      case ConnectState.CONNECTED_IDLE: return '#007DFF'; // 蓝色（断开状态）
      case ConnectState.FAILED: return '#FF5252';       // 红色
      default: return '#007DFF';
    }
  }

  // 处理点击逻辑
  async handleButtonClick() {
    if (!this.btManager) return;

    // 逻辑 A: 当前是“断开”状态 -> 执行断开操作
    if (this.btnState === ConnectState.CONNECTED_IDLE) {
      this.btManager.close();
      this.btnState = ConnectState.IDLE_CONNECT; // 恢复为“连接”
      return;
    }

    // 逻辑 B: 当前是“连接”状态 -> 执行连接操作
    if (this.btnState === ConnectState.IDLE_CONNECT || this.btnState === ConnectState.FAILED) {
      this.btnState = ConnectState.CONNECTING; // 变灰
      this.btManager.stopScan(); // 停止扫描

      // 执行连接
      let success = await this.btManager.connect(this.device.deviceId);

      if (success) {
        // 成功：变绿 -> 2秒后 -> 变蓝(断开)
        this.btnState = ConnectState.SUCCESS;
        setTimeout(() => {
          // 只有当前还在 Success 状态才切换，防止用户手速快乱点
          if (this.btnState === ConnectState.SUCCESS) {
            this.btnState = ConnectState.CONNECTED_IDLE;
          }
        }, 2000);
      } else {
        // 失败：变红 -> 2秒后 -> 变蓝(连接)
        this.btnState = ConnectState.FAILED;
        setTimeout(() => {
          if (this.btnState === ConnectState.FAILED) {
            this.btnState = ConnectState.IDLE_CONNECT;
          }
        }, 2000);
      }
    }
  }
}

// 主界面
@Component
export struct IndexPage {
  @State scannedDevices: Array<ScannedDevice> = [];

  private btManager = new BluetoothManager();
  private context = getContext(this) as common.UIAbilityContext;

  build() {
    Column() {
      // 1. 顶部标题栏
      Text("智能门禁")
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: 20, top: 20, bottom: 10 })

      // 2. 扫描按钮
      Button("扫描设备")
        .width('90%')
        .height(45)
        .fontSize(16)
        .backgroundColor('#007DFF')
        .margin({ bottom: 15 }) // 增加底部间距
        .onClick(async () => {
          let granted = await PermissionManager.requestBluetoothPermission(this.context);
          if (granted) {
            this.scannedDevices = [];
            this.btManager.startScan((device) => {
              // 简单去重
              let exists = this.scannedDevices.some(d => d.deviceId === device.deviceId);
              if (!exists) {
                this.scannedDevices.push(device);
              }
            });
          }
        })

      // 3. 设备列表 (使用 layoutWeight 占据剩余高度)
      List() {
        ForEach(this.scannedDevices, (item: ScannedDevice) => {
          ListItem() {
            // 引用上面的子组件
            DeviceItem({ device: item, btManager: this.btManager })
          }
        })
      }
      .layoutWeight(1) // 【关键】占据剩余所有空间，让列表尽可能长
      .width('100%')
      .padding({ left: 15, right: 15 })
      .edgeEffect(EdgeEffect.Spring) // 添加回弹效果，体验更好

      // 4. 底部控制区 (加了阴影和圆角背景，像个控制台)
      Column() {
        Text("门禁控制台")
          .fontSize(14)
          .fontColor('#999999')
          .margin({ bottom: 10 })

        Row({ space: 30 }) {
          Button("开 门")
            .type(ButtonType.Circle) // 圆形按钮
            .width(80)
            .height(80)
            .backgroundColor('#4CAF50') // 绿色
            .fontSize(18)
            .shadow({ radius: 10, color: '#4CAF50', offsetY: 5 })
            .onClick(() => {
              this.btManager.openDoor();
            })

          Button("关 门")
            .type(ButtonType.Circle) // 圆形按钮
            .width(80)
            .height(80)
            .backgroundColor('#FF5252') // 红色
            .fontSize(18)
            .shadow({ radius: 10, color: '#FF5252', offsetY: 5 })
            .onClick(() => {
              this.btManager.closeDoor();
            })
        }
      }
      .width('100%')
      .padding({ top: 20, bottom: 30 })
      .backgroundColor('#F9F9F9') // 浅灰背景区分控制区
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5') // 整体背景色
  }
}