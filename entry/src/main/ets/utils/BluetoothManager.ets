import { access, connection, socket } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';

export interface ScannedDevice {
  deviceId: string;
  deviceName: string;
}

export class BluetoothManager {
  private clientSocketID: number = -1;
  // 经典蓝牙 SPP UUID
  private uuid: string = "00001101-0000-1000-8000-00805F9B34FB";

  private onDeviceFoundCallback?: (device: ScannedDevice) => void;

  /**
   * 1. 启动扫描
   */
  public startScan(callback: (device: ScannedDevice) => void) {
    // 检查蓝牙开关
    try {
      let state = access.getState();
      if (state !== access.BluetoothState.STATE_ON) {
        promptAction.showToast({ message: '请先开启蓝牙' });
        return;
      }
    } catch (err) {
      console.error('获取蓝牙状态失败');
    }

    this.onDeviceFoundCallback = callback;

    try {
      // 监听设备发现事件
      connection.on('bluetoothDeviceFind', (data: Array<string>) => {
        data.forEach(deviceId => {
          // 尝试获取名称，如果为空则显示 MAC 地址
          let name = "未知设备";
          try {
            let remoteName = connection.getRemoteDeviceName(deviceId);
            if (remoteName && remoteName.length > 0) {
              name = remoteName;
            }
          } catch (e) {
            console.warn('获取设备名异常: ' + deviceId);
          }

          console.info(`[扫描发现] MAC: ${deviceId}, Name: ${name}`);

          // 【核心修正】: 移除过滤逻辑，显示所有设备，防止因名字为空被过滤
          if (this.onDeviceFoundCallback) {
            this.onDeviceFoundCallback({ deviceId: deviceId, deviceName: name });
          }
        });
      });

      // 开始扫描
      connection.startBluetoothDiscovery();
      promptAction.showToast({ message: '开始扫描...' });

    } catch (err) {
      console.error('扫描启动失败: ' + JSON.stringify(err));
      promptAction.showToast({ message: '扫描启动异常' });
    }
  }

  /**
   * 2. 停止扫描
   */
  public stopScan() {
    try {
      connection.stopBluetoothDiscovery();
      connection.off('bluetoothDeviceFind');
      console.info('停止扫描');
    } catch (err) {
      console.error('停止扫描异常');
    }
  }

  /**
   * 3. 连接指定 MAC
   */
  public async connect(deviceId: string): Promise<boolean> {
    this.stopScan();

    if (this.clientSocketID !== -1) {
      this.close();
    }

    let sppOption: socket.SppOptions = {
      uuid: '00001101-0000-1000-8000-00805F9B34FB',
      secure: false, // 保持非安全连接
      type: 0
    };

    try {
      promptAction.showToast({ message: '正在连接...' });
    } catch (e) {}

    return new Promise((resolve) => {
      try {
        socket.sppConnect(deviceId, sppOption, (err: BusinessError, socketID: number) => {
          if (err) {
            console.error(`连接失败 Code: ${err.code}`);
            try { promptAction.showToast({ message: `连接失败: ${err.code}` }); } catch(e){}
            resolve(false);
            return;
          }

          console.info(`连接成功 SocketID: ${socketID}`);
          this.clientSocketID = socketID;
          try { promptAction.showToast({ message: '连接成功！' }); } catch(e){}

          this.listenForData();
          resolve(true);
        });
      } catch (err) {
        console.error('Socket连接调用异常');
        resolve(false);
      }
    });
  }

  // 4. 发送指令
  public sendCommand(cmd: string) {
    if (this.clientSocketID === -1) {
      try { promptAction.showToast({ message: '蓝牙未连接' }); } catch(e){}
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

  public openDoor() { this.sendCommand("1"); }
  public closeDoor() { this.sendCommand("0"); }
  public checkStatus() { this.sendCommand("?"); }

  // 5. 监听数据
  private listenForData() {
    if (this.clientSocketID === -1) return;
    try {
      socket.on('sppRead', this.clientSocketID, (dataBuffer: ArrayBuffer) => {
        let textDecoder = util.TextDecoder.create("utf-8", { ignoreBOM: true });
        let str = textDecoder.decodeToString(new Uint8Array(dataBuffer));
        console.info("收到 Arduino 数据: " + str);
      });
    } catch (e) {
      console.error("监听失败");
    }
  }

  // 6. 断开连接
  public close() {
    if (this.clientSocketID !== -1) {
      try {
        socket.sppCloseClientSocket(this.clientSocketID);
        socket.off('sppRead', this.clientSocketID);
      } catch (e) {}
      this.clientSocketID = -1;
      try { promptAction.showToast({ message: '已断开' }); } catch(e){}
    }
  }
}