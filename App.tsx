import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  FlatList,
  StyleSheet,
  Platform,
  Alert,
  SafeAreaView,
  StatusBar,
  ScrollView,
  Image,
  ActivityIndicator,
} from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import axios from 'axios';

const Stack = createStackNavigator();
const Tab = createBottomTabNavigator();

// Types
interface Property {
  id: string;
  title: string;
  price: number;
  location: string;
  bedrooms: number;
  bathrooms: number;
  description: string;
  imageUrl?: string;
  type: 'apartment' | 'house' | 'room';
}

interface ChatMessage {
  id: string;
  text: string;
  sender: 'user' | 'ai';
  timestamp: Date;
}

interface User {
  id: string;
  email: string;
  name: string;
  token: string;
}

// API Service
const API_BASE_URL = 'https://your-api-endpoint.com'; // Replace with your actual API

const apiService = {
  async login(email: string, password: string): Promise<User> {
    const response = await axios.post(`${API_BASE_URL}/auth/login`, {
      email,
      password,
    });
    return response.data;
  },

  async getProperties(): Promise<Property[]> {
    const response = await axios.get(`${API_BASE_URL}/api/properties`);
    return response.data;
  },

  async searchProperties(query: string): Promise<Property[]> {
    const response = await axios.get(`${API_BASE_URL}/api/properties/search`, {
      params: { q: query },
    });
    return response.data;
  },

  async sendChatMessage(message: string): Promise<string> {
    const response = await axios.post(`${API_BASE_URL}/api/chat`, {
      message,
    });
    return response.data.response;
  },
};

// Components
const PropertyCard: React.FC<{ property: Property; onPress: () => void }> = ({
  property,
  onPress,
}) => (
  <TouchableOpacity style={styles.propertyCard} onPress={onPress}>
    <View style={styles.propertyImageContainer}>
      <Image
        source={{ uri: property.imageUrl || 'https://via.placeholder.com/300x200' }}
        style={styles.propertyImage}
        resizeMode="cover"
      />
      <View style={styles.propertyTypeTag}>
        <Text style={styles.propertyTypeText}>{property.type.toUpperCase()}</Text>
      </View>
    </View>
    <View style={styles.propertyInfo}>
      <Text style={styles.propertyTitle}>{property.title}</Text>
      <Text style={styles.propertyLocation}>{property.location}</Text>
      <View style={styles.propertyDetails}>
        <Text style={styles.propertyDetailsText}>
          {property.bedrooms} bed • {property.bathrooms} bath
        </Text>
        <Text style={styles.propertyPrice}>${property.price}/month</Text>
      </View>
    </View>
  </TouchableOpacity>
);

const ChatMessageItem: React.FC<{ message: ChatMessage }> = ({ message }) => (
  <View
    style={[
      styles.chatMessage,
      message.sender === 'user' ? styles.userMessage : styles.aiMessage,
    ]}
  >
    <Text style={styles.chatMessageText}>{message.text}</Text>
    <Text style={styles.chatTimestamp}>
      {message.timestamp.toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
      })}
    </Text>
  </View>
);

// Screens
const HomeScreen: React.FC<{ navigation: any }> = ({ navigation }) => {
  const [properties, setProperties] = useState<Property[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    loadProperties();
  }, []);

  const loadProperties = async () => {
    try {
      setLoading(true);
      // For demo purposes, using mock data
      const mockProperties: Property[] = [
        {
          id: '1',
          title: 'Modern Studio Apartment',
          price: 1200,
          location: 'Downtown',
          bedrooms: 1,
          bathrooms: 1,
          description: 'Beautiful modern studio in the heart of downtown.',
          type: 'apartment',
        },
        {
          id: '2',
          title: 'Cozy 2BR House',
          price: 1800,
          location: 'Suburbs',
          bedrooms: 2,
          bathrooms: 2,
          description: 'Spacious house with garden and parking.',
          type: 'house',
        },
        {
          id: '3',
          title: 'Shared Room',
          price: 600,
          location: 'University Area',
          bedrooms: 1,
          bathrooms: 1,
          description: 'Shared room near campus, utilities included.',
          type: 'room',
        },
      ];
      setProperties(mockProperties);
    } catch (error) {
      console.error('Error loading properties:', error);
      Alert.alert('Error', 'Failed to load properties');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      loadProperties();
      return;
    }
    
    try {
      setLoading(true);
      // Filter mock data for demo
      const filtered = properties.filter(property =>
        property.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        property.location.toLowerCase().includes(searchQuery.toLowerCase())
      );
      setProperties(filtered);
    } catch (error) {
      console.error('Error searching properties:', error);
      Alert.alert('Error', 'Failed to search properties');
    } finally {
      setLoading(false);
    }
  };

  const handlePropertyPress = (property: Property) => {
    navigation.navigate('PropertyDetail', { property });
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#fff" />
      <View style={styles.header}>
        <Text style={styles.headerTitle}>RoomFinder AI</Text>
        <Text style={styles.headerSubtitle}>Find your perfect room</Text>
      </View>
      
      <View style={styles.searchContainer}>
        <TextInput
          style={styles.searchInput}
          placeholder="Search properties..."
          value={searchQuery}
          onChangeText={setSearchQuery}
          onSubmitEditing={handleSearch}
        />
        <TouchableOpacity style={styles.searchButton} onPress={handleSearch}>
          <Text style={styles.searchButtonText}>Search</Text>
        </TouchableOpacity>
      </View>

      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#007AFF" />
          <Text style={styles.loadingText}>Loading properties...</Text>
        </View>
      ) : (
        <FlatList
          data={properties}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => (
            <PropertyCard
              property={item}
              onPress={() => handlePropertyPress(item)}
            />
          )}
          contentContainerStyle={styles.propertiesList}
          showsVerticalScrollIndicator={false}
        />
      )}
    </SafeAreaView>
  );
};

const PropertyDetailScreen: React.FC<{ route: any; navigation: any }> = ({
  route,
  navigation,
}) => {
  const { property } = route.params;

  const handleContactOwner = () => {
    Alert.alert(
      'Contact Owner',
      `Contact information for ${property.title}`,
      [
        { text: 'Call', onPress: () => console.log('Call pressed') },
        { text: 'Message', onPress: () => console.log('Message pressed') },
        { text: 'Cancel', style: 'cancel' },
      ]
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.detailContainer}>
        <Image
          source={{ uri: property.imageUrl || 'https://via.placeholder.com/400x300' }}
          style={styles.detailImage}
          resizeMode="cover"
        />
        
        <View style={styles.detailContent}>
          <View style={styles.detailHeader}>
            <Text style={styles.detailTitle}>{property.title}</Text>
            <Text style={styles.detailPrice}>${property.price}/month</Text>
          </View>
          
          <Text style={styles.detailLocation}>{property.location}</Text>
          
          <View style={styles.detailFeatures}>
            <View style={styles.featureItem}>
              <Text style={styles.featureLabel}>Bedrooms</Text>
              <Text style={styles.featureValue}>{property.bedrooms}</Text>
            </View>
            <View style={styles.featureItem}>
              <Text style={styles.featureLabel}>Bathrooms</Text>
              <Text style={styles.featureValue}>{property.bathrooms}</Text>
            </View>
            <View style={styles.featureItem}>
              <Text style={styles.featureLabel}>Type</Text>
              <Text style={styles.featureValue}>{property.type}</Text>
            </View>
          </View>
          
          <Text style={styles.detailDescription}>{property.description}</Text>
          
          <TouchableOpacity
            style={styles.contactButton}
            onPress={handleContactOwner}
          >
            <Text style={styles.contactButtonText}>Contact Owner</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const ChatScreen: React.FC = () => {
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: '1',
      text: 'Hello! I\'m your AI assistant. How can I help you find the perfect room today?',
      sender: 'ai',
      timestamp: new Date(),
    },
  ]);
  const [inputText, setInputText] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSendMessage = async () => {
    if (!inputText.trim()) return;

    const userMessage: ChatMessage = {
      id: Date.now().toString(),
      text: inputText,
      sender: 'user',
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setInputText('');
    setLoading(true);

    try {
      // Simulate AI response for demo
      setTimeout(() => {
        const aiResponse: ChatMessage = {
          id: (Date.now() + 1).toString(),
          text: `I understand you're looking for "${inputText}". Let me help you find the best options based on your preferences. Would you like me to search for properties in a specific area or price range?`,
          sender: 'ai',
          timestamp: new Date(),
        };
        setMessages(prev => [...prev, aiResponse]);
        setLoading(false);
      }, 1000);
    } catch (error) {
      console.error('Error sending message:', error);
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.chatContainer}>
        <FlatList
          data={messages}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => <ChatMessageItem message={item} />}
          contentContainerStyle={styles.chatMessages}
          showsVerticalScrollIndicator={false}
        />
        
        {loading && (
          <View style={styles.typingIndicator}>
            <ActivityIndicator size="small" color="#007AFF" />
            <Text style={styles.typingText}>AI is typing...</Text>
          </View>
        )}
        
        <View style={styles.chatInputContainer}>
          <TextInput
            style={styles.chatInput}
            placeholder="Type your message..."
            value={inputText}
            onChangeText={setInputText}
            multiline
            maxLength={500}
          />
          <TouchableOpacity
            style={styles.sendButton}
            onPress={handleSendMessage}
            disabled={!inputText.trim() || loading}
          >
            <Text style={styles.sendButtonText}>Send</Text>
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
};

const LoginScreen: React.FC<{ navigation: any }> = ({ navigation }) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async () => {
    if (!email || !password) {
      Alert.alert('Error', 'Please fill in all fields');
      return;
    }

    setLoading(true);
    try {
      // Simulate login for demo
      setTimeout(() => {
        Alert.alert('Success', 'Login successful!');
        navigation.navigate('Home');
        setLoading(false);
      }, 1000);
    } catch (error) {
      console.error('Login error:', error);
      Alert.alert('Error', 'Login failed. Please try again.');
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.loginContainer}>
        <Text style={styles.loginTitle}>Welcome Back</Text>
        <Text style={styles.loginSubtitle}>Sign in to your account</Text>
        
        <TextInput
          style={styles.input}
          placeholder="Email"
          value={email}
          onChangeText={setEmail}
          autoCapitalize="none"
          keyboardType="email-address"
        />
        
        <TextInput
          style={styles.input}
          placeholder="Password"
          value={password}
          onChangeText={setPassword}
          secureTextEntry
        />
        
        <TouchableOpacity
          style={styles.loginButton}
          onPress={handleLogin}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.loginButtonText}>Sign In</Text>
          )}
        </TouchableOpacity>
        
        <TouchableOpacity style={styles.forgotPassword}>
          <Text style={styles.forgotPasswordText}>Forgot Password?</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
};

const ProfileScreen: React.FC = () => {
  const [user] = useState({
    name: 'John Doe',
    email: 'john.doe@example.com',
    memberSince: '2023',
  });

  const handleLogout = () => {
    Alert.alert(
      'Logout',
      'Are you sure you want to logout?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Logout', onPress: () => console.log('Logout pressed') },
      ]
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.profileContainer}>
        <View style={styles.profileHeader}>
          <View style={styles.profileAvatar}>
            <Text style={styles.profileAvatarText}>
              {user.name.split(' ').map(n => n[0]).join('')}
            </Text>
          </View>
          <Text style={styles.profileName}>{user.name}</Text>
          <Text style={styles.profileEmail}>{user.email}</Text>
        </View>
        
        <View style={styles.profileSection}>
          <TouchableOpacity style={styles.profileItem}>
            <Text style={styles.profileItemText}>Edit Profile</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.profileItem}>
            <Text style={styles.profileItemText}>Saved Properties</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.profileItem}>
            <Text style={styles.profileItemText}>Notifications</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.profileItem}>
            <Text style={styles.profileItemText}>Help & Support</Text>
          </TouchableOpacity>
        </View>
        
        <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
          <Text style={styles.logoutButtonText}>Logout</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
};

// Navigation
const HomeStack = () => (
  <Stack.Navigator>
    <Stack.Screen 
      name="Home" 
      component={HomeScreen} 
      options={{ headerShown: false }}
    />
    <Stack.Screen 
      name="PropertyDetail" 
      component={PropertyDetailScreen} 
      options={{ 
        title: 'Property Details',
        headerBackTitle: 'Back',
      }}
    />
  </Stack.Navigator>
);

const MainTabNavigator = () => (
  <Tab.Navigator
    screenOptions={{
      tabBarStyle: {
        backgroundColor: '#fff',
        borderTopWidth: 1,
        borderTopColor: '#e0e0e0',
        paddingBottom: Platform.OS === 'ios' ? 20 : 0,
        height: Platform.OS === 'ios' ? 90 : 60,
      },
      tabBarActiveTintColor: '#007AFF',
      tabBarInactiveTintColor: '#8e8e93',
      headerShown: false,
    }}
  >
    <Tab.Screen 
      name="HomeTab" 
      component={HomeStack} 
      options={{ title: 'Home' }}
    />
    <Tab.Screen 
      name="Chat" 
      component={ChatScreen} 
      options={{ title: 'AI Chat' }}
    />
    <Tab.Screen 
      name="Profile" 
      component={ProfileScreen} 
      options={{ title: 'Profile' }}
    />
  </Tab.Navigator>
);

const App: React.FC = () => (
  <NavigationContainer>
    <Stack.Navigator initialRouteName="Login">
      <Stack.Screen 
        name="Login" 
        component={LoginScreen} 
        options={{ headerShown: false }}
      />
      <Stack.Screen 
        name="Main" 
        component={MainTabNavigator} 
        options={{ headerShown: false }}
      />
    </Stack.Navigator>
  </NavigationContainer>
);

// Styles
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  header: {
    padding: 20,
    paddingBottom: 10,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: '700',
    color: '#1d1d1f',
    fontFamily: Platform.OS === 'ios' ? 'System' : 'sans-serif',
  },
  headerSubtitle: {
    fontSize: 16,
    color: '#8e8e93',
    marginTop: 4,
  },
  searchContainer: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    paddingBottom: 20,
    gap: 10,
  },
  searchInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    backgroundColor: '#f8f9fa',
  },
  searchButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 12,
    justifyContent: 'center',
  },
  searchButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 10,
    fontSize: 16,
    color: '#8e8e93',
  },
  propertiesList: {
    paddingHorizontal: 20,
  },
  propertyCard: {
    backgroundColor: '#fff',
    borderRadius: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  propertyImageContainer: {
    position: 'relative',
  },
  propertyImage: {
    width: '100%',
    height: 200,
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
  },
  propertyTypeTag: {
    position: 'absolute',
    top: 12,
    left: 12,
    backgroundColor: '#007AFF',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
  },
  propertyTypeText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  propertyInfo: {
    padding: 16,
  },
  propertyTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1d1d1f',
    marginBottom: 4,
  },
  propertyLocation: {
    fontSize: 14,
    color: '#8e8e93',
    marginBottom: 8,
  },
  propertyDetails: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  propertyDetailsText: {
    fontSize: 14,
    color: '#8e8e93',
  },
  propertyPrice: {
    fontSize: 18,
    fontWeight: '700',
    color: '#007AFF',
  },
  detailContainer: {
    flex: 1,
  },
  detailImage: {
    width: '100%',
    height: 300,
  },
  detailContent: {
    padding: 20,
  },
  detailHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  detailTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: '#1d1d1f',
    flex: 1,
    marginRight: 10,
  },
  detailPrice: {
    fontSize: 20,
    fontWeight: '700',
    color: '#007AFF',
  },
  detailLocation: {
    fontSize: 16,
    color: '#8e8e93',
    marginBottom: 20,
  },
  detailFeatures: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    backgroundColor: '#f8f9fa',
    borderRadius: 12,
    padding: 16,
    marginBottom: 20,
  },
  featureItem: {
    alignItems: 'center',
  },
  featureLabel: {
    fontSize: 14,
    color: '#8e8e93',
    marginBottom: 4,
  },
  featureValue: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1d1d1f',
  },
  detailDescription: {
    fontSize: 16,
    color: '#1d1d1f',
    lineHeight: 24,
    marginBottom: 30,
  },
  contactButton: {
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  contactButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
  chatContainer: {
    flex: 1,
  },
  chatMessages: {
    padding: 20,
  },
  chatMessage: {
    marginBottom: 16,
    padding: 12,
    borderRadius: 16,
    maxWidth: '80%',
  },
  userMessage: {
    alignSelf: 'flex-end',
    backgroundColor: '#007AFF',
  },
  aiMessage: {
    alignSelf: 'flex-start',
    backgroundColor: '#f0f0f0',
  },
  chatMessageText: {
    fontSize: 16,
    color: '#1d1d1f',
    marginBottom: 4,
  },
  chatTimestamp: {
    fontSize: 12,
    color: '#8e8e93',
    textAlign: 'right',
  },
  typingIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 10,
  },
  typingText: {
    marginLeft: 8,
    fontSize: 14,
    color: '#8e8e93',
  },
  chatInputContainer: {
    flexDirection: 'row',
    padding: 20,
    paddingTop: 10,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
    backgroundColor: '#fff',
  },
  chatInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    maxHeight: 100,
    marginRight: 10,
  },
  sendButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 20,
    justifyContent: 'center',
  },
  sendButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  loginContainer: {
    flex: 1,
    justifyContent: 'center',
    padding: 20,
  },
  loginTitle: {
    fontSize: 32,
    fontWeight: '700',
    color: '#1d1d1f',
    textAlign: 'center',
    marginBottom: 8,
  },
  loginSubtitle: {
    fontSize: 16,
    color: '#8e8e93',
    textAlign: 'center',
    marginBottom: 40,
  },
  input: {
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 16,
    fontSize: 16,
    marginBottom: 16,
    backgroundColor: '#f8f9fa',
  },
  loginButton: {
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    marginBottom: 16,
  },
  loginButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
  forgotPassword: {
    alignItems: 'center',
  },
  forgotPasswordText: {
    color: '#007AFF',
    fontSize: 16,
  },
  profileContainer: {
    flex: 1,
    padding: 20,
  },
  profileHeader: {
    alignItems: 'center',
    marginBottom: 40,
  },
  profileAvatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  profileAvatarText: {
    fontSize: 24,
    fontWeight: '700',
    color: '#fff',
  },
  profileName: {
    fontSize: 24,
    fontWeight: '700',
    color: '#1d1d1f',
    marginBottom: 4,
  },
  profileEmail: {
    fontSize: 16,
    color: '#8e8e93',
  },
  profileSection: {
    marginBottom: 40,
  },
  profileItem: {
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  profileItemText: {
    fontSize: 18,
    color: '#1d1d1f',
  },
  logoutButton: {
    backgroundColor: '#ff3b30',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  logoutButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
});

export default App;