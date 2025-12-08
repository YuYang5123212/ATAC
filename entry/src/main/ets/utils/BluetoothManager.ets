import { ble, constant, access } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
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

  private gattClient: ble.GattClientDevice | null = null;
  private onDeviceFoundCallback?: (device: ScannedDevice) => void;

  // 1. 开始 BLE 扫描
  public startScan(callback: (device: ScannedDevice) => void) {
    try {
      if (access.getState() !== access.BluetoothState.STATE_ON) {
        return;
      }
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
      // 允许重复上报
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

  // 2. 连接 BLE 设备
  public async connect(deviceId: string): Promise<boolean> {
    this.stopScan();
    if (this.gattClient) this.close();

    try { promptAction.showToast({ message: '正在连接...' }); } catch(e) {}

    try {
      this.gattClient = ble.createGattClientDevice(deviceId);
    } catch(err) {
      return false;
    }

    return new Promise((resolve) => {
      if (!this.gattClient) { resolve(false); return; }

      try {
        this.gattClient.on('BLEConnectionStateChange', async (state) => {
          console.info('BLE状态: ' + state.state);

          if (state.state === constant.ProfileConnectionState.STATE_CONNECTED) {
            AppStorage.setOrCreate('CurrentConnectedID', deviceId);

            setTimeout(async () => {
              await this.discoverServices(resolve);
            }, 2500);

          } else if (state.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
            AppStorage.setOrCreate('CurrentConnectedID', '');
            try { promptAction.showToast({ message: '连接已断开' }); } catch(e) {}
            this.close();
          }
        });

        this.gattClient.connect();
      } catch (err) {
        resolve(false);
      }
    });
  }

  private async discoverServices(resolve: (value: boolean) => void) {
    if (!this.gattClient) return;
    try {
      let services = await this.gattClient.getServices();
      let targetService = services.find(s => s.serviceUuid === this.serviceUUID);
      if (!targetService) {
        // 没找到服务也当作成功，允许重试
        resolve(true);
        return;
      }
      try { promptAction.showToast({ message: '已连接，设备就绪' }); } catch(e) {}
      await this.enableNotification();
      resolve(true);
    } catch (err) {
      resolve(false);
    }
  }

  private async enableNotification() {
    if (!this.gattClient) return;
    try {
      this.gattClient.on('BLECharacteristicChange', (characteristicChange) => {
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
      await this.gattClient.setCharacteristicChangeNotification(notifyChar, true);
    } catch (err) {}
  }

  public async sendCommand(cmd: string) {
    if (!this.gattClient) {
      try { promptAction.showToast({ message: '蓝牙未连接' }); } catch(e) {}
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
      await this.gattClient.writeCharacteristicValue(writeChar, ble.GattWriteType.WRITE);
    } catch (err) {
      try {
        await this.gattClient.writeCharacteristicValue(writeChar, ble.GattWriteType.WRITE_NO_RESPONSE);
      } catch(e2) {}
    }
  }

  public openDoor() { this.sendCommand("1"); }
  public closeDoor() { this.sendCommand("0"); }
  public checkStatus() { this.sendCommand("?"); }

  public close() {
    if (this.gattClient) {
      try {
        this.gattClient.off('BLEConnectionStateChange');
        this.gattClient.disconnect();
        this.gattClient.close();
      } catch (e) {}
      this.gattClient = null;
      AppStorage.setOrCreate('CurrentConnectedID', '');
    }
  }
}