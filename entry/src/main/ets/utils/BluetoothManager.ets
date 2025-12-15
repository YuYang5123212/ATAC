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

  private connectedClients: Map<string, ble.GattClientDevice> = new Map();
  private onDeviceFoundCallback?: (device: ScannedDevice) => void;
  private dataCallbacks: Map<string, (data: string) => void> = new Map();

  constructor() {
    AppStorage.setOrCreate('ConnectedIDs', []);
  }

  public setOnDataReceived(deviceId: string, callback: (data: string) => void) {
    this.dataCallbacks.set(deviceId, callback);
  }

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

  public async connect(deviceId: string): Promise<boolean> {
    if (this.connectedClients.has(deviceId)) return true;

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
            if (client) {
              this.connectedClients.set(deviceId, client);
              this.updateConnectedList();
              // 延时一点，确保连接稳定
              setTimeout(async () => {
                await this.discoverServices(deviceId, client, resolve);
              }, 2000);
            }
          } else if (state.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
            this.connectedClients.delete(deviceId);
            this.dataCallbacks.delete(deviceId);
            this.updateConnectedList();
            try { promptAction.showToast({ message: '设备已断开' }); } catch(e) {}
            try { client?.close(); } catch(e) {}
          }
        });
        client.connect();
      } catch (err) {
        resolve(false);
      }
    });
  }

  private updateConnectedList() {
    let ids = Array.from(this.connectedClients.keys());
    AppStorage.setOrCreate('ConnectedIDs', ids);
  }

  private async discoverServices(deviceId: string, client: ble.GattClientDevice | null, resolve: (value: boolean) => void) {
    if (!client) return;
    try {
      let services = await client.getServices();
      // 1. 找到服务
      let targetService = services.find(s => s.serviceUuid === this.serviceUUID);
      if (!targetService) {
        console.warn(`未找到服务 ${this.serviceUUID}`);
        resolve(true);
        return;
      }

      // 2. 找到特征值 (这是最关键的一步，必须用获取到的对象)
      let targetChar = targetService.characteristics.find(c => c.characteristicUuid === this.characteristicUUID);
      if (!targetChar) {
        console.warn(`未找到特征值 ${this.characteristicUUID}`);
        resolve(true);
        return;
      }

      try { promptAction.showToast({ message: '设备就绪' }); } catch(e) {}

      // 3. 传入真实的 characteristic 对象去开启通知
      await this.enableNotification(deviceId, client, targetChar);
      resolve(true);
    } catch (err) {
      console.error("服务发现异常: " + JSON.stringify(err));
      resolve(false);
    }
  }

  private async enableNotification(deviceId: string, client: ble.GattClientDevice, targetChar: ble.BLECharacteristic) {
    try {
      // 1. 设置监听器
      client.on('BLECharacteristicChange', (characteristicChange) => {
        let value = new Uint8Array(characteristicChange.characteristicValue);
        let str = util.TextDecoder.create("utf-8", { ignoreBOM: true }).decodeToString(value);
        console.info(`[RECV] ${deviceId}: ${str}`); // 在日志里也能看到

        let callback = this.dataCallbacks.get(deviceId);
        if (callback) {
          callback(str);
        }
      });

      // 2. 开启通知 (使用从服务中获取的真实对象)
      await client.setCharacteristicChangeNotification(targetChar, true);
      console.info("通知已开启: " + deviceId);

    } catch (err) {
      console.error("开启通知失败: " + JSON.stringify(err));
    }
  }

  public async sendCommand(deviceId: string, cmd: string) {
    let client = this.connectedClients.get(deviceId);
    if (!client) {
      try { promptAction.showToast({ message: '该设备未连接' }); } catch(e) {}
      return;
    }

    let buffer = new ArrayBuffer(cmd.length);
    let dataView = new DataView(buffer);
    for (let i = 0; i < cmd.length; i++) dataView.setUint8(i, cmd.charCodeAt(i));

    // 发送时也重新构造一个简单的对象即可，或者也可以缓存之前的 targetChar
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

  public close(deviceId: string) {
    let client = this.connectedClients.get(deviceId);
    if (client) {
      try {
        client.disconnect();
        client.close();
      } catch(e) {}
      this.connectedClients.delete(deviceId);
      this.dataCallbacks.delete(deviceId);
      this.updateConnectedList();
    }
  }
}