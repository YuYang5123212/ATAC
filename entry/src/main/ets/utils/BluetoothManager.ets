import { access, connection, socket } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';

// 定义扫描到的设备数据结构
export interface ScannedDevice {
  deviceId: string;
  deviceName: string;
}

export class BluetoothManager {
  private clientSocketID: number = -1;
  // 经典蓝牙 SPP UUID
  private uuid: string = "00001101-0000-1000-8000-00805F9B34FB";

  // 回调函数：当扫描到设备时通知 UI
  private onDeviceFoundCallback?: (device: ScannedDevice) => void;

  /**
   * 1. 启动扫描
   * @param callback 发现设备时的回调函数
   */
  public startScan(callback: (device: ScannedDevice) => void) {
    if (access.getState() !== access.BluetoothState.STATE_ON) {
      promptAction.showToast({ message: '请先开启蓝牙' });
      return;
    }

    this.onDeviceFoundCallback = callback;

    try {
      // 监听设备发现事件
      connection.on('bluetoothDeviceFind', (data: Array<string>) => {
        data.forEach(deviceId => {
          // 获取设备名称，如果获取失败显示默认名
          let name = connection.getRemoteDeviceName(deviceId) || "未知设备";

          // 过滤逻辑：只返回名字包含 HC-05 或 第八组 的设备
          // 如果你需要看所有设备，可以注释掉下面这行
          if (name.includes("HC-05") || name.includes("第八组")) {
            if (this.onDeviceFoundCallback) {
              this.onDeviceFoundCallback({ deviceId: deviceId, deviceName: name });
            }
          }
        });
      });

      // 开始扫描
      connection.startBluetoothDiscovery();
      promptAction.showToast({ message: '开始扫描...' });
      console.info('蓝牙扫描已启动');
    } catch (err) {
      console.error('扫描启动失败: ' + JSON.stringify(err));
    }
  }

  /**
   * 2. 停止扫描 (连接前必须调用)
   */
  public stopScan() {
    try {
      connection.stopBluetoothDiscovery();
      connection.off('bluetoothDeviceFind');
    } catch (err) {
      console.error('停止扫描异常');
    }
  }

  /**
   * 3. 连接指定 MAC 地址的设备
   */
  public async connect(deviceId: string): Promise<boolean> {
    this.stopScan(); // 必须先停止扫描

    // 如果已有连接，先断开
    if (this.clientSocketID !== -1) {
      this.close();
    }

    // 配置连接选项
    let sppOption: socket.SppOptions = {
      uuid: this.uuid,
      secure: false, // 【关键】设置为 false，模仿蓝牙调试器的非安全连接，绕过系统配对
      type: 0
    };

    promptAction.showToast({ message: '正在连接...' });

    return new Promise((resolve) => {
      socket.sppConnect(deviceId, sppOption, (err: BusinessError, socketID: number) => {
        if (err) {
          console.error(`连接失败 Code: ${err.code}, Message: ${err.message}`);
          promptAction.showToast({ message: '连接失败，请检查设备是否开启' });
          resolve(false);
          return;
        }

        console.info(`连接成功 SocketID: ${socketID}`);
        this.clientSocketID = socketID;
        promptAction.showToast({ message: '连接成功！' });

        // 连接成功后启动数据监听
        this.listenForData();
        resolve(true);
      });
    });
  }

  // 4. 发送指令 (已适配 Arduino 的单字符协议)
  public sendCommand(cmd: string) {
    if (this.clientSocketID === -1) {
      promptAction.showToast({ message: '蓝牙未连接' });
      return;
    }
    try {
      let buffer = new ArrayBuffer(cmd.length);
      let dataView = new DataView(buffer);
      for (let i = 0; i < cmd.length; i++) {
        dataView.setUint8(i, cmd.charCodeAt(i));
      }
      socket.sppWrite(this.clientSocketID, new Uint8Array(buffer).buffer);
      console.info('发送指令: ' + cmd);
    } catch (err) {
      console.error('发送失败: ' + JSON.stringify(err));
    }
  }

  // 快捷指令
  public openDoor() { this.sendCommand("1"); }
  public closeDoor() { this.sendCommand("0"); }
  public checkStatus() { this.sendCommand("?"); }

  // 5. 监听数据
  private listenForData() {
    if (this.clientSocketID === -1) return;
    socket.on('sppRead', this.clientSocketID, (dataBuffer: ArrayBuffer) => {
      let textDecoder = util.TextDecoder.create("utf-8", { ignoreBOM: true });
      let str = textDecoder.decodeToString(new Uint8Array(dataBuffer));
      console.info("收到 Arduino 数据: " + str);
    });
  }

  // 6. 断开连接
  public close() {
    if (this.clientSocketID !== -1) {
      try {
        socket.sppCloseClientSocket(this.clientSocketID);
        socket.off('sppRead', this.clientSocketID);
      } catch (e) {}
      this.clientSocketID = -1;
      promptAction.showToast({ message: '连接已断开' });
    }
  }
}