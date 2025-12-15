import { BluetoothManager, ScannedDevice } from '../utils/BluetoothManager';
import { PermissionManager } from '../utils/PermissionManager';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

PersistentStorage.persistProp('HistoryDevices', []);
PersistentStorage.persistProp('AppLogs', []);

interface SavedDevice {
  deviceId: string;
  deviceName: string;
}

interface LogItem {
  timestamp: string;
  deviceName: string;
  content: string;
  type: 'SEND' | 'RECV';
}

// 【新增】密码输入弹窗
@CustomDialog
struct PasswordDialog {
  controller: CustomDialogController;
  confirmAction: () => void = () => {};
  @State inputValue: string = '';

  build() {
    Column() {
      Text("安全验证")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 10 })

      Text("首次开门请输入密码")
        .fontSize(14)
        .fontColor('#999999')
        .margin({ bottom: 20 })

      TextInput({ placeholder: '请输入密码 (123)' })
        .type(InputType.Password)
        .maxLength(6)
        .width('85%')
        .height(45)
        .onChange((value: string) => {
          this.inputValue = value;
        })

      Row() {
        Button("取消")
          .onClick(() => this.controller.close())
          .backgroundColor(Color.Transparent)
          .fontColor('#666666')
          .layoutWeight(1)

        Button("确认")
          .onClick(() => {
            if (this.inputValue === '123') {
              this.confirmAction();
              this.controller.close();
            } else {
              try { promptAction.showToast({ message: '密码错误' }); } catch(e) {}
            }
          })
          .backgroundColor(Color.Transparent)
          .fontColor('#007DFF')
          .layoutWeight(1)
      }
      .margin({ top: 20, bottom: 10 })
      .width('100%')
    }
    .width('80%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }
}

@Component
struct DeviceItem {
  device: ScannedDevice = { deviceId: '', deviceName: '', rssi: 0 };
  isHistory: boolean = false;
  btManager: BluetoothManager | null = null;
  onConnectSuccess: (device: ScannedDevice) => void = (device: ScannedDevice) => {};
  onAddLog: (text: string, type: 'SEND' | 'RECV') => void = () => {};

  @StorageLink('ConnectedIDs') connectedIDs: string[] = [];
  @State isConnecting: boolean = false;
  @State doorState: number = 0;
  @State lastMessage: string = '';

  // 【新增】本次连接是否已验证密码
  @State hasVerified: boolean = false;

  // 密码弹窗控制器
  dialogController: CustomDialogController = new CustomDialogController({
    builder: PasswordDialog({
      confirmAction: () => {
        // 验证通过后的回调
        this.hasVerified = true;
        this.performOpenDoor(); // 执行开门
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

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
                Text(" [已开]").fontSize(14).fontColor('#4CAF50').fontWeight(FontWeight.Bold)
              } else if (this.doorState === 2) {
                Text(" [已关]").fontSize(14).fontColor('#FF5252').fontWeight(FontWeight.Bold)
              }
            }
          }

          Text(this.device.deviceId).fontSize(14).fontColor('#999999').margin({ top: 4 })
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
              .fontSize(12).fontColor('#666666').textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
          }
          .width('100%').padding({ left: 5, bottom: 10 })

          Row({ space: 15 }) {
            // 开门按钮 (增加验证逻辑)
            Button("开 门")
              .type(ButtonType.Normal).borderRadius(8).backgroundColor('#4CAF50')
              .fontColor(Color.White).layoutWeight(1).height(40)
              .onClick(() => {
                this.handleOpenClick();
              })

            Button("关 门")
              .type(ButtonType.Normal).borderRadius(8).backgroundColor('#FF5252')
              .fontColor(Color.White).layoutWeight(1).height(40)
              .onClick(() => {
                // 关门通常不需要密码
                this.btManager?.sendCommand(this.device.deviceId, "0");
                this.onAddLog("发送关门指令", 'SEND');
              })

            Button("查 询")
              .type(ButtonType.Normal).borderRadius(8).backgroundColor('#FF9800')
              .fontColor(Color.White).layoutWeight(1).height(40)
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

  // 处理开门点击
  handleOpenClick() {
    if (this.hasVerified) {
      // 已经验证过，直接开门
      this.performOpenDoor();
    } else {
      // 未验证，弹窗
      this.dialogController.open();
    }
  }

  // 执行实际开门指令
  performOpenDoor() {
    this.btManager?.sendCommand(this.device.deviceId, "1");
    this.onAddLog("发送开门指令", 'SEND');
    try { promptAction.showToast({ message: '验证通过，开门指令已发送' }); } catch(e) {}
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

    // 开始连接时，重置验证状态
    this.hasVerified = false;
    this.isConnecting = true;
    let success = await this.btManager.connect(this.device.deviceId);
    this.isConnecting = false;

    if (success) {
      this.onConnectSuccess(this.device);
      this.onAddLog("连接成功", 'RECV');

      this.btManager.setOnDataReceived(this.device.deviceId, (data: string) => {
        let cleanData = data.trim();
        this.lastMessage = cleanData;
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

  addLog(deviceName: string, content: string, type: 'SEND' | 'RECV') {
    let now = new Date();
    let timeStr = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}`;
    let newItem: LogItem = { timestamp: timeStr, deviceName: deviceName, content: content, type: type };
    this.appLogs.unshift(newItem);
    if (this.appLogs.length > 100) this.appLogs = this.appLogs.slice(0, 100);
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
            Text("已配对设备").fontSize(14).fontColor('#666666').margin({ bottom: 8, left: 5 })
          }
          ForEach(this.historyDevices, (item: SavedDevice) => {
            ListItem() {
              DeviceItem({
                device: { deviceId: item.deviceId, deviceName: item.deviceName, rssi: 0 },
                isHistory: true,
                btManager: this.btManager,
                onConnectSuccess: (d: ScannedDevice): void => this.handleConnectSuccess(d),
                onAddLog: (text, type) => { this.addLog(item.deviceName || "未知", text, type); }
              })
            }
          })
        }

        ListItem() {
          Row() {
            Text("新发现设备").fontSize(14).fontColor('#666666')
            Blank()
            Text("刷新").fontSize(14).fontColor('#007DFF').onClick(() => { this.refreshScan() })
          }
          .width('100%').padding({ left: 5, right: 5, top: 10, bottom: 8 })
        }

        if (this.newDevices.length === 0) {
          ListItem() {
            Text("正在扫描附近设备...").fontSize(14).fontColor('#999999').width('100%').textAlign(TextAlign.Center).padding(20)
          }
        }

        ForEach(this.newDevices, (item: ScannedDevice) => {
          ListItem() {
            DeviceItem({
              device: item,
              isHistory: false,
              btManager: this.btManager,
              onConnectSuccess: (d: ScannedDevice): void => this.handleConnectSuccess(d),
              onAddLog: (text, type) => { this.addLog(item.deviceName || "未知", text, type); }
            })
          }
        })
      }
      .layoutWeight(1).width('100%').padding({ left: 15, right: 15 }).edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }
}