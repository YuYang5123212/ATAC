import { BluetoothManager, ScannedDevice } from '../utils/BluetoothManager';
import { PermissionManager } from '../utils/PermissionManager';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

PersistentStorage.persistProp('HistoryDevices', []);

interface SavedDevice {
  deviceId: string;
  deviceName: string;
}

@Component
struct DeviceItem {
  device: ScannedDevice = { deviceId: '', deviceName: '', rssi: 0 };
  isHistory: boolean = false;
  btManager: BluetoothManager | null = null;
  onConnectSuccess: (device: ScannedDevice) => void = (device: ScannedDevice) => {};

  // 【核心变更】这里是一个数组，包含所有已连接的 ID
  @StorageLink('ConnectedIDs') connectedIDs: string[] = [];
  @State isConnecting: boolean = false;

  build() {
    Column() {
      // 上半部分：信息与连接按钮
      Row() {
        Column() {
          Text(this.device.deviceName || "未知设备")
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isConnected() ? '#007DFF' : '#333333')

          Text(this.device.deviceId)
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button(this.getButtonText())
          .height(30) // 稍微改小一点，给下面的控制留空间
          .fontSize(12)
          .backgroundColor(this.getButtonColor())
          .enabled(!this.isConnecting) // 只有连接中不可点
          .onClick(async () => {
            this.handleButtonClick();
          })
          .animation({ duration: 300 })
      }
      .width('100%')

      // 下半部分：控制面板 (只有连接成功才显示)
      if (this.isConnected()) {
        Row({ space: 20 }) {
          Button("开 门")
            .type(ButtonType.Normal)
            .borderRadius(8)
            .backgroundColor('#4CAF50') // 绿
            .fontColor(Color.White)
            .width('45%')
            .height(40)
            .onClick(() => {
              // 传入当前设备 ID
              this.btManager?.sendCommand(this.device.deviceId, "1");
            })

          Button("关 门")
            .type(ButtonType.Normal)
            .borderRadius(8)
            .backgroundColor('#FF5252') // 红
            .fontColor(Color.White)
            .width('45%')
            .height(40)
            .onClick(() => {
              this.btManager?.sendCommand(this.device.deviceId, "0");
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 15 })
        .transition({ type: TransitionType.All, opacity: 0, translate: { y: -10 } }) // 动画效果
      }
    }
    .width('100%')
    .padding(15)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 10 })
    .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })
    .animation({ duration: 300 }) // 让卡片高度变化有动画
  }

  // 判断当前设备是否在连接列表中
  isConnected(): boolean {
    return this.connectedIDs.includes(this.device.deviceId);
  }

  getButtonText(): string {
    if (this.isConnecting) return "连接中...";
    if (this.isConnected()) return "断 开";
    return "连 接";
  }

  getButtonColor(): ResourceColor {
    if (this.isConnecting) return '#CCCCCC';
    if (this.isConnected()) return '#E91E63'; // 断开用深红色区分
    return '#007DFF';
  }

  async handleButtonClick() {
    if (!this.btManager) return;

    if (this.isConnected()) {
      // 断开特定设备
      this.btManager.close(this.device.deviceId);
      return;
    }

    this.isConnecting = true;
    let success = await this.btManager.connect(this.device.deviceId);
    this.isConnecting = false;

    if (success) {
      this.onConnectSuccess(this.device);
    }
  }
}

@Component
export struct IndexPage {
  @StorageLink('HistoryDevices') historyDevices: SavedDevice[] = [];
  @State newDevices: ScannedDevice[] = [];

  private btManager = new BluetoothManager();
  private context = getContext(this) as common.UIAbilityContext;
  private scanTimer: number = -1;

  async aboutToAppear() {
    let granted = await PermissionManager.requestBluetoothPermission(this.context);
    if (granted) {
      this.refreshScan();
    }
  }

  onPageShow() {
    this.startScanLoop();
  }

  onPageHide() {
    this.stopScanLoop();
  }

  startScanLoop() {
    this.stopScanLoop();
    this.refreshScan();
    this.scanTimer = setInterval(() => {
      this.refreshScan();
    }, 5000);
  }

  stopScanLoop() {
    if (this.scanTimer !== -1) {
      clearInterval(this.scanTimer);
      this.scanTimer = -1;
    }
    this.btManager.stopScan();
  }

  refreshScan() {
    this.newDevices = [];
    this.btManager.startScan((device: ScannedDevice) => {
      let isHistory = this.historyDevices.some((d: SavedDevice) => d.deviceId === device.deviceId);

      if (!isHistory) {
        let exists = this.newDevices.some((d: ScannedDevice) => d.deviceId === device.deviceId);
        if (!exists) {
          this.newDevices.push(device);
        }
      }
    });
  }

  handleConnectSuccess(device: ScannedDevice) {
    let newHistory = this.historyDevices.filter((d: SavedDevice) => d.deviceId !== device.deviceId);
    newHistory.unshift({ deviceId: device.deviceId, deviceName: device.deviceName });
    this.historyDevices = newHistory;

    this.newDevices = this.newDevices.filter((d: ScannedDevice) => d.deviceId !== device.deviceId);
  }

  build() {
    Column() {
      Text("智能门禁")
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 20, top: 20, bottom: 10 })

      List() {
        // --- 已配对设备 ---
        if (this.historyDevices.length > 0) {
          ListItem() {
            Text("已配对设备")
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8, left: 5 })
          }

          ForEach(this.historyDevices, (item: SavedDevice) => {
            ListItem() {
              DeviceItem({
                device: { deviceId: item.deviceId, deviceName: item.deviceName, rssi: 0 },
                isHistory: true,
                btManager: this.btManager,
                onConnectSuccess: (d: ScannedDevice): void => this.handleConnectSuccess(d)
              })
            }
          })
        }

        // --- 新发现设备 ---
        ListItem() {
          Row() {
            Text("新发现设备")
              .fontSize(14)
              .fontColor('#666666')
            Blank()
            Text("刷新")
              .fontSize(14)
              .fontColor('#007DFF')
              .onClick(() => { this.refreshScan() })
          }
          .width('100%')
          .padding({ left: 5, right: 5, top: 10, bottom: 8 })
        }

        if (this.newDevices.length === 0) {
          ListItem() {
            Text("正在扫描附近设备...")
              .fontSize(14)
              .fontColor('#999999')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(20)
          }
        }

        ForEach(this.newDevices, (item: ScannedDevice) => {
          ListItem() {
            DeviceItem({
              device: item,
              isHistory: false,
              btManager: this.btManager,
              onConnectSuccess: (d: ScannedDevice): void => this.handleConnectSuccess(d)
            })
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 15, right: 15 })
      .edgeEffect(EdgeEffect.Spring)

      // 注意：底部的全局控制台被移除了，因为现在每个设备独立控制
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5')
  }
}