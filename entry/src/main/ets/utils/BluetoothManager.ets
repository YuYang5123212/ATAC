import { ble, constant, access } from '@kit.ConnectivityKit';
import { promptAction } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';

export interface ScannedDevice {
  deviceId: string;
  deviceName: string;
  rssi: number;
}

export class BluetoothManager {
  // 目标 UUID (小写)
  private serviceUUID: string = '0000ffe0-0000-1000-8000-00805f9b34fb';
  private characteristicUUID: string = '0000ffe1-0000-1000-8000-00805f9b34fb';

  private connectedClients: Map<string, ble.GattClientDevice> = new Map();
  // 缓存系统返回的真实特征值对象
  private deviceCharacteristics: Map<string, ble.BLECharacteristic> = new Map();

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

    try { promptAction.showToast({ message: '正在连接...' }); } catch(e) {}

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
              // 延时等待连接稳定
              setTimeout(async () => {
                await this.discoverServices(deviceId, client, resolve);
              }, 1500);
            }
          } else if (state.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
            this.connectedClients.delete(deviceId);
            this.deviceCharacteristics.delete(deviceId);
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

      // 策略1：寻找服务
      let targetService = services.find(s => s.serviceUuid.toLowerCase() === this.serviceUUID.toLowerCase());
      if (!targetService) {
        targetService = services.find(s => s.serviceUuid.toLowerCase().includes("ffe0"));
      }
      // 兜底：使用第一个服务
      if (!targetService && services.length > 0) {
        targetService = services[0];
      }

      if (!targetService) {
        try { promptAction.showToast({ message: '无法识别服务' }); } catch(e) {}
        resolve(true);
        return;
      }

      let targetChar: ble.BLECharacteristic | undefined;

      // 策略2：寻找特征值
      targetChar = targetService.characteristics.find(c => c.characteristicUuid.toLowerCase() === this.characteristicUUID.toLowerCase());

      if (!targetChar) {
        targetChar = targetService.characteristics.find(c => c.characteristicUuid.toLowerCase().includes("ffe1"));
      }

      // 策略3：自动抓取第一个可写特征值 (【修复】增加 properties 空检查)
      if (!targetChar) {
        targetChar = targetService.characteristics.find(c => {
          if (!c.properties) return false; // 严谨的空检查
          return (c.properties.write || c.properties.writeNoResponse);
        });
      }

      if (!targetChar) {
        try { promptAction.showToast({ message: '未找到可写特征值' }); } catch(e) {}
        resolve(true);
        return;
      }

      // 缓存真实对象
      this.deviceCharacteristics.set(deviceId, targetChar);
      try { promptAction.showToast({ message: '控制已就绪' }); } catch(e) {}

      // 开启通知
      await this.enableNotification(deviceId, client, targetChar);
      resolve(true);

    } catch (err) {
      console.error("服务发现异常: " + JSON.stringify(err));
      resolve(false);
    }
  }

  private async enableNotification(deviceId: string, client: ble.GattClientDevice, targetChar: ble.BLECharacteristic) {
    try {
      client.on('BLECharacteristicChange', (characteristicChange) => {
        let value = new Uint8Array(characteristicChange.characteristicValue);
        let str = util.TextDecoder.create("utf-8", { ignoreBOM: true }).decodeToString(value);
        console.info(`[RECV] ${deviceId}: ${str}`);
        let callback = this.dataCallbacks.get(deviceId);
        if (callback) callback(str);
      });

      // 【修复】增加 properties 空检查，解决编译报错
      let canNotify = false;
      if (targetChar.properties) {
        if (targetChar.properties.notify || targetChar.properties.indicate) {
          canNotify = true;
        }
      }

      if (canNotify) {
        await client.setCharacteristicChangeNotification(targetChar, true);
        console.info("通知监听已开启");
      }
    } catch (err) {
      console.error("开启通知失败: " + JSON.stringify(err));
    }
  }

  public async sendCommand(deviceId: string, cmd: string) {
    let client = this.connectedClients.get(deviceId);
    let targetChar = this.deviceCharacteristics.get(deviceId);

    if (!client || !targetChar) {
      try { promptAction.showToast({ message: '设备未就绪' }); } catch(e) {}
      return;
    }

    let buffer = new ArrayBuffer(cmd.length);
    let dataView = new DataView(buffer);
    for (let i = 0; i < cmd.length; i++) dataView.setUint8(i, cmd.charCodeAt(i));

    // 直接修改缓存对象的 value
    targetChar.characteristicValue = buffer;

    try {
      await client.writeCharacteristicValue(targetChar, ble.GattWriteType.WRITE);
      console.info(`发送成功: ${cmd}`);
    } catch (err) {
      try {
        await client.writeCharacteristicValue(targetChar, ble.GattWriteType.WRITE_NO_RESPONSE);
        console.info(`发送成功(无响应): ${cmd}`);
      } catch(e2) {
        console.error(`发送失败: ${JSON.stringify(e2)}`);
      }
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
      this.deviceCharacteristics.delete(deviceId);
      this.dataCallbacks.delete(deviceId);
      this.updateConnectedList();
    }
  }
}