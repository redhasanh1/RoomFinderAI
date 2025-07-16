import axios from 'axios';
import {Alert} from 'react-native';

// Create axios instance with default configuration
const apiClient = axios.create({
  baseURL: 'https://api.example.com', // Replace with your API base URL
  timeout: 10000, // 10 second timeout
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
});

// Request interceptor to add authentication token
apiClient.interceptors.request.use(
  (config) => {
    // Add auth token if available
    const token = ''; // Get from AsyncStorage or secure storage
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    
    console.log('API Request:', config.method?.toUpperCase(), config.url);
    return config;
  },
  (error) => {
    console.error('Request Error:', error);
    return Promise.reject(error);
  }
);

// Response interceptor to handle errors globally
apiClient.interceptors.response.use(
  (response) => {
    console.log('API Response:', response.status, response.config.url);
    return response;
  },
  (error) => {
    console.error('Response Error:', error);
    
    // Handle different error types
    if (error.code === 'ECONNABORTED') {
      Alert.alert('Timeout', 'Request timed out. Please try again.');
    } else if (error.response?.status === 401) {
      Alert.alert('Authentication Error', 'Please login again.');
    } else if (error.response?.status === 403) {
      Alert.alert('Permission Denied', 'You do not have permission to access this resource.');
    } else if (error.response?.status >= 500) {
      Alert.alert('Server Error', 'Something went wrong on our end. Please try again later.');
    } else if (!error.response) {
      Alert.alert('Network Error', 'Please check your internet connection.');
    }
    
    return Promise.reject(error);
  }
);

// API Service class
class ApiService {
  // Room-related API calls
  static async getRooms() {
    try {
      const response = await apiClient.get('/rooms');
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  static async getRoomById(id) {
    try {
      const response = await apiClient.get(`/rooms/${id}`);
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  static async createRoom(roomData) {
    try {
      const response = await apiClient.post('/rooms', roomData);
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  static async updateRoom(id, roomData) {
    try {
      const response = await apiClient.put(`/rooms/${id}`, roomData);
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  static async deleteRoom(id) {
    try {
      const response = await apiClient.delete(`/rooms/${id}`);
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  // Booking-related API calls
  static async bookRoom(roomId, bookingData) {
    try {
      const response = await apiClient.post(`/rooms/${roomId}/book`, bookingData);
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  static async getBookings(roomId) {
    try {
      const response = await apiClient.get(`/rooms/${roomId}/bookings`);
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  // User authentication
  static async login(credentials) {
    try {
      const response = await apiClient.post('/auth/login', credentials);
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  static async register(userData) {
    try {
      const response = await apiClient.post('/auth/register', userData);
      return response.data;
    } catch (error) {
      throw error;
    }
  }

  // Generic API call method
  static async makeRequest(method, endpoint, data = null) {
    try {
      const response = await apiClient({
        method,
        url: endpoint,
        data,
      });
      return response.data;
    } catch (error) {
      throw error;
    }
  }
}

export default ApiService;