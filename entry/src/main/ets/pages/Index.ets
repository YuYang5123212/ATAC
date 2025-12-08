import { BluetoothManager, ScannedDevice } from '../utils/BluetoothManager';
import { PermissionManager } from '../utils/PermissionManager';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

// 初始化持久化存储
PersistentStorage.persistProp('HistoryDevices', []);

// 设备数据结构（用于存储）
interface SavedDevice {
  deviceId: string;
  deviceName: string;
}

@Component
struct DeviceItem {
  // 【修复1】给所有属性添加默认初始值
  device: ScannedDevice = { deviceId: '', deviceName: '', rssi: 0 };
  isHistory: boolean = false;
  isOnline: boolean = false;
  btManager: BluetoothManager | null = null;
  // 回调函数也要初始化
  onConnectSuccess: (device: ScannedDevice) => void = (device: ScannedDevice) => {};

  // 全局连接状态
  @StorageLink('CurrentConnectedID') currentConnectedID: string = '';
  @State isConnecting: boolean = false;

  build() {
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
        .height(36)
        .fontSize(14)
        .backgroundColor(this.getButtonColor())
        .enabled(this.isButtonEnabled())
        .onClick(async () => {
          this.handleButtonClick();
        })
        .animation({ duration: 300 })
    }
    .width('100%')
    .padding({ left: 15, right: 15, top: 12, bottom: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 10 })
    .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })
  }

  isConnected(): boolean {
    return this.currentConnectedID === this.device.deviceId;
  }

  isButtonEnabled(): boolean {
    if (this.isHistory && !this.isOnline) return false;
    if (this.isConnecting) return false;
    if (this.currentConnectedID !== '' && !this.isConnected()) return false;
    return true;
  }

  getButtonText(): string {
    if (this.isHistory && !this.isOnline) return "未找到";
    if (this.isConnecting) return "连接中...";
    if (this.isConnected()) return "断 开";
    return "连 接";
  }

  getButtonColor(): ResourceColor {
    if (this.isHistory && !this.isOnline) return '#E0E0E0';
    if (this.isConnecting) return '#CCCCCC';
    if (this.isConnected()) return '#FF5252';
    return '#007DFF';
  }

  async handleButtonClick() {
    if (!this.btManager) return;

    if (this.isConnected()) {
      this.btManager.close();
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
  @State onlineHistoryIDs: string[] = [];
  @State newDevices: ScannedDevice[] = [];

  private btManager = new BluetoothManager();
  private context = getContext(this) as common.UIAbilityContext;

  async aboutToAppear() {
    let granted = await PermissionManager.requestBluetoothPermission(this.context);
    if (granted) {
      this.startScan();
    }
  }

  startScan() {
    this.onlineHistoryIDs = [];
    this.newDevices = [];

    this.btManager.startScan((device: ScannedDevice) => {
      let isHistory = this.historyDevices.some((d: SavedDevice) => d.deviceId === device.deviceId);

      if (isHistory) {
        if (!this.onlineHistoryIDs.includes(device.deviceId)) {
          this.onlineHistoryIDs.push(device.deviceId);
        }
      } else {
        let exists = this.newDevices.some((d: ScannedDevice) => d.deviceId === device.deviceId);
        if (!exists) {
          this.newDevices.push(device);
        }
      }
    });
  }

  getDisplayHistoryList(): ScannedDevice[] {
    let list: ScannedDevice[] = [];

    this.historyDevices.forEach((saved: SavedDevice) => {
      list.push({
        deviceId: saved.deviceId,
        deviceName: saved.deviceName,
        rssi: 0
      });
    });

    list.sort((a: ScannedDevice, b: ScannedDevice) => {
      let aOnline = this.onlineHistoryIDs.includes(a.deviceId);
      let bOnline = this.onlineHistoryIDs.includes(b.deviceId);
      if (aOnline && !bOnline) return -1;
      if (!aOnline && bOnline) return 1;
      return 0;
    });

    return list;
  }

  handleConnectSuccess(device: ScannedDevice) {
    let newHistory = this.historyDevices.filter((d: SavedDevice) => d.deviceId !== device.deviceId);
    newHistory.unshift({ deviceId: device.deviceId, deviceName: device.deviceName });
    this.historyDevices = newHistory;

    this.newDevices = this.newDevices.filter((d: ScannedDevice) => d.deviceId !== device.deviceId);

    if (!this.onlineHistoryIDs.includes(device.deviceId)) {
      this.onlineHistoryIDs.push(device.deviceId);
    }
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

          ForEach(this.getDisplayHistoryList(), (item: ScannedDevice) => {
            ListItem() {
              // 【修复2】显式声明回调参数类型 (d: ScannedDevice): void
              DeviceItem({
                device: item,
                isHistory: true,
                isOnline: this.onlineHistoryIDs.includes(item.deviceId),
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
              .onClick(() => { this.startScan() })
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
            // 【修复2】显式声明回调参数类型 (d: ScannedDevice): void
            DeviceItem({
              device: item,
              isHistory: false,
              isOnline: true,
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

      Column() {
        Row({ space: 40 }) {
          Button("开 门")
            .type(ButtonType.Circle)
            .width(80)
            .height(80)
            .backgroundColor('#4CAF50')
            .fontSize(20)
            .shadow({ radius: 10, color: '#4CAF50', offsetY: 5 })
            .onClick(() => { this.btManager.openDoor(); })

          Button("关 门")
            .type(ButtonType.Circle)
            .width(80)
            .height(80)
            .backgroundColor('#FF5252')
            .fontSize(20)
            .shadow({ radius: 10, color: '#FF5252', offsetY: 5 })
            .onClick(() => { this.btManager.closeDoor(); })
        }
      }
      .width('100%')
      .padding({ top: 20, bottom: 30 })
      .backgroundColor('#F9F9F9')
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5')
  }
}