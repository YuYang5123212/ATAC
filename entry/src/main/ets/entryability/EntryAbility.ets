import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { PreferencesUtil } from '../pages/../utils/PreferencesUtil'; // 注意路径，确保引用正确

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 移除 PersistentStorage
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    let windowClass: window.Window = windowStage.getMainWindowSync();
    try {
      windowClass.setWindowLayoutFullScreen(true);
    } catch (err) {}

    // 1. 初始化首选项
    await PreferencesUtil.load(this.context);

    // 2. 【核心】从磁盘读取数据 -> 同步到内存 (AppStorage)
    const lastLogin = await PreferencesUtil.get('LoginTimestamp', 0) as number;
    const historyJson = await PreferencesUtil.get('HistoryDevices_JSON', '[]') as string;
    const logsJson = await PreferencesUtil.get('AppLogs_JSON', '[]') as string;

    // 注入全局内存，供 UI 使用
    AppStorage.setOrCreate('LoginTimestamp', lastLogin);
    AppStorage.setOrCreate('HistoryDevices_JSON', historyJson);
    AppStorage.setOrCreate('AppLogs_JSON', logsJson);

    // 3. 自动登录判断
    const now = new Date().getTime();
    const validPeriod = 30 * 24 * 60 * 60 * 1000; // 30天
    let startPage = 'pages/LoginPage';

    if (lastLogin > 0 && (now - lastLogin < validPeriod)) {
      startPage = 'pages/MainContainer';
    }

    windowStage.loadContent(startPage);
  }
}