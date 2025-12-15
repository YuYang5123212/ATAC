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

  @StorageLink('ConnectedIDs') connectedIDs: string[] = [];
  @State isConnecting: boolean = false;

  // 【新增】门锁状态：0=未知, 1=已开, 2=已关
  @State doorState: number = 0;
  // 【新增】最后收到的消息
  @State lastMessage: string = '';

  build() {
    Column() {
      // --- 上半部分：设备信息 & 连接按钮 ---
      Row() {
        Column() {
          Row() {
            Text(this.device.deviceName || "未知设备")
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isConnected() ? '#007DFF' : '#333333')

            // 【新增】状态小标签
            if (this.isConnected()) {
              if (this.doorState === 1) {
                Text(" [已开]")
                  .fontSize(14)
                  .fontColor('#4CAF50')
                  .fontWeight(FontWeight.Bold)
              } else if (this.doorState === 2) {
                Text(" [已关]")
                  .fontSize(14)
                  .fontColor('#FF5252')
                  .fontWeight(FontWeight.Bold)
              }
            }
          }

          Text(this.device.deviceId)
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button(this.getButtonText())
          .height(30)
          .fontSize(12)
          .backgroundColor(this.getButtonColor())
          .enabled(!this.isConnecting)
          .onClick(async () => {
            this.handleButtonClick();
          })
          .animation({ duration: 300 })
      }
      .width('100%')

      // --- 下半部分：控制面板 (连接成功显示) ---
      if (this.isConnected()) {
        Column() {
          Divider().color('#F0F0F0').margin({ top: 10, bottom: 10 })

          // 【新增】消息回显区
          Row() {
            Text("RX: " + (this.lastMessage || "等待数据..."))
              .fontSize(12)
              .fontColor('#666666')
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
          }
          .width('100%')
          .padding({ left: 5, bottom: 10 })

          // 按钮组
          Row({ space: 15 }) {
            // 开门
            Button("开 门")
              .type(ButtonType.Normal)
              .borderRadius(8)
              .backgroundColor('#4CAF50')
              .fontColor(Color.White)
              .layoutWeight(1) // 均分宽度
              .height(40)
              .onClick(() => {
                this.btManager?.sendCommand(this.device.deviceId, "1");
                this.lastMessage = "发送: 开门";
              })

            // 关门
            Button("关 门")
              .type(ButtonType.Normal)
              .borderRadius(8)
              .backgroundColor('#FF5252')
              .fontColor(Color.White)
              .layoutWeight(1)
              .height(40)
              .onClick(() => {
                this.btManager?.sendCommand(this.device.deviceId, "0");
                this.lastMessage = "发送: 关门";
              })

            // 【新增】查询按钮
            Button("查 询")
              .type(ButtonType.Normal)
              .borderRadius(8)
              .backgroundColor('#FF9800') // 橙色
              .fontColor(Color.White)
              .layoutWeight(1)
              .height(40)
              .onClick(() => {
                this.btManager?.sendCommand(this.device.deviceId, "?");
                this.lastMessage = "发送: 查询状态";
              })
          }
          .width('100%')
        }
        .transition({ type: TransitionType.All, opacity: 0, translate: { y: -10 } })
      }
    }
    .width('100%')
    .padding(15)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 10 })
    .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })
    .animation({ duration: 300 })
  }

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
    if (this.isConnected()) return '#E91E63';
    return '#007DFF';
  }

  async handleButtonClick() {
    if (!this.btManager) return;

    if (this.isConnected()) {
      this.btManager.close(this.device.deviceId);
      // 断开时重置状态
      this.doorState = 0;
      this.lastMessage = '';
      return;
    }

    this.isConnecting = true;
    let success = await this.btManager.connect(this.device.deviceId);
    this.isConnecting = false;

    if (success) {
      this.onConnectSuccess(this.device);

      // 【核心逻辑】注册数据监听，处理 Arduino 回传
      this.btManager.setOnDataReceived(this.device.deviceId, (data: string) => {
        // 去除回车换行，更新消息显示
        let cleanData = data.trim();
        this.lastMessage = cleanData;

        // 解析状态 (根据你的 Arduino 代码：SUCCESS:OPENED / STATE:OPEN)
        if (cleanData.includes("OPEN")) {
          this.doorState = 1; // 开锁状态
        } else if (cleanData.includes("CLOSE")) {
          this.doorState = 2; // 关锁状态
        }
      });

      // 自动查一次状态，同步 UI
      setTimeout(() => {
        this.btManager?.sendCommand(this.device.deviceId, "?");
      }, 3000); // 给一点时间让连接完全稳定
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5')
  }
}