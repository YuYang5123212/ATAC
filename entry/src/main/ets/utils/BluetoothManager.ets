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
  // 根据你截图填写的 BLE UUID
  private serviceUUID: string = '0000ffe0-0000-1000-8000-00805f9b34fb';
  private characteristicUUID: string = '0000ffe1-0000-1000-8000-00805f9b34fb';

  private gattClient: ble.GattClientDevice | null = null;
  private onDeviceFoundCallback?: (device: ScannedDevice) => void;

  /**
   * 1. 开始 BLE 扫描
   */
  public startScan(callback: (device: ScannedDevice) => void) {
    try {
      if (access.getState() !== access.BluetoothState.STATE_ON) {
        try { promptAction.showToast({ message: '请先开启蓝牙' }); } catch(e) {}
        return;
      }
    } catch (err) {
      console.error('获取蓝牙状态失败');
    }

    this.onDeviceFoundCallback = callback;

    try {
      ble.on('BLEDeviceFind', (data: Array<ble.ScanResult>) => {
        data.forEach(result => {
          let deviceName = result.deviceName || "未知设备";
          let deviceId = result.deviceId;

          if (this.onDeviceFoundCallback) {
            this.onDeviceFoundCallback({
              deviceId: deviceId,
              deviceName: deviceName,
              rssi: result.rssi
            });
          }
        });
      });

      ble.startBLEScan(null);
      try { promptAction.showToast({ message: '开始 BLE 扫描...' }); } catch(e) {}
      console.info('BLE 扫描已启动');

    } catch (err) {
      console.error('BLE 扫描启动失败: ' + JSON.stringify(err));
      try { promptAction.showToast({ message: '扫描启动失败' }); } catch(e) {}
    }
  }

  /**
   * 2. 停止扫描
   */
  public stopScan() {
    try {
      ble.stopBLEScan();
      ble.off('BLEDeviceFind');
      console.info('停止 BLE 扫描');
    } catch (err) {}
  }

  /**
   * 3. 连接 BLE 设备
   */
  public async connect(deviceId: string): Promise<boolean> {
    this.stopScan();

    if (this.gattClient) {
      this.close();
    }

    try { promptAction.showToast({ message: '正在连接 BLE...' }); } catch(e) {}

    try {
      this.gattClient = ble.createGattClientDevice(deviceId);
    } catch(err) {
      console.error('创建GATT客户端失败:' + err);
      return false;
    }

    return new Promise((resolve) => {
      if (!this.gattClient) {
        resolve(false);
        return;
      }

      try {
        this.gattClient.on('BLEConnectionStateChange', async (state) => {
          console.info('连接状态变化: ' + state.state);

          if (state.state === constant.ProfileConnectionState.STATE_CONNECTED) {
            console.info('BLE 已连接，准备获取服务...');
            setTimeout(async () => {
              await this.discoverServices(resolve);
            }, 500);

          } else if (state.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
            console.warn('BLE 已断开');
            this.close();
          }
        });

        this.gattClient.connect();
      } catch (err) {
        console.error('发起连接失败: ' + JSON.stringify(err));
        resolve(false);
      }
    });
  }

  // 内部辅助：发现服务并启用通知
  private async discoverServices(resolve: (value: boolean) => void) {
    if (!this.gattClient) return;

    try {
      let services = await this.gattClient.getServices();
      let targetService = services.find(s => s.serviceUuid === this.serviceUUID);

      if (!targetService) {
        try { promptAction.showToast({ message: '未找到透传服务 FFE0' }); } catch(e) {}
        console.error('未找到 UUID 为 ' + this.serviceUUID + ' 的服务');
        resolve(false);
        return;
      }

      try { promptAction.showToast({ message: '连接成功，正在握手...' }); } catch(e) {}
      await this.enableNotification();
      resolve(true);

    } catch (err) {
      console.error('获取服务失败: ' + JSON.stringify(err));
      try { promptAction.showToast({ message: '获取服务失败' }); } catch(e) {}
      resolve(false);
    }
  }

  // 启用特征值通知
  private async enableNotification() {
    if (!this.gattClient) return;

    try {
      this.gattClient.on('BLECharacteristicChange', (characteristicChange) => {
        let value = new Uint8Array(characteristicChange.characteristicValue);
        let textDecoder = util.TextDecoder.create("utf-8", { ignoreBOM: true });
        let str = textDecoder.decodeToString(value);
        console.info("收到 Arduino 数据: " + str);
      });

      // 【核心修复】：添加 descriptors: [] 以满足 strict 类型检查
      let notifyChar: ble.BLECharacteristic = {
        serviceUuid: this.serviceUUID,
        characteristicUuid: this.characteristicUUID,
        characteristicValue: new ArrayBuffer(0),
        descriptors: []
      };

      await this.gattClient.setCharacteristicChangeNotification(notifyChar, true);
      console.info('通知已启用');
    } catch (err) {
      console.error('启用通知失败: ' + JSON.stringify(err));
    }
  }

  /**
   * 4. 发送指令
   */
  public async sendCommand(cmd: string) {
    if (!this.gattClient) {
      try { promptAction.showToast({ message: '未连接' }); } catch(e) {}
      return;
    }

    let buffer = new ArrayBuffer(cmd.length);
    let dataView = new DataView(buffer);
    for (let i = 0; i < cmd.length; i++) {
      dataView.setUint8(i, cmd.charCodeAt(i));
    }

    // 【核心修复】：添加 descriptors: [] 以满足 strict 类型检查
    let writeChar: ble.BLECharacteristic = {
      serviceUuid: this.serviceUUID,
      characteristicUuid: this.characteristicUUID,
      characteristicValue: buffer,
      descriptors: []
    };

    try {
      await this.gattClient.writeCharacteristicValue(writeChar, ble.GattWriteType.WRITE_NO_RESPONSE);
      console.info('指令发送成功: ' + cmd);
    } catch (err) {
      console.error('发送失败: ' + JSON.stringify(err));
      try { promptAction.showToast({ message: '发送失败' }); } catch(e) {}
    }
  }

  public openDoor() { this.sendCommand("1"); }
  public closeDoor() { this.sendCommand("0"); }
  public checkStatus() { this.sendCommand("?"); }

  /**
   * 5. 断开连接
   */
  public close() {
    if (this.gattClient) {
      try {
        this.gattClient.off('BLEConnectionStateChange');
        this.gattClient.off('BLECharacteristicChange');
        this.gattClient.disconnect();
        this.gattClient.close();
      } catch (e) {}
      this.gattClient = null;
      try { promptAction.showToast({ message: '已断开' }); } catch(e) {}
    }
  }
}