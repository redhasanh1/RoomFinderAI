import React, {useState} from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import Icon from 'react-native-vector-icons/Ionicons';
import NativeAlertService from '../services/NativeAlertService';

const NativeTestScreen = () => {
  const [deviceInfo, setDeviceInfo] = useState(null);

  const testNativeAlert = async () => {
    try {
      const result = await NativeAlertService.showNativeAlert(
        'Native Alert',
        'This is a native iOS alert dialog!'
      );
      Alert.alert('Result', `Button pressed: ${result}`);
    } catch (error) {
      Alert.alert('Error', error.message);
    }
  };

  const testActionSheet = async () => {
    try {
      const result = await NativeAlertService.showActionSheet(
        'Choose an Option',
        'Select your preferred room type:',
        ['Conference Room', 'Meeting Room', 'Phone Booth', 'Open Space']
      );
      
      if (result === -1) {
        Alert.alert('Result', 'Action cancelled');
      } else {
        const options = ['Conference Room', 'Meeting Room', 'Phone Booth', 'Open Space'];
        Alert.alert('Result', `Selected: ${options[result]}`);
      }
    } catch (error) {
      Alert.alert('Error', error.message);
    }
  };

  const testConfirmDialog = async () => {
    try {
      const result = await NativeAlertService.showConfirmDialog(
        'Delete Room',
        'Are you sure you want to delete this room? This action cannot be undone.',
        'Delete',
        'Keep'
      );
      
      Alert.alert('Result', result ? 'Room deleted' : 'Room kept');
    } catch (error) {
      Alert.alert('Error', error.message);
    }
  };

  const testHapticFeedback = async (type) => {
    try {
      await NativeAlertService.hapticFeedback(type);
      Alert.alert('Success', `${type} haptic feedback triggered`);
    } catch (error) {
      Alert.alert('Error', error.message);
    }
  };

  const getDeviceInfo = async () => {
    try {
      const info = await NativeAlertService.getDeviceInfo();
      setDeviceInfo(info);
    } catch (error) {
      Alert.alert('Error', error.message);
    }
  };

  const renderButton = (title, onPress, color = '#007AFF') => (
    <TouchableOpacity
      style={[styles.button, {backgroundColor: color}]}
      onPress={onPress}
      activeOpacity={0.8}>
      <Text style={styles.buttonText}>{title}</Text>
    </TouchableOpacity>
  );

  const renderHapticButton = (type, color) => (
    <TouchableOpacity
      style={[styles.hapticButton, {backgroundColor: color}]}
      onPress={() => testHapticFeedback(type)}
      activeOpacity={0.8}>
      <Text style={styles.hapticButtonText}>{type}</Text>
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContainer}>
        <View style={styles.header}>
          <Icon name="phone-portrait" size={32} color="#007AFF" />
          <Text style={styles.title}>Native Module Test</Text>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Alert Dialogs</Text>
          {renderButton('Show Native Alert', testNativeAlert)}
          {renderButton('Show Action Sheet', testActionSheet)}
          {renderButton('Show Confirm Dialog', testConfirmDialog, '#FF9500')}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Haptic Feedback</Text>
          <View style={styles.hapticContainer}>
            {renderHapticButton('light', '#34C759')}
            {renderHapticButton('medium', '#007AFF')}
            {renderHapticButton('heavy', '#5856D6')}
          </View>
          <View style={styles.hapticContainer}>
            {renderHapticButton('success', '#34C759')}
            {renderHapticButton('warning', '#FF9500')}
            {renderHapticButton('error', '#FF3B30')}
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Device Information</Text>
          {renderButton('Get Device Info', getDeviceInfo, '#5856D6')}
          
          {deviceInfo && (
            <View style={styles.deviceInfoContainer}>
              <Text style={styles.deviceInfoTitle}>Device Info:</Text>
              <Text style={styles.deviceInfoText}>Model: {deviceInfo.model}</Text>
              <Text style={styles.deviceInfoText}>Name: {deviceInfo.name}</Text>
              <Text style={styles.deviceInfoText}>System: {deviceInfo.systemName} {deviceInfo.systemVersion}</Text>
              <Text style={styles.deviceInfoText}>Screen: {deviceInfo.screenWidth}x{deviceInfo.screenHeight} @{deviceInfo.screenScale}x</Text>
            </View>
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F2F2F7',
  },
  scrollContainer: {
    paddingHorizontal: 20,
    paddingBottom: 40,
  },
  header: {
    alignItems: 'center',
    paddingVertical: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: '600',
    color: '#000000',
    marginTop: 12,
    fontFamily: 'SF Pro Display',
  },
  section: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 20,
    marginBottom: 20,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.22,
    shadowRadius: 2.22,
    elevation: 3,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#000000',
    marginBottom: 16,
    fontFamily: 'SF Pro Text',
  },
  button: {
    borderRadius: 10,
    paddingVertical: 16,
    paddingHorizontal: 20,
    marginBottom: 12,
    alignItems: 'center',
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'SF Pro Text',
  },
  hapticContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  hapticButton: {
    borderRadius: 8,
    paddingVertical: 12,
    paddingHorizontal: 16,
    flex: 1,
    marginHorizontal: 4,
    alignItems: 'center',
  },
  hapticButtonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
    fontFamily: 'SF Pro Text',
  },
  deviceInfoContainer: {
    backgroundColor: '#F2F2F7',
    borderRadius: 8,
    padding: 16,
    marginTop: 12,
  },
  deviceInfoTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#000000',
    marginBottom: 12,
    fontFamily: 'SF Pro Text',
  },
  deviceInfoText: {
    fontSize: 14,
    color: '#3C3C43',
    marginBottom: 4,
    fontFamily: 'SF Pro Text',
  },
});

export default NativeTestScreen;