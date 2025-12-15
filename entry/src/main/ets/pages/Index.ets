import { BluetoothManager, ScannedDevice } from '../utils/BluetoothManager';
import { PermissionManager } from '../utils/PermissionManager';
// 引入 LogItem (注意路径要对，如果报错请确认 LogPage.ets 的位置)
// 这里我们为了方便，直接在下面重新定义接口结构，或者利用 Storage 直接操作
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

// 初始化持久化存储
PersistentStorage.persistProp('HistoryDevices', []);
PersistentStorage.persistProp('AppLogs', []); // 确保日志存储已初始化

interface SavedDevice {
  deviceId: string;
  deviceName: string;
}

// 简单的日志结构定义 (与 LogPage 保持一致)
interface LogItem {
  timestamp: string;
  deviceName: string;
  content: string;
  type: 'SEND' | 'RECV';
}

@Component
struct DeviceItem {
  device: ScannedDevice = { deviceId: '', deviceName: '', rssi: 0 };
  isHistory: boolean = false;
  btManager: BluetoothManager | null = null;
  onConnectSuccess: (device: ScannedDevice) => void = (device: ScannedDevice) => {};

  // 【新增】父组件传入的写日志方法
  onAddLog: (text: string, type: 'SEND' | 'RECV') => void = () => {};

  @StorageLink('ConnectedIDs') connectedIDs: string[] = [];
  @State isConnecting: boolean = false;

  @State doorState: number = 0;
  @State lastMessage: string = '';

  build() {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(this.device.deviceName || "未知设备")
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isConnected() ? '#007DFF' : '#333333')

            if (this.isConnected()) {
              if (this.doorState === 1) {
                Text(" [🔓]")
                  .fontSize(14)
                  .fontColor('#4CAF50')
                  .fontWeight(FontWeight.Bold)
              } else if (this.doorState === 2) {
                Text(" [🔒]")
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

      if (this.isConnected()) {
        Column() {
          Divider().color('#F0F0F0').margin({ top: 10, bottom: 10 })

          Row() {
            Text("RX: " + (this.lastMessage || "等待数据..."))
              .fontSize(12)
              .fontColor('#666666')
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
          }
          .width('100%')
          .padding({ left: 5, bottom: 10 })

          Row({ space: 15 }) {
            Button("开 门")
              .type(ButtonType.Normal)
              .borderRadius(8)
              .backgroundColor('#4CAF50')
              .fontColor(Color.White)
              .layoutWeight(1)
              .height(40)
              .onClick(() => {
                this.btManager?.sendCommand(this.device.deviceId, "1");
                // 【埋点】记录日志
                this.onAddLog("发送开门指令", 'SEND');
              })

            Button("关 门")
              .type(ButtonType.Normal)
              .borderRadius(8)
              .backgroundColor('#FF5252')
              .fontColor(Color.White)
              .layoutWeight(1)
              .height(40)
              .onClick(() => {
                this.btManager?.sendCommand(this.device.deviceId, "0");
                this.onAddLog("发送关门指令", 'SEND');
              })

            Button("查 询")
              .type(ButtonType.Normal)
              .borderRadius(8)
              .backgroundColor('#FF9800')
              .fontColor(Color.White)
              .layoutWeight(1)
              .height(40)
              .onClick(() => {
                this.btManager?.sendCommand(this.device.deviceId, "?");
                this.onAddLog("查询状态", 'SEND');
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
      this.doorState = 0;
      this.lastMessage = '';
      return;
    }

    this.isConnecting = true;
    let success = await this.btManager.connect(this.device.deviceId);
    this.isConnecting = false;

    if (success) {
      this.onConnectSuccess(this.device);
      this.onAddLog("连接成功", 'RECV');

      this.btManager.setOnDataReceived(this.device.deviceId, (data: string) => {
        let cleanData = data.trim();
        this.lastMessage = cleanData;

        // 【埋点】收到消息记录日志
        this.onAddLog(cleanData, 'RECV');

        if (cleanData.includes("OPEN")) {
          this.doorState = 1;
        } else if (cleanData.includes("CLOSE")) {
          this.doorState = 2;
        }
      });

      setTimeout(() => {
        this.btManager?.sendCommand(this.device.deviceId, "?");
      }, 3000);
    }
  }
}

@Component
export struct IndexPage {
  @StorageLink('HistoryDevices') historyDevices: SavedDevice[] = [];
  @State newDevices: ScannedDevice[] = [];

  // 绑定全局日志
  @StorageLink('AppLogs') appLogs: LogItem[] = [];

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

  // 【新增】添加日志的辅助函数
  addLog(deviceName: string, content: string, type: 'SEND' | 'RECV') {
    // 获取当前时间 HH:mm:ss
    let now = new Date();
    let timeStr = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}`;

    let newItem: LogItem = {
      timestamp: timeStr,
      deviceName: deviceName,
      content: content,
      type: type
    };

    // 插入到最前面
    this.appLogs.unshift(newItem);

    // 限制日志条数，防止无限增长 (保留最近100条)
    if (this.appLogs.length > 100) {
      this.appLogs = this.appLogs.slice(0, 100);
    }
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
      Text("AT智能门禁")
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
                onConnectSuccess: (d: ScannedDevice): void => this.handleConnectSuccess(d),
                // 【核心】将 addLog 函数传给子组件使用
                onAddLog: (text, type) => {
                  this.addLog(item.deviceName || "未知", text, type);
                }
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
              onConnectSuccess: (d: ScannedDevice): void => this.handleConnectSuccess(d),
              // 【核心】传递日志回调
              onAddLog: (text, type) => {
                this.addLog(item.deviceName || "未知", text, type);
              }
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