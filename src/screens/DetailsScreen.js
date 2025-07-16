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

const DetailsScreen = ({route, navigation}) => {
  const {room = {}} = route.params || {};

  const showNativeAlert = () => {
    Alert.alert(
      'Room Booked',
      `You have successfully booked ${room.name || 'this room'}!`,
      [
        {
          text: 'Cancel',
          style: 'cancel',
        },
        {
          text: 'OK',
          style: 'default',
          onPress: () => navigation.goBack(),
        },
      ],
      {cancelable: false}
    );
  };

  const roomDetails = [
    {icon: 'location-outline', label: 'Location', value: room.location || 'Building A, Floor 2'},
    {icon: 'people-outline', label: 'Capacity', value: room.capacity || '8 people'},
    {icon: 'wifi-outline', label: 'WiFi', value: room.wifi ? 'Available' : 'Not Available'},
    {icon: 'tv-outline', label: 'Projector', value: room.projector ? 'Available' : 'Not Available'},
  ];

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContainer}>
        <View style={styles.header}>
          <Text style={styles.roomTitle}>{room.name || 'Conference Room A'}</Text>
          <Text style={styles.roomType}>{room.type || 'Meeting Room'}</Text>
        </View>

        <View style={styles.detailsCard}>
          <Text style={styles.sectionTitle}>Room Details</Text>
          {roomDetails.map((detail, index) => (
            <View key={index} style={styles.detailRow}>
              <View style={styles.detailLeft}>
                <Icon name={detail.icon} size={24} color="#007AFF" />
                <Text style={styles.detailLabel}>{detail.label}</Text>
              </View>
              <Text style={styles.detailValue}>{detail.value}</Text>
            </View>
          ))}
        </View>

        <View style={styles.descriptionCard}>
          <Text style={styles.sectionTitle}>Description</Text>
          <Text style={styles.description}>
            {room.description || 
            'A modern conference room equipped with the latest technology for productive meetings and presentations. Perfect for team collaborations and client meetings.'}
          </Text>
        </View>

        <View style={styles.availabilityCard}>
          <Text style={styles.sectionTitle}>Availability</Text>
          <View style={styles.timeSlots}>
            {['9:00 AM', '11:00 AM', '2:00 PM', '4:00 PM'].map((time, index) => (
              <TouchableOpacity key={index} style={styles.timeSlot}>
                <Text style={styles.timeText}>{time}</Text>
                <Text style={styles.availableText}>Available</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>
      </ScrollView>

      <View style={styles.buttonContainer}>
        <TouchableOpacity
          style={styles.bookButton}
          onPress={showNativeAlert}
          activeOpacity={0.8}>
          <Icon name="calendar" size={24} color="#FFFFFF" />
          <Text style={styles.buttonText}>Book This Room</Text>
        </TouchableOpacity>
      </View>
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
    paddingBottom: 100,
  },
  header: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 20,
    marginTop: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.22,
    shadowRadius: 2.22,
    elevation: 3,
  },
  roomTitle: {
    fontSize: 28,
    fontWeight: '700',
    color: '#000000',
    marginBottom: 8,
    fontFamily: 'SF Pro Display',
  },
  roomType: {
    fontSize: 17,
    color: '#8E8E93',
    fontFamily: 'SF Pro Text',
  },
  detailsCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 20,
    marginBottom: 16,
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
    fontSize: 20,
    fontWeight: '600',
    color: '#000000',
    marginBottom: 16,
    fontFamily: 'SF Pro Text',
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 0.5,
    borderBottomColor: '#E5E5EA',
  },
  detailLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  detailLabel: {
    fontSize: 17,
    color: '#000000',
    marginLeft: 12,
    fontFamily: 'SF Pro Text',
  },
  detailValue: {
    fontSize: 17,
    color: '#8E8E93',
    fontFamily: 'SF Pro Text',
  },
  descriptionCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 20,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.22,
    shadowRadius: 2.22,
    elevation: 3,
  },
  description: {
    fontSize: 16,
    lineHeight: 24,
    color: '#3C3C43',
    fontFamily: 'SF Pro Text',
  },
  availabilityCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 20,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.22,
    shadowRadius: 2.22,
    elevation: 3,
  },
  timeSlots: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  timeSlot: {
    backgroundColor: '#E8F5E8',
    borderRadius: 8,
    padding: 12,
    width: '48%',
    marginBottom: 12,
    alignItems: 'center',
  },
  timeText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#34C759',
    fontFamily: 'SF Pro Text',
  },
  availableText: {
    fontSize: 14,
    color: '#34C759',
    marginTop: 4,
    fontFamily: 'SF Pro Text',
  },
  buttonContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: '#FFFFFF',
    paddingHorizontal: 20,
    paddingVertical: 20,
    borderTopWidth: 0.5,
    borderTopColor: '#C7C7CC',
  },
  bookButton: {
    backgroundColor: '#34C759',
    borderRadius: 12,
    paddingVertical: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#34C759',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
    marginLeft: 8,
    fontFamily: 'SF Pro Text',
  },
});

export default DetailsScreen;