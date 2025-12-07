import { access, connection, socket } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';

export class BluetoothManager {
  private clientSocketID: number = -1;

  // 【修正1】HC-05 必须使用标准 SPP UUID，不能用 BLE 的 FFE1
  private uuid: string = "0000ffe1-0000-1000-8000-00805F9B34FB";

  // 1. 连接逻辑
  public async connectToHC05(): Promise<boolean> {
    if (this.clientSocketID !== -1) {
      promptAction.showToast({ message: '设备已连接' });
      return true;
    }

    try {
      // 检查蓝牙状态
      let state = access.getState();
      if (state !== access.BluetoothState.STATE_ON) {
        promptAction.showToast({ message: '请先在系统设置中开启蓝牙' });
        return false;
      }

      // 获取配对设备
      let pairedDevices: Array<string> = connection.getPairedDevices();
      let targetMac = "";

      console.info("已配对设备数量: " + pairedDevices.length);

      if (pairedDevices.length > 0) {
        // 建议：实际开发中最好遍历 pairedDevices，让用户选择，这里暂取第一个
        targetMac = pairedDevices[0];
        console.info(`尝试连接 MAC: ${targetMac}`);
      } else {
        promptAction.showToast({ message: '未找到配对设备，请先在系统蓝牙设置中配对 HC-05' });
        return false;
      }

      // 【修正2】HC-05 建议使用非安全连接，否则容易握手失败
      let sppOption: socket.SppOptions = {
        uuid: this.uuid,
        secure: false,
        type: 0
      };

      promptAction.showToast({ message: '正在连接...' });

      return new Promise((resolve) => {
        // API 12 socket.sppConnect 用法检查无误
        socket.sppConnect(targetMac, sppOption, (err: BusinessError, socketID: number) => {
          if (err) {
            console.error(`SPP连接失败 Code: ${err.code}, Msg: ${err.message}`);
            // 常见错误处理
            if (err.code === 2900003) {
              promptAction.showToast({ message: '连接超时，请检查HC-05是否上电' });
            } else {
              promptAction.showToast({ message: `连接失败: ${err.code}` });
            }
            resolve(false);
            return;
          }

          console.info(`SPP连接成功，SocketID: ${socketID}`);
          this.clientSocketID = socketID;
          promptAction.showToast({ message: '连接成功！' });

          this.listenForData();
          resolve(true);
        });
      });

    } catch (err) {
      let error = err as BusinessError;
      console.error(`执行异常: ${error.message}`);
      return false;
    }
  }

  // 2. 发送数据
  public sendCommand(cmd: string) {
    if (this.clientSocketID === -1) {
      promptAction.showToast({ message: '蓝牙未连接' });
      return;
    }

    try {
      // 【建议】很多 Arduino 代码读取字符串需要换行符作为结束标志
      // 如果你的 Arduino 代码是用 Serial.readStringUntil('\n')，请取消下面这行的注释
      // cmd = cmd + "\n";

      let buffer = new ArrayBuffer(cmd.length);
      let dataView = new DataView(buffer);
      for (let i = 0; i < cmd.length; i++) {
        dataView.setUint8(i, cmd.charCodeAt(i));
      }

      socket.sppWrite(this.clientSocketID, new Uint8Array(buffer).buffer);
      console.info('指令发送成功: ' + cmd);
    } catch (err) {
      let error = err as BusinessError;
      console.error('发送失败: ' + error.message);
      // 如果发送报错，可能是连接断开了
      if (error.code === 2901000) { // 假设的断开码，具体视日志而定
        this.close();
      }
    }
  }

  // 3. 监听接收数据
  private listenForData() {
    if (this.clientSocketID === -1) return;

    try {
      // API 12: on(type: 'sppRead', socketID: number, callback)
      socket.on('sppRead', this.clientSocketID, (dataBuffer: ArrayBuffer) => {
        try {
          let textDecoder = util.TextDecoder.create("utf-8", { ignoreBOM: true });
          let readString = textDecoder.decodeToString(new Uint8Array(dataBuffer));
          console.info("收到 Arduino 消息: " + readString);

          // 这里可以添加逻辑，通过 AppStorage 或 EventHub 通知 UI 更新
        } catch (e) {
          console.error("数据解码失败");
        }
      });
    } catch (err) {
      console.error("监听启动失败: " + JSON.stringify(err));
    }
  }

  // 4. 断开连接
  public close() {
    if (this.clientSocketID !== -1) {
      try {
        socket.sppCloseClientSocket(this.clientSocketID);
        // 重要：关闭后取消监听，防止内存泄漏（虽然系统可能会自动回收，但显式关闭更好）
        socket.off('sppRead', this.clientSocketID);
        console.info(`Socket ${this.clientSocketID} 已关闭`);
      } catch(err) {
        console.error("断开失败: " + JSON.stringify(err));
      } finally {
        this.clientSocketID = -1;
        promptAction.showToast({ message: '连接已断开' });
      }
    }
  }
}