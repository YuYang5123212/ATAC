import { BluetoothManager, ScannedDevice } from '../utils/BluetoothManager';
import { PermissionManager } from '../utils/PermissionManager';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';
import { PreferencesUtil } from '../utils/PreferencesUtil';

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

@CustomDialog
struct PasswordDialog {
  controller: CustomDialogController;
  confirmAction: () => void = () => {};
  @State inputValue: string = '';

  build() {
    Column() {
      Text("安全验证").fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ top: 20, bottom: 10 })
      Text("首次开门请输入密码").fontSize(14).fontColor('#AAAAAA').margin({ bottom: 20 })
      TextInput({ placeholder: '请输入密码 (123)' }).type(InputType.Password).maxLength(6).width('85%').height(45)
        .backgroundColor('#333333').fontColor(Color.White).placeholderColor('#666666')
        .onChange((value: string) => { this.inputValue = value; })

      Row() {
        Button("取消").onClick(() => this.controller.close()).backgroundColor(Color.Transparent).fontColor('#AAAAAA').layoutWeight(1)
        Button("确认").onClick(() => {
          if (this.inputValue === '123') { this.confirmAction(); this.controller.close(); }
          else { try { promptAction.showToast({ message: '密码错误' }); } catch(e) {} }
        }).backgroundColor(Color.Transparent).fontColor('#007DFF').layoutWeight(1)
      }.margin({ top: 20, bottom: 10 }).width('100%')
    }.width('80%').backgroundColor('#1E1E1E').borderRadius(16)
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
  @State hasVerified: boolean = false;

  dialogController: CustomDialogController = new CustomDialogController({
    builder: PasswordDialog({ confirmAction: () => { this.hasVerified = true; this.performOpenDoor(); } }),
    autoCancel: true, alignment: DialogAlignment.Center, customStyle: true
  });

  build() {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(this.device.deviceName || "未知设备").fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.isConnected() ? '#448AFF' : Color.White)
            if (this.isConnected()) {
              if (this.doorState === 1) Text(" [已开]").fontSize(14).fontColor('#69F0AE').fontWeight(FontWeight.Bold)
              else if (this.doorState === 2) Text(" [已关]").fontSize(14).fontColor('#FF5252').fontWeight(FontWeight.Bold)
            }
          }
          Text(this.device.deviceId).fontSize(14).fontColor('#888888').margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Button(this.getButtonText()).height(30).fontSize(12).backgroundColor(this.getButtonColor()).enabled(!this.isConnecting)
          .onClick(async () => { this.handleButtonClick(); }).animation({ duration: 300 })
      }
      .width('100%')

      if (this.isConnected()) {
        Column() {
          Divider().color('#333333').margin({ top: 10, bottom: 10 })
          Row() {
            Text("RX: " + (this.lastMessage || "等待数据...")).fontSize(12).fontColor('#AAAAAA').textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
          }.width('100%').padding({ left: 5, bottom: 10 })

          Row({ space: 15 }) {
            Button("开 门").type(ButtonType.Normal).borderRadius(8).backgroundColor('#2E7D32').fontColor(Color.White).layoutWeight(1).height(40)
              .onClick(() => { this.handleOpenClick(); })
            Button("关 门").type(ButtonType.Normal).borderRadius(8).backgroundColor('#C62828').fontColor(Color.White).layoutWeight(1).height(40)
              .onClick(() => { this.btManager?.sendCommand(this.device.deviceId, "0"); this.onAddLog("发送关门指令", 'SEND'); })
            Button("查 询").type(ButtonType.Normal).borderRadius(8).backgroundColor('#EF6C00').fontColor(Color.White).layoutWeight(1).height(40)
              .onClick(() => { this.btManager?.sendCommand(this.device.deviceId, "?"); this.onAddLog("查询状态", 'SEND'); })
          }.width('100%')
        }.transition({ type: TransitionType.All, opacity: 0, translate: { y: -10 } })
      }
    }
    .width('100%').padding(15).backgroundColor('#1E1E1E').borderRadius(12).margin({ bottom: 10 })
    .shadow({ radius: 4, color: '#000000', offsetY: 2 }).animation({ duration: 300 })
  }

  isConnected(): boolean { return this.connectedIDs.includes(this.device.deviceId); }

  handleOpenClick() {
    if (this.hasVerified) this.performOpenDoor();
    else this.dialogController.open();
  }

  performOpenDoor() {
    this.btManager?.sendCommand(this.device.deviceId, "1");
    this.onAddLog("发送开门指令", 'SEND');
    try { promptAction.showToast({ message: '验证通过，指令已发送' }); } catch(e) {}
  }

  getButtonText(): string {
    if (this.isConnecting) return "连接中...";
    if (this.isConnected()) return "断 开";
    return "连 接";
  }

  getButtonColor(): ResourceColor {
    if (this.isConnecting) return '#555555';
    if (this.isConnected()) return '#D32F2F';
    return '#1565C0';
  }

  async handleButtonClick() {
    if (!this.btManager) return;
    if (this.isConnected()) {
      this.btManager.close(this.device.deviceId);
      this.doorState = 0;
      this.lastMessage = '';
      return;
    }
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
        if (cleanData.includes("OPEN")) this.doorState = 1;
        else if (cleanData.includes("CLOSE")) this.doorState = 2;
      });
      setTimeout(() => { this.btManager?.sendCommand(this.device.deviceId, "?"); }, 3000);
    }
  }
}

@Component
export struct IndexPage {
  @StorageLink('HistoryDevices_JSON') historyJson: string = '[]';
  @StorageLink('AppLogs_JSON') logsJson: string = '[]';

  @State historyDevices: SavedDevice[] = [];
  @State newDevices: ScannedDevice[] = [];

  // 【新增】简洁模式状态，默认开启
  @State isConciseMode: boolean = true;

  private btManager = new BluetoothManager();
  private context = getContext(this) as common.UIAbilityContext;
  private scanTimer: number = -1;

  aboutToAppear() {
    try {
      // 只有当 JSON 不为空时才解析，避免覆盖
      if (this.historyJson && this.historyJson !== '[]') {
        this.historyDevices = JSON.parse(this.historyJson);
      }
    } catch(e) {
      console.error('历史记录解析失败', e);
    }
    this.initScan();
  }

  async initScan() {
    let granted = await PermissionManager.requestBluetoothPermission(this.context);
    if (granted) { this.refreshScan(); }
  }

  onPageShow() { this.startScanLoop(); }
  onPageHide() { this.stopScanLoop(); }

  addLog(deviceName: string, content: string, type: 'SEND' | 'RECV') {
    let now = new Date();
    let timeStr = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}`;

    let currentLogs: LogItem[] = [];
    try { currentLogs = JSON.parse(this.logsJson); } catch(e) {}

    let newItem: LogItem = { timestamp: timeStr, deviceName: deviceName, content: content, type: type };
    currentLogs.unshift(newItem);
    if (currentLogs.length > 100) currentLogs = currentLogs.slice(0, 100);

    const newJson = JSON.stringify(currentLogs);
    // 1. 更新 UI (内存)
    this.logsJson = newJson;
    // 2. 【核心】更新磁盘
    PreferencesUtil.put('AppLogs_JSON', newJson);
  }

  startScanLoop() {
    this.stopScanLoop();
    this.refreshScan();
    this.scanTimer = setInterval(() => { this.refreshScan(); }, 5000);
  }

  stopScanLoop() {
    if (this.scanTimer !== -1) { clearInterval(this.scanTimer); this.scanTimer = -1; }
    this.btManager.stopScan();
  }

  refreshScan() {
    // 这里不清空 historyDevices，只刷新新设备
    this.newDevices = [];
    this.btManager.startScan((device: ScannedDevice) => {
      let isHistory = this.historyDevices.some((d: SavedDevice) => d.deviceId === device.deviceId);
      if (!isHistory) {
        let exists = this.newDevices.some((d: ScannedDevice) => d.deviceId === device.deviceId);
        if (!exists) this.newDevices.push(device);
      }
    });
  }

  handleConnectSuccess(device: ScannedDevice) {
    let list = this.historyDevices.filter((d: SavedDevice) => d.deviceId !== device.deviceId);
    list.unshift({ deviceId: device.deviceId, deviceName: device.deviceName });

    this.historyDevices = list;
    const newJson = JSON.stringify(list);

    // 1. 更新 UI (内存)
    this.historyJson = newJson;
    // 2. 【核心】更新磁盘
    PreferencesUtil.put('HistoryDevices_JSON', newJson);

    this.newDevices = this.newDevices.filter((d: ScannedDevice) => d.deviceId !== device.deviceId);
  }

  // 【新增】获取过滤后的新设备列表
  getFilteredNewDevices(): ScannedDevice[] {
    if (!this.isConciseMode) {
      return this.newDevices; // 全部显示
    }
    // 简洁模式：过滤掉名字为空 或 名字叫 "未知设备" 的
    return this.newDevices.filter(item => {
      return item.deviceName && item.deviceName !== '未知设备' && item.deviceName.trim() !== '';
    });
  }

  build() {
    Column() {
      Text("智能门禁")
        .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width('100%').padding({ left: 20, top: 20, bottom: 10 })

      List() {
        // 1. 历史设备 (始终显示)
        if (this.historyDevices.length > 0) {
          ListItem() {
            Text("已配对设备").fontSize(14).fontColor('#888888').margin({ bottom: 8, left: 5 })
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

        // 2. 新发现设备标题栏 (带刷新和简洁模式开关)
        ListItem() {
          Row() {
            Text("新发现设备").fontSize(14).fontColor('#888888')
            Blank()

            // 【新增】简洁模式按钮
            Row() {
              Text(this.isConciseMode ? "简洁模式:开" : "简洁模式:关")
                .fontSize(12).fontColor(this.isConciseMode ? '#4CAF50' : '#666666')
                .margin({ right: 15 })
                .onClick(() => { this.isConciseMode = !this.isConciseMode }) // 切换模式

              Text("刷新").fontSize(14).fontColor('#448AFF')
                .onClick(() => { this.refreshScan() })
            }
          }
          .width('100%').padding({ left: 5, right: 5, top: 10, bottom: 8 })
        }

        // 3. 列表为空提示
        if (this.getFilteredNewDevices().length === 0) {
          ListItem() {
            Text(this.isConciseMode ? "正在扫描 (已隐藏未知设备)..." : "正在扫描附近设备...")
              .fontSize(14).fontColor('#666666').width('100%').textAlign(TextAlign.Center).padding(20)
          }
        }

        // 4. 渲染过滤后的列表
        ForEach(this.getFilteredNewDevices(), (item: ScannedDevice) => {
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
    .width('100%').height('100%')
    .backgroundColor('#111111')
  }
}