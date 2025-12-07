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
  // 【关键配置】根据你的截图填写的 BLE UUID
  // 服务 UUID (0000ffe0...)
  private serviceUUID: string = '0000ffe0-0000-1000-8000-00805f9b34fb';
  // 特征值 UUID (0000ffe1...) 用于发送和接收
  private characteristicUUID: string = '0000ffe1-0000-1000-8000-00805f9b34fb';

  private gattClient: ble.GattClientDevice | null = null;
  private onDeviceFoundCallback?: (device: ScannedDevice) => void;

  /**
   * 1. 开始 BLE 扫描
   */
  public startScan(callback: (device: ScannedDevice) => void) {
    if (access.getState() !== access.BluetoothState.STATE_ON) {
      promptAction.showToast({ message: '请先开启蓝牙' });
      return;
    }

    this.onDeviceFoundCallback = callback;

    try {
      // 监听 BLE 设备发现事件
      ble.on('BLEDeviceFind', (data: Array<ble.ScanResult>) => {
        data.forEach(result => {
          let deviceName = result.deviceName || "未知设备";
          let deviceId = result.deviceId; // MAC地址

          // 你的设备 MAC 是 74:0B... 或 B6:39...
          // 这里我们不过滤，全部把结果传出去，你在 UI 层看哪个是你
          if (this.onDeviceFoundCallback) {
            this.onDeviceFoundCallback({
              deviceId: deviceId,
              deviceName: deviceName,
              rssi: result.rssi
            });
          }
        });
      });

      // 开始扫描 (允许后台扫描)
      ble.startBLEScan(null); // null 表示不设置过滤器，扫所有
      promptAction.showToast({ message: '开始 BLE 扫描...' });
      console.info('BLE 扫描已启动');

    } catch (err) {
      console.error('BLE 扫描启动失败: ' + JSON.stringify(err));
      promptAction.showToast({ message: '扫描启动失败' });
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
   * 3. 连接 BLE 设备 (核心逻辑)
   */
  public async connect(deviceId: string): Promise<boolean> {
    this.stopScan(); // 连接前停止扫描

    // 如果已有连接，先断开
    if (this.gattClient) {
      this.close();
    }

    promptAction.showToast({ message: '正在连接 BLE...' });

    // 创建 GATT 客户端
    this.gattClient = ble.createGattClientDevice(deviceId);

    return new Promise((resolve) => {
      if (!this.gattClient) {
        resolve(false);
        return;
      }

      // 监听连接状态变化
      this.gattClient.on('BLEConnectionStateChange', async (state) => {
        console.info('连接状态变化: ' + state.state);

        if (state.state === constant.ProfileConnectionState.STATE_CONNECTED) {
          console.info('BLE 已连接，正在获取服务...');

          // 连接成功后，必须设置 MTU 和 获取服务
          // 稍微延迟一下确保稳定
          setTimeout(async () => {
            await this.discoverServices(resolve);
          }, 500);

        } else if (state.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
          console.warn('BLE 已断开');
          this.close();
        }
      });

      // 发起连接
      try {
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
      // 获取服务列表
      let services = await this.gattClient.getServices();
      let targetService = services.find(s => s.serviceUuid === this.serviceUUID);

      if (!targetService) {
        promptAction.showToast({ message: '未找到透传服务 FFE0' });
        console.error('未找到 UUID 为 ' + this.serviceUUID + ' 的服务');
        resolve(false);
        return;
      }

      console.info('找到服务，正在启用通知...');
      promptAction.showToast({ message: '连接成功，正在握手...' });

      // 启用通知 (接收 Arduino 发来的数据)
      await this.enableNotification();

      resolve(true); // 连接流程全部完成

    } catch (err) {
      console.error('获取服务失败: ' + JSON.stringify(err));
      promptAction.showToast({ message: '获取服务失败' });
      resolve(false);
    }
  }

  // 启用特征值通知
  private async enableNotification() {
    if (!this.gattClient) return;

    // 1. 设置特征值变化监听
    this.gattClient.on('BLECharacteristicChange', (characteristicChange) => {
      let value = new Uint8Array(characteristicChange.characteristicValue);
      let textDecoder = util.TextDecoder.create("utf-8", { ignoreBOM: true });
      let str = textDecoder.decodeToString(value);
      console.info("收到 Arduino 数据: " + str);
    });

    // 2. 向系统申请开启通知
    let notifyChar: ble.BLECharacteristic = {
      serviceUuid: this.serviceUUID,
      characteristicUuid: this.characteristicUUID,
      characteristicValue: new ArrayBuffer(0),
      isSigned: false
    };

    try {
      await this.gattClient.setCharacteristicChangeNotification(notifyChar, true);
      console.info('通知已启用');
    } catch (err) {
      console.error('启用通知失败: ' + JSON.stringify(err));
    }
  }

  /**
   * 4. 发送指令 (BLE 写特征值)
   */
  public async sendCommand(cmd: string) {
    if (!this.gattClient) {
      promptAction.showToast({ message: '未连接' });
      return;
    }

    // 转换字符串为 buffer
    let buffer = new ArrayBuffer(cmd.length);
    let dataView = new DataView(buffer);
    for (let i = 0; i < cmd.length; i++) {
      dataView.setUint8(i, cmd.charCodeAt(i));
    }

    let writeChar: ble.BLECharacteristic = {
      serviceUuid: this.serviceUUID,
      characteristicUuid: this.characteristicUUID,
      characteristicValue: buffer,
      isSigned: false // 通常不需要签名
    };

    try {
      // 大部分透传模块使用 writeWithoutResponse (提升速度)
      // 如果发不出去，可以试着把 true 改为 false (即带响应的写入)
      await this.gattClient.writeCharacteristicValue(writeChar, ble.GattWriteType.WRITE_NO_RESPONSE);
      console.info('指令发送成功: ' + cmd);
    } catch (err) {
      console.error('发送失败: ' + JSON.stringify(err));
      promptAction.showToast({ message: '发送失败' });
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
        this.gattClient.disconnect(); // 断开
        this.gattClient.close(); // 释放资源
      } catch (e) {}
      this.gattClient = null;
      promptAction.showToast({ message: '已断开' });
    }
  }
}