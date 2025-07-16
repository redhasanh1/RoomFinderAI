import React from 'react';
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

const ProfileScreen = () => {
  const profileOptions = [
    {
      icon: 'person-outline',
      title: 'Edit Profile',
      onPress: () => Alert.alert('Info', 'Edit Profile coming soon!'),
    },
    {
      icon: 'notifications-outline',
      title: 'Notifications',
      onPress: () => Alert.alert('Info', 'Notification settings coming soon!'),
    },
    {
      icon: 'settings-outline',
      title: 'Settings',
      onPress: () => Alert.alert('Info', 'Settings coming soon!'),
    },
    {
      icon: 'help-circle-outline',
      title: 'Help & Support',
      onPress: () => Alert.alert('Info', 'Help & Support coming soon!'),
    },
    {
      icon: 'log-out-outline',
      title: 'Sign Out',
      onPress: () => Alert.alert('Sign Out', 'Are you sure you want to sign out?'),
      isDestructive: true,
    },
  ];

  const renderProfileOption = (option, index) => (
    <TouchableOpacity
      key={index}
      style={styles.optionItem}
      onPress={option.onPress}
      activeOpacity={0.7}>
      <View style={styles.optionLeft}>
        <Icon 
          name={option.icon} 
          size={24} 
          color={option.isDestructive ? '#FF3B30' : '#007AFF'} 
        />
        <Text style={[
          styles.optionTitle,
          {color: option.isDestructive ? '#FF3B30' : '#000000'}
        ]}>
          {option.title}
        </Text>
      </View>
      <Icon name="chevron-forward" size={20} color="#C7C7CC" />
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContainer}>
        <View style={styles.profileHeader}>
          <View style={styles.avatarContainer}>
            <Icon name="person" size={40} color="#FFFFFF" />
          </View>
          <Text style={styles.userName}>John Doe</Text>
          <Text style={styles.userEmail}>john.doe@company.com</Text>
        </View>

        <View style={styles.optionsContainer}>
          {profileOptions.map((option, index) => renderProfileOption(option, index))}
        </View>

        <View style={styles.footer}>
          <Text style={styles.versionText}>Version 1.0.0</Text>
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
  profileHeader: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 24,
    alignItems: 'center',
    marginTop: 16,
    marginBottom: 24,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.22,
    shadowRadius: 2.22,
    elevation: 3,
  },
  avatarContainer: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  userName: {
    fontSize: 24,
    fontWeight: '600',
    color: '#000000',
    marginBottom: 4,
    fontFamily: 'SF Pro Display',
  },
  userEmail: {
    fontSize: 16,
    color: '#8E8E93',
    fontFamily: 'SF Pro Text',
  },
  optionsContainer: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.22,
    shadowRadius: 2.22,
    elevation: 3,
  },
  optionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 16,
    paddingHorizontal: 20,
    borderBottomWidth: 0.5,
    borderBottomColor: '#E5E5EA',
  },
  optionLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  optionTitle: {
    fontSize: 17,
    fontWeight: '400',
    marginLeft: 16,
    fontFamily: 'SF Pro Text',
  },
  footer: {
    alignItems: 'center',
    marginTop: 32,
  },
  versionText: {
    fontSize: 14,
    color: '#8E8E93',
    fontFamily: 'SF Pro Text',
  },
});

export default ProfileScreen;