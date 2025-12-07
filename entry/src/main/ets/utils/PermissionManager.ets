import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

export class PermissionManager {
  public static async requestBluetoothPermission(context: common.UIAbilityContext): Promise<boolean> {
    // 【修改】请求所有必要权限
    const PERMISSIONS: Array<Permissions> = [
      'ohos.permission.ACCESS_BLUETOOTH',
      'ohos.permission.DISCOVER_BLUETOOTH',
      'ohos.permission.APPROXIMATELY_LOCATION'
    ];

    try {
      let atManager = abilityAccessCtrl.createAtManager();
      let result = await atManager.requestPermissionsFromUser(context, PERMISSIONS);

      // 只要有一个权限被拒，就无法扫描
      let allGranted = result.authResults.every(status => status === 0);

      if (!allGranted) {
        promptAction.showToast({ message: '为了扫描设备，请允许定位和蓝牙权限' });
        return false;
      }
      return true;
    } catch (err) {
      console.error(`权限请求出错: ${JSON.stringify(err)}`);
      return false;
    }
  }
}