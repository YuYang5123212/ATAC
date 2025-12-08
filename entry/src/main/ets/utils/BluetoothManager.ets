import { ble, constant, access } from '@kit.ConnectivityKit';
import { promptAction } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';

export interface ScannedDevice {
  deviceId: string;
  deviceName: string;
  rssi: number;
}

export class BluetoothManager {
  private serviceUUID: string = '0000ffe0-0000-1000-8000-00805f9b34fb';
  private characteristicUUID: string = '0000ffe1-0000-1000-8000-00805f9b34fb';

  // 【核心变更】使用 Map 存储多个连接对象 <MAC地址, Client>
  private connectedClients: Map<string, ble.GattClientDevice> = new Map();

  private onDeviceFoundCallback?: (device: ScannedDevice) => void;

  // 初始化全局连接列表状态
  constructor() {
    AppStorage.setOrCreate('ConnectedIDs', []);
  }

  // 1. 扫描逻辑 (保持不变)
  public startScan(callback: (device: ScannedDevice) => void) {
    try {
      if (access.getState() !== access.BluetoothState.STATE_ON) return;
    } catch (err) {}

    this.onDeviceFoundCallback = callback;

    try {
      ble.on('BLEDeviceFind', (data: Array<ble.ScanResult>) => {
        data.forEach(result => {
          let deviceName = result.deviceName || "未知设备";
          if (this.onDeviceFoundCallback) {
            this.onDeviceFoundCallback({
              deviceId: result.deviceId,
              deviceName: deviceName,
              rssi: result.rssi
            });
          }
        });
      });
      ble.startBLEScan(null);
    } catch (err) {
      console.error('BLE 扫描启动失败: ' + JSON.stringify(err));
    }
  }

  public stopScan() {
    try {
      ble.stopBLEScan();
      ble.off('BLEDeviceFind');
    } catch (err) {}
  }

  // 2. 连接指定设备 (支持多连)
  public async connect(deviceId: string): Promise<boolean> {
    // 如果该设备已经连接，直接返回成功
    if (this.connectedClients.has(deviceId)) {
      return true;
    }

    // 注意：不再调用 stopScan，因为可能还需要扫描别的设备
    // 也不再关闭其他连接

    try { promptAction.showToast({ message: '正在连接 ' + deviceId }); } catch(e) {}

    let client: ble.GattClientDevice | null = null;
    try {
      client = ble.createGattClientDevice(deviceId);
    } catch(err) {
      return false;
    }

    return new Promise((resolve) => {
      if (!client) { resolve(false); return; }

      try {
        client.on('BLEConnectionStateChange', async (state) => {
          if (state.state === constant.ProfileConnectionState.STATE_CONNECTED) {
            // 【关键】连接成功，存入 Map
            if (client) { // 再次检查非空
              this.connectedClients.set(deviceId, client);
              this.updateConnectedList(); // 更新全局状态

              // 延时获取服务
              setTimeout(async () => {
                await this.discoverServices(client, resolve);
              }, 2500);
            }

          } else if (state.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
            // 断开连接，从 Map 移除
            this.connectedClients.delete(deviceId);
            this.updateConnectedList(); // 更新全局状态

            try { promptAction.showToast({ message: deviceId + ' 已断开' }); } catch(e) {}
            // 清理监听
            try { client?.close(); } catch(e) {}
          }
        });

        client.connect();
      } catch (err) {
        resolve(false);
      }
    });
  }

  // 更新全局 AppStorage，通知 UI 哪些设备在线
  private updateConnectedList() {
    // 将 Map 的 Key 转为数组存入 AppStorage
    let ids = Array.from(this.connectedClients.keys());
    AppStorage.setOrCreate('ConnectedIDs', ids);
  }

  private async discoverServices(client: ble.GattClientDevice | null, resolve: (value: boolean) => void) {
    if (!client) return;
    try {
      let services = await client.getServices();
      let targetService = services.find(s => s.serviceUuid === this.serviceUUID);
      if (!targetService) {
        resolve(true);
        return;
      }
      try { promptAction.showToast({ message: '设备就绪' }); } catch(e) {}
      await this.enableNotification(client);
      resolve(true);
    } catch (err) {
      resolve(false);
    }
  }

  private async enableNotification(client: ble.GattClientDevice) {
    try {
      client.on('BLECharacteristicChange', (characteristicChange) => {
        let value = new Uint8Array(characteristicChange.characteristicValue);
        let str = util.TextDecoder.create("utf-8", { ignoreBOM: true }).decodeToString(value);
        console.info("收到回复: " + str);
      });
      let notifyChar: ble.BLECharacteristic = {
        serviceUuid: this.serviceUUID,
        characteristicUuid: this.characteristicUUID,
        characteristicValue: new ArrayBuffer(0),
        descriptors: []
      };
      await client.setCharacteristicChangeNotification(notifyChar, true);
    } catch (err) {}
  }

  // 【核心变更】发送指令必须指定给谁发
  public async sendCommand(deviceId: string, cmd: string) {
    let client = this.connectedClients.get(deviceId);
    if (!client) {
      try { promptAction.showToast({ message: '该设备未连接' }); } catch(e) {}
      return;
    }

    let buffer = new ArrayBuffer(cmd.length);
    let dataView = new DataView(buffer);
    for (let i = 0; i < cmd.length; i++) dataView.setUint8(i, cmd.charCodeAt(i));

    let writeChar: ble.BLECharacteristic = {
      serviceUuid: this.serviceUUID,
      characteristicUuid: this.characteristicUUID,
      characteristicValue: buffer,
      descriptors: []
    };

    try {
      await client.writeCharacteristicValue(writeChar, ble.GattWriteType.WRITE);
    } catch (err) {
      try {
        await client.writeCharacteristicValue(writeChar, ble.GattWriteType.WRITE_NO_RESPONSE);
      } catch(e2) {}
    }
  }

  // 指定设备断开
  public close(deviceId: string) {
    let client = this.connectedClients.get(deviceId);
    if (client) {
      try {
        client.disconnect();
        client.close();
      } catch(e) {}
      this.connectedClients.delete(deviceId);
      this.updateConnectedList();
    }
  }

  // 断开所有 (可选)
  public closeAll() {
    this.connectedClients.forEach((client) => {
      try { client.disconnect(); client.close(); } catch(e){}
    });
    this.connectedClients.clear();
    this.updateConnectedList();
  }
}