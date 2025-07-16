# Capacitor to React Native Migration Guide

## Quick Start Commands

### 1. Remove Capacitor
```bash
# Run the removal script
./remove-capacitor.sh

# Or manually remove dependencies
npm uninstall @capacitor/core @capacitor/cli @capacitor/ios @capacitor/android
rm -rf ios/ android/ capacitor.config.json .capacitor/
```

### 2. Set Up React Native
```bash
# Create new React Native project
npx react-native@latest init RoomFinderAI --version 0.73.6

# Install dependencies
cd RoomFinderAI
npm install axios react-native-vector-icons @react-navigation/native @react-navigation/native-stack @react-navigation/bottom-tabs react-native-screens react-native-safe-area-context

# iOS setup
cd ios && pod install && cd ..
```

### 3. Run the App
```bash
# iOS Simulator
npx react-native run-ios

# iOS Device
npx react-native run-ios --device "Your iPhone Name"

# Reset cache if needed
npx react-native start --reset-cache
```

## Component Migration Map

### HTML to React Native Components
```jsx
// OLD (Capacitor/Web)
<div className="container">
  <h1>Title</h1>
  <p>Description</p>
  <button onClick={handleClick}>Click Me</button>
  <input type="text" value={text} onChange={handleChange} />
</div>

// NEW (React Native)
<View style={styles.container}>
  <Text style={styles.title}>Title</Text>
  <Text style={styles.description}>Description</Text>
  <TouchableOpacity style={styles.button} onPress={handleClick}>
    <Text style={styles.buttonText}>Click Me</Text>
  </TouchableOpacity>
  <TextInput
    style={styles.input}
    value={text}
    onChangeText={handleChange}
  />
</View>
```

### Navigation Migration
```jsx
// OLD (React Router)
import { BrowserRouter, Route, Routes } from 'react-router-dom';

// NEW (React Navigation)
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

const Stack = createNativeStackNavigator();

function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen name="Home" component={HomeScreen} />
        <Stack.Screen name="Details" component={DetailsScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
```

### API Calls Migration
```jsx
// OLD (Capacitor HTTP)
import { CapacitorHttp } from '@capacitor/core';

const response = await CapacitorHttp.get({
  url: 'https://api.example.com/data'
});

// NEW (Axios)
import axios from 'axios';

const response = await axios.get('https://api.example.com/data');
```

## State Management Migration

### React Hooks (Same for both)
```jsx
// No changes needed for useState, useEffect, etc.
const [data, setData] = useState([]);
const [loading, setLoading] = useState(false);

useEffect(() => {
  fetchData();
}, []);
```

### Redux Migration
```jsx
// OLD (Web Redux)
import { createStore } from 'redux';
import { Provider } from 'react-redux';

// NEW (React Native Redux) - Same code!
import { createStore } from 'redux';
import { Provider } from 'react-redux';

// Redux works identically in React Native
```

## Styling Migration

### CSS to StyleSheet
```jsx
// OLD (CSS)
.container {
  display: flex;
  flex-direction: column;
  padding: 20px;
  background-color: #f0f0f0;
}

.button {
  background-color: #007AFF;
  color: white;
  padding: 16px;
  border-radius: 8px;
  text-align: center;
}

// NEW (StyleSheet)
const styles = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'column',
    padding: 20,
    backgroundColor: '#f0f0f0',
  },
  button: {
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    paddingHorizontal: 20,
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
});
```

## iOS-Specific Configurations

### Info.plist Updates
```xml
<!-- Add these permissions for network access -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>api.example.com</key>
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key>
      <true/>
    </dict>
  </dict>
</dict>

<!-- Add other permissions as needed -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses location to find nearby rooms</string>
```

### Xcode Project Setup
1. Open `ios/RoomFinderAI.xcworkspace` in Xcode
2. Select your target → General → Identity
3. Set Bundle Identifier (e.g., `com.yourcompany.roomfinder`)
4. Set Team for code signing
5. Set Deployment Target to iOS 14.0+

## Troubleshooting Common Issues

### 1. Metro Bundler Issues
```bash
# Clear Metro cache
npx react-native start --reset-cache

# Clear React Native cache
npx react-native-clean-project

# Delete node_modules and reinstall
rm -rf node_modules
npm install
```

### 2. iOS Build Errors
```bash
# Clean iOS build
cd ios && xcodebuild clean && cd ..

# Reinstall pods
cd ios && rm -rf Pods/ Podfile.lock && pod install && cd ..

# Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### 3. API Connection Issues
```jsx
// Check network permissions in Info.plist
// Use proper error handling
const fetchData = async () => {
  try {
    const response = await axios.get('https://api.example.com/data', {
      timeout: 10000,
    });
    return response.data;
  } catch (error) {
    if (error.code === 'ECONNABORTED') {
      throw new Error('Request timeout');
    } else if (!error.response) {
      throw new Error('Network error');
    } else {
      throw new Error(`API error: ${error.response.status}`);
    }
  }
};
```

### 4. Navigation Issues
```jsx
// Ensure NavigationContainer wraps your entire app
import { NavigationContainer } from '@react-navigation/native';

function App() {
  return (
    <NavigationContainer>
      {/* Your navigation stack */}
    </NavigationContainer>
  );
}

// Use proper navigation prop
const HomeScreen = ({ navigation }) => {
  const goToDetails = () => {
    navigation.navigate('Details', { roomId: '123' });
  };
  
  return (
    <TouchableOpacity onPress={goToDetails}>
      <Text>Go to Details</Text>
    </TouchableOpacity>
  );
};
```

### 5. Vector Icons Issues
```bash
# iOS setup for react-native-vector-icons
cd ios && pod install && cd ..

# If icons don't appear, add to Info.plist
<key>UIAppFonts</key>
<array>
  <string>Ionicons.ttf</string>
</array>
```

### 6. Safe Area Issues
```jsx
// Use SafeAreaView from react-native-safe-area-context
import { SafeAreaView } from 'react-native-safe-area-context';

const Screen = () => (
  <SafeAreaView style={{ flex: 1 }}>
    {/* Your content */}
  </SafeAreaView>
);
```

## Testing Your Migration

### 1. Test on iOS Simulator
```bash
npx react-native run-ios --simulator="iPhone 15"
```

### 2. Test on Physical Device
```bash
# List available devices
xcrun xctrace list devices

# Run on specific device
npx react-native run-ios --device "Your iPhone Name"
```

### 3. Test API Calls
- Use network inspector in React Native Debugger
- Check API endpoints work with proper headers
- Test error handling and timeouts

### 4. Test Navigation
- Test deep linking
- Test back navigation
- Test tab navigation

## Performance Optimization

### 1. Bundle Size
```bash
# Analyze bundle size
npx react-native bundle --platform ios --dev false --entry-file index.js --bundle-output ios/main.jsbundle --sourcemap-output ios/main.jsbundle.map
```

### 2. Images
```jsx
// Use proper image formats
import { Image } from 'react-native';

// Local images
<Image source={require('./images/logo.png')} />

// Remote images with caching
<Image source={{ uri: 'https://example.com/image.jpg' }} />
```

### 3. Memory Management
```jsx
// Properly clean up listeners
useEffect(() => {
  const subscription = someListener();
  
  return () => {
    subscription.remove();
  };
}, []);
```

## Final Checklist

- [ ] Remove all Capacitor dependencies
- [ ] Convert HTML components to React Native
- [ ] Update navigation to React Navigation
- [ ] Convert CSS to StyleSheet
- [ ] Test API calls with proper error handling
- [ ] Configure iOS permissions in Info.plist
- [ ] Test on iOS simulator and device
- [ ] Verify native modules work correctly
- [ ] Test app performance and memory usage
- [ ] Submit to App Store (if ready)

## Additional Resources

- [React Native Documentation](https://reactnative.dev/)
- [React Navigation Documentation](https://reactnavigation.org/)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [React Native Vector Icons](https://github.com/oblador/react-native-vector-icons)