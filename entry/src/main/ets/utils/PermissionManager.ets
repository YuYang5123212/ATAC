import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import type common from '@ohos.app.ability.common';

interface PermissionRequestResult {
  authResults: Array<number>;
}

/**
 * 权限管理类：负责动态请求鸿蒙系统的权限。
 */
export class PermissionManager {
  /** 动态申请蓝牙权限 */
  public static async requestBluetoothPermission(context: common.UIAbilityContext): Promise<boolean> {
    const PERMISSIONS: Array<string> = ['ohos.permission.ACCESS_BLUETOOTH'];

    try {
      // API 17 中 createAtManager 不带参数
      let atManager = abilityAccessCtrl.createAtManager();
      promptAction.showToast({ message: '正在请求蓝牙权限...' });
      // 【修正 1】：使用 Object 类型接收返回值，避免 'unknown' 导致的 ERROR 1
      let requestResult: Object = await atManager.requestPermissionsFromUser(context, PERMISSIONS as Permissions[]);
      // 【修正 2】：定义 grantResults 变量并赋值 (解决 ERROR 6, 7 和潜在的类型问题)
      // 使用类型断言和属性访问替代索引访问
      let resultObject: PermissionRequestResult = requestResult as PermissionRequestResult;
      let grantResults: Array<number> = resultObject.authResults;

      if (grantResults.length > 0 && grantResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        promptAction.showToast({ message: '蓝牙权限申请成功' });
        return true;
      } else {
        promptAction.showToast({ message: '蓝牙连接需要蓝牙权限' });
        return false;
      }

    } catch (err) {
      let error = err as BusinessError;
      console.error(`权限请求异常: Code: ${error.code}, Message: ${error.message}`);
      promptAction.showToast({ message: `权限请求异常: ${error.message}` });
      return false;
    }
  }
}