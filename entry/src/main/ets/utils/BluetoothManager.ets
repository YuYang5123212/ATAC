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
  // 根据你截图确认的 UUID
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
      try { promptAction.showToast({ message: '扫描中...' }); } catch(e) {}
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

  /**
   * 2. 连接 BLE 设备
   */
  public async connect(deviceId: string): Promise<boolean> {
    this.stopScan();

    if (this.gattClient) {
      this.close();
    }

    try { promptAction.showToast({ message: '正在连接...' }); } catch(e) {}

    try {
      this.gattClient = ble.createGattClientDevice(deviceId);
    } catch(err) {
      console.error('创建GATT失败:' + err);
      return false;
    }

    return new Promise((resolve) => {
      if (!this.gattClient) {
        resolve(false);
        return;
      }

      try {
        this.gattClient.on('BLEConnectionStateChange', async (state) => {
          console.info('BLE状态: ' + state.state);

          if (state.state === constant.ProfileConnectionState.STATE_CONNECTED) {
            console.info('BLE 已连接，等待配对完成...');
            try { promptAction.showToast({ message: '已连接，请留意配对弹窗' }); } catch(e) {}

            // 【核心修改1】：将延时增加到 2500ms
            // 给系统足够的时间弹出配对框并完成加密，否则获取服务会失败
            setTimeout(async () => {
              await this.discoverServices(resolve);
            }, 2500);

          } else if (state.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
            console.warn('BLE 已断开');
            try { promptAction.showToast({ message: '设备已断开' }); } catch(e) {}
            this.close();
          }
        });

        this.gattClient.connect();
      } catch (err) {
        console.error('连接异常: ' + JSON.stringify(err));
        resolve(false);
      }
    });
  }

  private async discoverServices(resolve: (value: boolean) => void) {
    if (!this.gattClient) return;

    try {
      console.info('开始搜索服务...');
      let services = await this.gattClient.getServices();

      // 打印查找到的所有服务，方便调试
      services.forEach(s => console.info(`发现服务 UUID: ${s.serviceUuid}`));

      let targetService = services.find(s => s.serviceUuid === this.serviceUUID);

      if (!targetService) {
        try { promptAction.showToast({ message: '未找到服务 FFE0，请重试' }); } catch(e) {}
        console.error('服务搜索失败或未匹配');
        // 不要 resolve(false)，保持连接让用户重试，或者自动重试
        resolve(true);
        return;
      }

      try { promptAction.showToast({ message: '服务就绪，可以控制了！' }); } catch(e) {}
      await this.enableNotification();
      resolve(true);

    } catch (err) {
      console.error('获取服务异常: ' + JSON.stringify(err));
      // 常见错误：GATT 133 或 128，通常是因为配对没完成就调用了getServices
      try { promptAction.showToast({ message: '服务获取受阻，请重连' }); } catch(e) {}
      resolve(false);
    }
  }

  private async enableNotification() {
    if (!this.gattClient) return;

    try {
      this.gattClient.on('BLECharacteristicChange', (characteristicChange) => {
        let value = new Uint8Array(characteristicChange.characteristicValue);
        let textDecoder = util.TextDecoder.create("utf-8", { ignoreBOM: true });
        let str = textDecoder.decodeToString(value);
        console.info("收到回复: " + str);
        try { promptAction.showToast({ message: '收到: ' + str }); } catch(e) {}
      });

      let notifyChar: ble.BLECharacteristic = {
        serviceUuid: this.serviceUUID,
        characteristicUuid: this.characteristicUUID,
        characteristicValue: new ArrayBuffer(0),
        descriptors: []
      };

      await this.gattClient.setCharacteristicChangeNotification(notifyChar, true);
    } catch (err) {
      console.error('通知启用失败 (不影响发送): ' + JSON.stringify(err));
    }
  }

  /**
   * 4. 发送指令
   */
  public async sendCommand(cmd: string) {
    if (!this.gattClient) {
      try { promptAction.showToast({ message: '蓝牙未连接' }); } catch(e) {}
      return;
    }

    let buffer = new ArrayBuffer(cmd.length);
    let dataView = new DataView(buffer);
    for (let i = 0; i < cmd.length; i++) {
      dataView.setUint8(i, cmd.charCodeAt(i));
    }

    let writeChar: ble.BLECharacteristic = {
      serviceUuid: this.serviceUUID,
      characteristicUuid: this.characteristicUUID,
      characteristicValue: buffer,
      descriptors: []
    };

    try {
      // 【核心修改2】：改为 WRITE (带响应写入)
      // 很多克隆模块不支持 WRITE_NO_RESPONSE，会导致静默失败
      await this.gattClient.writeCharacteristicValue(writeChar, ble.GattWriteType.WRITE);
      console.info('指令已发送: ' + cmd);
      // try { promptAction.showToast({ message: '发送成功: ' + cmd }); } catch(e) {}
    } catch (err) {
      console.error('发送失败: ' + JSON.stringify(err));

      // 如果 WRITE 失败，尝试 fallback 到 WRITE_NO_RESPONSE
      console.info('尝试无响应写入模式...');
      try {
        await this.gattClient.writeCharacteristicValue(writeChar, ble.GattWriteType.WRITE_NO_RESPONSE);
      } catch(e2) {
        try { promptAction.showToast({ message: '发送完全失败' }); } catch(e) {}
      }
    }
  }

  public openDoor() { this.sendCommand("1"); }
  public closeDoor() { this.sendCommand("0"); }
  public checkStatus() { this.sendCommand("?"); }

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