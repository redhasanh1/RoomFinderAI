import {NativeModules, Platform} from 'react-native';

const {NativeAlertModule} = NativeModules;

class NativeAlertService {
  /**
   * Show a native iOS alert dialog
   * @param {string} title - Alert title
   * @param {string} message - Alert message
   * @returns {Promise<string>} - Returns 'OK_PRESSED' or 'CANCEL_PRESSED'
   */
  static async showNativeAlert(title, message) {
    if (Platform.OS !== 'ios' || !NativeAlertModule) {
      console.warn('NativeAlertModule is only available on iOS');
      return Promise.reject('Platform not supported');
    }

    try {
      const result = await NativeAlertModule.showNativeAlert(title, message);
      return result;
    } catch (error) {
      console.error('Error showing native alert:', error);
      throw error;
    }
  }

  /**
   * Show a native iOS action sheet
   * @param {string} title - Action sheet title
   * @param {string} message - Action sheet message
   * @param {Array<string>} options - Array of option strings
   * @returns {Promise<number>} - Returns index of selected option (-1 for cancel)
   */
  static async showActionSheet(title, message, options) {
    if (Platform.OS !== 'ios' || !NativeAlertModule) {
      console.warn('NativeAlertModule is only available on iOS');
      return Promise.reject('Platform not supported');
    }

    try {
      const result = await NativeAlertModule.showActionSheet(title, message, options);
      return result;
    } catch (error) {
      console.error('Error showing action sheet:', error);
      throw error;
    }
  }

  /**
   * Show a native iOS confirm dialog
   * @param {string} title - Dialog title
   * @param {string} message - Dialog message
   * @param {string} confirmText - Confirm button text (default: 'Confirm')
   * @param {string} cancelText - Cancel button text (default: 'Cancel')
   * @returns {Promise<boolean>} - Returns true if confirmed, false if cancelled
   */
  static async showConfirmDialog(title, message, confirmText = 'Confirm', cancelText = 'Cancel') {
    if (Platform.OS !== 'ios' || !NativeAlertModule) {
      console.warn('NativeAlertModule is only available on iOS');
      return Promise.reject('Platform not supported');
    }

    try {
      const result = await NativeAlertModule.showConfirmDialog(title, message, confirmText, cancelText);
      return result;
    } catch (error) {
      console.error('Error showing confirm dialog:', error);
      throw error;
    }
  }

  /**
   * Get device information
   * @returns {Promise<Object>} - Returns device info object
   */
  static async getDeviceInfo() {
    if (Platform.OS !== 'ios' || !NativeAlertModule) {
      console.warn('NativeAlertModule is only available on iOS');
      return Promise.reject('Platform not supported');
    }

    try {
      const deviceInfo = await NativeAlertModule.getDeviceInfo();
      return deviceInfo;
    } catch (error) {
      console.error('Error getting device info:', error);
      throw error;
    }
  }

  /**
   * Trigger haptic feedback
   * @param {string} type - Haptic type: 'light', 'medium', 'heavy', 'success', 'warning', 'error'
   * @returns {Promise<string>} - Returns 'HAPTIC_TRIGGERED' on success
   */
  static async hapticFeedback(type) {
    if (Platform.OS !== 'ios' || !NativeAlertModule) {
      console.warn('NativeAlertModule is only available on iOS');
      return Promise.reject('Platform not supported');
    }

    try {
      const result = await NativeAlertModule.hapticFeedback(type);
      return result;
    } catch (error) {
      console.error('Error triggering haptic feedback:', error);
      throw error;
    }
  }
}

export default NativeAlertService;