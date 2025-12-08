import { BluetoothManager, ScannedDevice } from '../utils/BluetoothManager';
import { PermissionManager } from '../utils/PermissionManager';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

// 初始化持久化存储
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
    // 1. 如果正在连接中，禁用
    if (this.isConnecting) return false;

    // 2. 如果连着别的设备，禁用（防止多连冲突）
    if (this.currentConnectedID !== '' && !this.isConnected()) return false;

    // 其他情况（包括历史设备无论是否在线）都允许点击
    return true;
  }

  getButtonText(): string {
    if (this.isConnecting) return "连接中...";
    if (this.isConnected()) return "断 开";
    // 历史设备不再显示"未找到"或"尝试连接"，统一回归原始设计
    return "连 接";
  }

  getButtonColor(): ResourceColor {
    if (this.isConnecting) return '#CCCCCC';
    if (this.isConnected()) return '#FF5252';
    // 默认蓝色
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
  @State newDevices: ScannedDevice[] = [];

  private btManager = new BluetoothManager();
  private context = getContext(this) as common.UIAbilityContext;
  private scanTimer: number = -1; // 定时器 ID

  async aboutToAppear() {
    let granted = await PermissionManager.requestBluetoothPermission(this.context);
    if (granted) {
      // 首次加载立即扫描
      this.refreshScan();
    }
  }

  onPageShow() {
    // 页面显示时，启动周期性刷新 (每5秒)
    this.startScanLoop();
  }

  onPageHide() {
    // 页面隐藏时，停止定时器和扫描，节省电量
    this.stopScanLoop();
  }

  startScanLoop() {
    // 先清除旧的定时器防止叠加
    this.stopScanLoop();

    // 立即执行一次
    this.refreshScan();

    // 开启循环
    this.scanTimer = setInterval(() => {
      this.refreshScan();
    }, 5000); // 5000ms = 5秒
  }

  stopScanLoop() {
    if (this.scanTimer !== -1) {
      clearInterval(this.scanTimer);
      this.scanTimer = -1;
    }
    // 可选：页面隐藏时停止蓝牙扫描
    this.btManager.stopScan();
  }

  // 执行一次刷新扫描
  refreshScan() {
    // 清空“新发现设备”，防止显示已经离开的设备
    // 注意：不清空 historyDevices，因为它们是持久化的
    this.newDevices = [];

    this.btManager.startScan((device: ScannedDevice) => {
      let isHistory = this.historyDevices.some((d: SavedDevice) => d.deviceId === device.deviceId);

      if (!isHistory) {
        // 如果是新设备，且列表里还没有
        let exists = this.newDevices.some((d: ScannedDevice) => d.deviceId === device.deviceId);
        if (!exists) {
          this.newDevices.push(device);
        }
      }
      // 如果是历史设备，我们不需要做什么，因为它已经永久显示在上面的列表里了
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
        // --- 第一部分：已配对设备 (始终显示，始终可点) ---
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
                // 构造一个临时的 ScannedDevice 对象传进去
                device: { deviceId: item.deviceId, deviceName: item.deviceName, rssi: 0 },
                isHistory: true,
                btManager: this.btManager,
                onConnectSuccess: (d: ScannedDevice): void => this.handleConnectSuccess(d)
              })
            }
          })
        }

        // --- 第二部分：新发现设备 (每5秒刷新一次) ---
        ListItem() {
          Row() {
            Text("新发现设备")
              .fontSize(14)
              .fontColor('#666666')
            Blank()
            // 手动刷新按钮（虽然有自动刷新，但保留手动也不错）
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