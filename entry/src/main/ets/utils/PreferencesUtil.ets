import dataPreferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';

const PREF_NAME = 'ATAccessConfig';

export class PreferencesUtil {
  private static pref: dataPreferences.Preferences | null = null;

  // 1. 初始化
  static async load(context: common.UIAbilityContext) {
    try {
      // 【修复】this -> PreferencesUtil
      PreferencesUtil.pref = await dataPreferences.getPreferences(context, PREF_NAME);
      console.info('Preferences 初始化成功');
    } catch (err) {
      console.error('Preferences 初始化失败', JSON.stringify(err));
    }
  }

  // 2. 保存数据
  static async put(key: string, value: string | number | boolean) {
    if (!PreferencesUtil.pref) return;
    try {
      await PreferencesUtil.pref.put(key, value);
      await PreferencesUtil.pref.flush();
    } catch (e) {
      console.error(`保存失败 [${key}]:`, JSON.stringify(e));
    }
  }

  // 3. 读取数据
  static async get(key: string, defaultValue: string | number | boolean): Promise<dataPreferences.ValueType> {
    if (!PreferencesUtil.pref) return defaultValue;
    try {
      return await PreferencesUtil.pref.get(key, defaultValue);
    } catch (e) {
      return defaultValue;
    }
  }
}