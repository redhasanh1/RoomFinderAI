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
  Modal,
  KeyboardAvoidingView,
  Dimensions,
  RefreshControl,
} from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import supabaseService from './src/services/SupabaseService';

const Stack = createStackNavigator();
const Tab = createBottomTabNavigator();
const { width: screenWidth, height: screenHeight } = Dimensions.get('window');

// Global state management
const AppContext = React.createContext();

const AppProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [properties, setProperties] = useState([]);
  const [chatMessages, setChatMessages] = useState([]);

  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    try {
      await supabaseService.init();
      const currentUser = await supabaseService.getCurrentUser();
      
      if (currentUser) {
        const profile = await supabaseService.getUserProfile(currentUser.email);
        setUser({ ...currentUser, ...profile });
      }
    } catch (error) {
      console.error('App initialization error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (email, password) => {
    try {
      const { user: authUser } = await supabaseService.signIn(email, password);
      const profile = await supabaseService.getUserProfile(authUser.email);
      setUser({ ...authUser, ...profile });
      return true;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  };

  const logout = async () => {
    try {
      await supabaseService.signOut();
      setUser(null);
      setProperties([]);
      setChatMessages([]);
    } catch (error) {
      console.error('Logout error:', error);
      throw error;
    }
  };

  const value = {
    user,
    setUser,
    isLoading,
    properties,
    setProperties,
    chatMessages,
    setChatMessages,
    login,
    logout,
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
};

const useApp = () => {
  const context = React.useContext(AppContext);
  if (!context) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
};

// Components
const PropertyCard = ({ property, onPress }) => (
  <TouchableOpacity style={styles.propertyCard} onPress={onPress}>
    <View style={styles.propertyImageContainer}>
      <Image
        source={{ 
          uri: property.media && property.media.length > 0 
            ? (typeof property.media[0] === 'string' ? property.media[0] : property.media[0].url)
            : 'https://via.placeholder.com/300x200?text=No+Image'
        }}
        style={styles.propertyImage}
        resizeMode="cover"
      />
      <View style={styles.propertyTypeTag}>
        <Text style={styles.propertyTypeText}>{property.house_type?.toUpperCase() || 'PROPERTY'}</Text>
      </View>
    </View>
    <View style={styles.propertyInfo}>
      <Text style={styles.propertyTitle} numberOfLines={2}>
        {property.title || 'Untitled Property'}
      </Text>
      <Text style={styles.propertyLocation} numberOfLines={1}>
        📍 {property.city || 'Location not specified'}
        {property.street && ` • ${property.street}`}
      </Text>
      <View style={styles.propertyDetails}>
        <Text style={styles.propertyDetailsText}>
          {property.bedrooms || 0} bed • {property.utilities || 'N/A'} utilities
        </Text>
        <Text style={styles.propertyPrice}>
          {supabaseService.formatPrice(property.price || 0)}/month
        </Text>
      </View>
    </View>
  </TouchableOpacity>
);

const LoadingSpinner = ({ message = 'Loading...' }) => (
  <View style={styles.loadingContainer}>
    <ActivityIndicator size="large" color="#007AFF" />
    <Text style={styles.loadingText}>{message}</Text>
  </View>
);

const EmptyState = ({ message, onRefresh }) => (
  <View style={styles.emptyContainer}>
    <Text style={styles.emptyText}>{message}</Text>
    {onRefresh && (
      <TouchableOpacity style={styles.refreshButton} onPress={onRefresh}>
        <Text style={styles.refreshButtonText}>Refresh</Text>
      </TouchableOpacity>
    )}
  </View>
);

const SearchBar = ({ value, onChangeText, onSubmit, placeholder = 'Search properties...' }) => (
  <View style={styles.searchContainer}>
    <TextInput
      style={styles.searchInput}
      placeholder={placeholder}
      value={value}
      onChangeText={onChangeText}
      onSubmitEditing={onSubmit}
      returnKeyType="search"
    />
    <TouchableOpacity style={styles.searchButton} onPress={onSubmit}>
      <Text style={styles.searchButtonText}>Search</Text>
    </TouchableOpacity>
  </View>
);

const FilterModal = ({ visible, onClose, onApply, filters, setFilters }) => (
  <Modal
    animationType="slide"
    transparent={true}
    visible={visible}
    onRequestClose={onClose}
  >
    <View style={styles.modalOverlay}>
      <View style={styles.modalContent}>
        <View style={styles.modalHeader}>
          <Text style={styles.modalTitle}>Filter Properties</Text>
          <TouchableOpacity onPress={onClose}>
            <Text style={styles.modalCloseButton}>✕</Text>
          </TouchableOpacity>
        </View>
        
        <ScrollView style={styles.filterContainer}>
          <View style={styles.filterGroup}>
            <Text style={styles.filterLabel}>Max Price</Text>
            <TextInput
              style={styles.filterInput}
              placeholder="Enter max price"
              value={filters.maxPrice}
              onChangeText={(text) => setFilters({...filters, maxPrice: text})}
              keyboardType="numeric"
            />
          </View>
          
          <View style={styles.filterGroup}>
            <Text style={styles.filterLabel}>Min Price</Text>
            <TextInput
              style={styles.filterInput}
              placeholder="Enter min price"
              value={filters.minPrice}
              onChangeText={(text) => setFilters({...filters, minPrice: text})}
              keyboardType="numeric"
            />
          </View>
          
          <View style={styles.filterGroup}>
            <Text style={styles.filterLabel}>City</Text>
            <TextInput
              style={styles.filterInput}
              placeholder="Enter city"
              value={filters.city}
              onChangeText={(text) => setFilters({...filters, city: text})}
            />
          </View>
          
          <View style={styles.filterGroup}>
            <Text style={styles.filterLabel}>Property Type</Text>
            <View style={styles.typeButtonsContainer}>
              {['House', 'Apartment', 'Condo', 'Studio', 'Basement'].map(type => (
                <TouchableOpacity
                  key={type}
                  style={[
                    styles.typeButton,
                    filters.houseType === type && styles.typeButtonActive
                  ]}
                  onPress={() => setFilters({
                    ...filters,
                    houseType: filters.houseType === type ? '' : type
                  })}
                >
                  <Text style={[
                    styles.typeButtonText,
                    filters.houseType === type && styles.typeButtonTextActive
                  ]}>
                    {type}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>
          
          <View style={styles.filterGroup}>
            <Text style={styles.filterLabel}>Bedrooms</Text>
            <View style={styles.typeButtonsContainer}>
              {[1, 2, 3, 4, 5].map(num => (
                <TouchableOpacity
                  key={num}
                  style={[
                    styles.typeButton,
                    filters.bedrooms === num.toString() && styles.typeButtonActive
                  ]}
                  onPress={() => setFilters({
                    ...filters,
                    bedrooms: filters.bedrooms === num.toString() ? '' : num.toString()
                  })}
                >
                  <Text style={[
                    styles.typeButtonText,
                    filters.bedrooms === num.toString() && styles.typeButtonTextActive
                  ]}>
                    {num}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>
        </ScrollView>
        
        <View style={styles.modalFooter}>
          <TouchableOpacity style={styles.clearButton} onPress={() => setFilters({})}>
            <Text style={styles.clearButtonText}>Clear All</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.applyButton} onPress={onApply}>
            <Text style={styles.applyButtonText}>Apply Filters</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  </Modal>
);

// Screens
const HomeScreen = ({ navigation }) => {
  const { properties, setProperties, user } = useApp();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [filters, setFilters] = useState({});
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    loadProperties();
  }, []);

  const loadProperties = async () => {
    try {
      setLoading(true);
      const data = await supabaseService.getListings({
        filters: {
          ...filters,
          excludeUserEmail: user?.email
        }
      });
      setProperties(data);
    } catch (error) {
      console.error('Error loading properties:', error);
      Alert.alert('Error', 'Failed to load properties. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadProperties();
    setRefreshing(false);
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      loadProperties();
      return;
    }

    try {
      setLoading(true);
      const data = await supabaseService.searchListings(searchQuery, {
        ...filters,
        excludeUserEmail: user?.email
      });
      setProperties(data);
    } catch (error) {
      console.error('Error searching properties:', error);
      Alert.alert('Error', 'Failed to search properties. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const applyFilters = async () => {
    setShowFilters(false);
    try {
      setLoading(true);
      let data;
      
      if (searchQuery.trim()) {
        data = await supabaseService.searchListings(searchQuery, {
          ...filters,
          excludeUserEmail: user?.email
        });
      } else {
        data = await supabaseService.getListings({
          filters: {
            ...filters,
            excludeUserEmail: user?.email
          }
        });
      }
      
      setProperties(data);
    } catch (error) {
      console.error('Error applying filters:', error);
      Alert.alert('Error', 'Failed to apply filters. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handlePropertyPress = (property) => {
    navigation.navigate('PropertyDetail', { property });
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#fff" />
      
      <View style={styles.header}>
        <Text style={styles.headerTitle}>RoomFinder AI</Text>
        <Text style={styles.headerSubtitle}>Find your perfect room</Text>
      </View>

      <SearchBar
        value={searchQuery}
        onChangeText={setSearchQuery}
        onSubmit={handleSearch}
      />

      <View style={styles.filterBar}>
        <TouchableOpacity
          style={styles.filterButton}
          onPress={() => setShowFilters(true)}
        >
          <Text style={styles.filterButtonText}>
            Filters {Object.keys(filters).length > 0 && `(${Object.keys(filters).length})`}
          </Text>
        </TouchableOpacity>
        
        <Text style={styles.resultsText}>
          {properties.length} properties found
        </Text>
      </View>

      {loading ? (
        <LoadingSpinner message="Loading properties..." />
      ) : properties.length === 0 ? (
        <EmptyState
          message="No properties found. Try adjusting your search criteria."
          onRefresh={loadProperties}
        />
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
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
          }
        />
      )}

      <FilterModal
        visible={showFilters}
        onClose={() => setShowFilters(false)}
        onApply={applyFilters}
        filters={filters}
        setFilters={setFilters}
      />
    </SafeAreaView>
  );
};

const PropertyDetailScreen = ({ route, navigation }) => {
  const { property } = route.params;

  const handleContactOwner = () => {
    Alert.alert(
      'Contact Owner',
      `Would you like to contact the owner of "${property.title}"?`,
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Email', onPress: () => handleEmailOwner() },
        { text: 'AI Chat', onPress: () => handleAIChat() },
      ]
    );
  };

  const handleEmailOwner = () => {
    Alert.alert('Email', `Contact: ${property.user_email}`);
  };

  const handleAIChat = () => {
    navigation.navigate('AIChat', { 
      initialMessage: `I'm interested in your property: ${property.title}. Can you provide more details?`,
      propertyId: property.id 
    });
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.detailContainer}>
        <Image
          source={{ 
            uri: property.media && property.media.length > 0 
              ? (typeof property.media[0] === 'string' ? property.media[0] : property.media[0].url)
              : 'https://via.placeholder.com/400x300?text=No+Image'
          }}
          style={styles.detailImage}
          resizeMode="cover"
        />
        
        <View style={styles.detailContent}>
          <View style={styles.detailHeader}>
            <Text style={styles.detailTitle}>{property.title}</Text>
            <Text style={styles.detailPrice}>
              {supabaseService.formatPrice(property.price)}/month
            </Text>
          </View>
          
          <Text style={styles.detailLocation}>
            📍 {property.city}
            {property.street && ` • ${property.street}`}
            {property.postal_code && ` • ${property.postal_code}`}
          </Text>
          
          <View style={styles.detailFeatures}>
            <View style={styles.featureItem}>
              <Text style={styles.featureLabel}>Bedrooms</Text>
              <Text style={styles.featureValue}>{property.bedrooms || 0}</Text>
            </View>
            <View style={styles.featureItem}>
              <Text style={styles.featureLabel}>Type</Text>
              <Text style={styles.featureValue}>{property.house_type || 'N/A'}</Text>
            </View>
            <View style={styles.featureItem}>
              <Text style={styles.featureLabel}>Utilities</Text>
              <Text style={styles.featureValue}>{property.utilities || 'N/A'}</Text>
            </View>
          </View>
          
          <View style={styles.descriptionSection}>
            <Text style={styles.sectionTitle}>Description</Text>
            <Text style={styles.detailDescription}>
              {property.description || 'No description available.'}
            </Text>
          </View>
          
          <View style={styles.contactSection}>
            <Text style={styles.sectionTitle}>Contact Information</Text>
            <Text style={styles.contactText}>Owner: {property.user_email}</Text>
            <Text style={styles.contactText}>
              Listed: {supabaseService.formatDate(property.created_at)}
            </Text>
          </View>
          
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

const AIChatScreen = ({ route, navigation }) => {
  const { chatMessages, setChatMessages, user } = useApp();
  const [inputText, setInputText] = useState('');
  const [loading, setLoading] = useState(false);
  const [initialLoading, setInitialLoading] = useState(true);

  // Handle initial message from property detail
  const initialMessage = route?.params?.initialMessage;
  const propertyId = route?.params?.propertyId;

  useEffect(() => {
    loadChatHistory();
  }, []);

  useEffect(() => {
    if (initialMessage && chatMessages.length === 0) {
      setTimeout(() => {
        handleSendMessage(initialMessage);
      }, 1000);
    }
  }, [initialMessage, chatMessages]);

  const loadChatHistory = async () => {
    try {
      setInitialLoading(true);
      if (user?.email) {
        const history = await supabaseService.getAIChatHistory(user.email);
        setChatMessages(history);
      }
    } catch (error) {
      console.error('Error loading chat history:', error);
    } finally {
      setInitialLoading(false);
    }
  };

  const handleSendMessage = async (messageText = null) => {
    const message = messageText || inputText.trim();
    if (!message || loading) return;

    setInputText('');
    setLoading(true);

    try {
      // Add user message to local state immediately
      const userMessage = {
        id: Date.now().toString(),
        role: 'user',
        message,
        created_at: new Date().toISOString()
      };
      
      setChatMessages(prev => [...prev, userMessage]);

      // Send to AI and get response
      const aiResponse = await supabaseService.sendAIMessage(
        message,
        user?.email || 'anonymous@user.com',
        chatMessages
      );

      // Add AI response to local state
      const aiMessage = {
        id: (Date.now() + 1).toString(),
        role: 'ai',
        message: aiResponse,
        created_at: new Date().toISOString()
      };
      
      setChatMessages(prev => [...prev, aiMessage]);

    } catch (error) {
      console.error('Error sending message:', error);
      Alert.alert('Error', 'Failed to send message. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const renderMessage = ({ item }) => (
    <View style={[
      styles.chatMessage,
      item.role === 'user' ? styles.userMessage : styles.aiMessage
    ]}>
      <Text style={[
        styles.chatMessageText,
        item.role === 'user' ? styles.userMessageText : styles.aiMessageText
      ]}>
        {item.message}
      </Text>
      <Text style={styles.chatTimestamp}>
        {new Date(item.created_at).toLocaleTimeString([], {
          hour: '2-digit',
          minute: '2-digit'
        })}
      </Text>
    </View>
  );

  if (initialLoading) {
    return (
      <SafeAreaView style={styles.container}>
        <LoadingSpinner message="Loading chat..." />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView 
        style={styles.chatContainer}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <View style={styles.chatHeader}>
          <Text style={styles.chatHeaderTitle}>AI Assistant</Text>
          <Text style={styles.chatHeaderSubtitle}>
            Get help finding the perfect property
          </Text>
        </View>

        <FlatList
          data={chatMessages}
          keyExtractor={(item) => item.id}
          renderItem={renderMessage}
          contentContainerStyle={styles.chatMessages}
          showsVerticalScrollIndicator={false}
        />
        
        {loading && (
          <View style={styles.typingIndicator}>
            <ActivityIndicator size="small" color="#007AFF" />
            <Text style={styles.typingText}>AI is thinking...</Text>
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
            editable={!loading}
          />
          <TouchableOpacity
            style={[styles.sendButton, loading && styles.sendButtonDisabled]}
            onPress={() => handleSendMessage()}
            disabled={!inputText.trim() || loading}
          >
            <Text style={styles.sendButtonText}>Send</Text>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

const LoginScreen = ({ navigation }) => {
  const { login } = useApp();
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
      await login(email, password);
      navigation.navigate('Main');
    } catch (error) {
      console.error('Login error:', error);
      Alert.alert('Error', 'Login failed. Please check your credentials and try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleGuestLogin = async () => {
    try {
      setLoading(true);
      // For demo purposes, create a guest session
      // In production, you might want to handle this differently
      navigation.navigate('Main');
    } catch (error) {
      console.error('Guest login error:', error);
      Alert.alert('Error', 'Failed to continue as guest');
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView style={styles.loginContainer} behavior="padding">
        <View style={styles.loginHeader}>
          <Text style={styles.loginTitle}>Welcome to RoomFinder AI</Text>
          <Text style={styles.loginSubtitle}>Find your perfect room with AI assistance</Text>
        </View>
        
        <View style={styles.loginForm}>
          <TextInput
            style={styles.input}
            placeholder="Email"
            value={email}
            onChangeText={setEmail}
            autoCapitalize="none"
            keyboardType="email-address"
            editable={!loading}
          />
          
          <TextInput
            style={styles.input}
            placeholder="Password"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            editable={!loading}
          />
          
          <TouchableOpacity
            style={[styles.loginButton, loading && styles.loginButtonDisabled]}
            onPress={handleLogin}
            disabled={loading}
          >
            {loading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.loginButtonText}>Sign In</Text>
            )}
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.guestButton}
            onPress={handleGuestLogin}
            disabled={loading}
          >
            <Text style={styles.guestButtonText}>Continue as Guest</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.forgotPassword}>
            <Text style={styles.forgotPasswordText}>Forgot Password?</Text>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

const ProfileScreen = () => {
  const { user, logout } = useApp();
  const [userListings, setUserListings] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (user?.email) {
      loadUserListings();
    }
  }, [user]);

  const loadUserListings = async () => {
    try {
      setLoading(true);
      const listings = await supabaseService.getUserListings(user.email);
      setUserListings(listings);
    } catch (error) {
      console.error('Error loading user listings:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    Alert.alert(
      'Logout',
      'Are you sure you want to logout?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Logout', onPress: logout },
      ]
    );
  };

  if (!user) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.guestProfileContainer}>
          <Text style={styles.guestProfileText}>Please sign in to view your profile</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.profileContainer}>
        <View style={styles.profileHeader}>
          <Image
            source={{ uri: user.profile_image || supabaseService.getDefaultProfileImage() }}
            style={styles.profileAvatar}
            resizeMode="cover"
          />
          <Text style={styles.profileName}>
            {user.first_name && user.last_name 
              ? `${user.first_name} ${user.last_name}`
              : user.email
            }
          </Text>
          <Text style={styles.profileEmail}>{user.email}</Text>
        </View>
        
        <View style={styles.profileStats}>
          <View style={styles.statItem}>
            <Text style={styles.statNumber}>{userListings.length}</Text>
            <Text style={styles.statLabel}>Properties Listed</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statNumber}>0</Text>
            <Text style={styles.statLabel}>Messages</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statNumber}>0</Text>
            <Text style={styles.statLabel}>Favorites</Text>
          </View>
        </View>

        <View style={styles.profileSection}>
          <Text style={styles.sectionTitle}>Your Listings</Text>
          {loading ? (
            <LoadingSpinner message="Loading your listings..." />
          ) : userListings.length === 0 ? (
            <Text style={styles.emptyText}>You haven't listed any properties yet.</Text>
          ) : (
            userListings.map((listing) => (
              <View key={listing.id} style={styles.listingItem}>
                <Text style={styles.listingTitle}>{listing.title}</Text>
                <Text style={styles.listingDetails}>
                  {listing.city} • {supabaseService.formatPrice(listing.price)}/month
                </Text>
                <Text style={styles.listingDate}>
                  Listed: {supabaseService.formatDate(listing.created_at)}
                </Text>
              </View>
            ))
          )}
        </View>
        
        <View style={styles.profileActions}>
          <TouchableOpacity style={styles.profileActionButton}>
            <Text style={styles.profileActionText}>Edit Profile</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.profileActionButton}>
            <Text style={styles.profileActionText}>Settings</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.profileActionButton}>
            <Text style={styles.profileActionText}>Help & Support</Text>
          </TouchableOpacity>
        </View>
        
        <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
          <Text style={styles.logoutButtonText}>Logout</Text>
        </TouchableOpacity>
      </ScrollView>
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
        headerTintColor: '#007AFF',
      }}
    />
    <Stack.Screen 
      name="AIChat" 
      component={AIChatScreen} 
      options={{ 
        title: 'AI Assistant',
        headerBackTitle: 'Back',
        headerTintColor: '#007AFF',
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
      name="AIChat" 
      component={AIChatScreen} 
      options={{ title: 'AI Chat' }}
    />
    <Tab.Screen 
      name="Profile" 
      component={ProfileScreen} 
      options={{ title: 'Profile' }}
    />
  </Tab.Navigator>
);

const App = () => {
  return (
    <AppProvider>
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
    </AppProvider>
  );
};

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
    paddingBottom: 10,
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
  filterBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingBottom: 10,
  },
  filterButton: {
    backgroundColor: '#f0f0f0',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
  },
  filterButtonText: {
    fontSize: 14,
    color: '#007AFF',
    fontWeight: '500',
  },
  resultsText: {
    fontSize: 14,
    color: '#8e8e93',
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
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  emptyText: {
    fontSize: 16,
    color: '#8e8e93',
    textAlign: 'center',
    marginBottom: 20,
  },
  refreshButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 8,
  },
  refreshButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  propertiesList: {
    paddingHorizontal: 20,
    paddingBottom: 20,
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
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#1d1d1f',
    marginBottom: 10,
  },
  descriptionSection: {
    marginBottom: 20,
  },
  detailDescription: {
    fontSize: 16,
    color: '#1d1d1f',
    lineHeight: 24,
  },
  contactSection: {
    marginBottom: 30,
  },
  contactText: {
    fontSize: 16,
    color: '#8e8e93',
    marginBottom: 4,
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
  chatHeader: {
    padding: 20,
    paddingBottom: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  chatHeaderTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#1d1d1f',
  },
  chatHeaderSubtitle: {
    fontSize: 14,
    color: '#8e8e93',
    marginTop: 4,
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
    marginBottom: 4,
  },
  userMessageText: {
    color: '#fff',
  },
  aiMessageText: {
    color: '#1d1d1f',
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
  sendButtonDisabled: {
    backgroundColor: '#ccc',
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
  loginHeader: {
    alignItems: 'center',
    marginBottom: 40,
  },
  loginTitle: {
    fontSize: 28,
    fontWeight: '700',
    color: '#1d1d1f',
    textAlign: 'center',
    marginBottom: 8,
  },
  loginSubtitle: {
    fontSize: 16,
    color: '#8e8e93',
    textAlign: 'center',
  },
  loginForm: {
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
  loginButtonDisabled: {
    backgroundColor: '#ccc',
  },
  loginButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
  guestButton: {
    backgroundColor: '#f0f0f0',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    marginBottom: 16,
  },
  guestButtonText: {
    color: '#007AFF',
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
  guestProfileContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  guestProfileText: {
    fontSize: 16,
    color: '#8e8e93',
    textAlign: 'center',
  },
  profileContainer: {
    flex: 1,
    padding: 20,
  },
  profileHeader: {
    alignItems: 'center',
    marginBottom: 30,
  },
  profileAvatar: {
    width: 100,
    height: 100,
    borderRadius: 50,
    marginBottom: 16,
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
  profileStats: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    backgroundColor: '#f8f9fa',
    borderRadius: 12,
    padding: 20,
    marginBottom: 30,
  },
  statItem: {
    alignItems: 'center',
  },
  statNumber: {
    fontSize: 24,
    fontWeight: '700',
    color: '#007AFF',
  },
  statLabel: {
    fontSize: 14,
    color: '#8e8e93',
    marginTop: 4,
  },
  profileSection: {
    marginBottom: 30,
  },
  listingItem: {
    backgroundColor: '#f8f9fa',
    padding: 16,
    borderRadius: 12,
    marginBottom: 10,
  },
  listingTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1d1d1f',
  },
  listingDetails: {
    fontSize: 14,
    color: '#8e8e93',
    marginTop: 4,
  },
  listingDate: {
    fontSize: 12,
    color: '#8e8e93',
    marginTop: 4,
  },
  profileActions: {
    marginBottom: 30,
  },
  profileActionButton: {
    backgroundColor: '#f8f9fa',
    paddingVertical: 16,
    paddingHorizontal: 20,
    borderRadius: 12,
    marginBottom: 10,
  },
  profileActionText: {
    fontSize: 16,
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
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: screenHeight * 0.8,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#1d1d1f',
  },
  modalCloseButton: {
    fontSize: 24,
    color: '#8e8e93',
  },
  filterContainer: {
    padding: 20,
  },
  filterGroup: {
    marginBottom: 20,
  },
  filterLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1d1d1f',
    marginBottom: 10,
  },
  filterInput: {
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    backgroundColor: '#f8f9fa',
  },
  typeButtonsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  typeButton: {
    backgroundColor: '#f0f0f0',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  typeButtonActive: {
    backgroundColor: '#007AFF',
  },
  typeButtonText: {
    fontSize: 14,
    color: '#1d1d1f',
  },
  typeButtonTextActive: {
    color: '#fff',
  },
  modalFooter: {
    flexDirection: 'row',
    padding: 20,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
    gap: 10,
  },
  clearButton: {
    flex: 1,
    backgroundColor: '#f0f0f0',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  clearButtonText: {
    fontSize: 16,
    color: '#8e8e93',
    fontWeight: '600',
  },
  applyButton: {
    flex: 1,
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  applyButtonText: {
    fontSize: 16,
    color: '#fff',
    fontWeight: '600',
  },
});

export default App;