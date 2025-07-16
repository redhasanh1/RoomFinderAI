import React from 'react';
import {NavigationContainer} from '@react-navigation/native';
import {createNativeStackNavigator} from '@react-navigation/native-stack';
import HomeScreen from './src/screens/HomeScreen';
import DetailsScreen from './src/screens/DetailsScreen';

const Stack = createNativeStackNavigator();

function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator
        screenOptions={{
          headerStyle: {
            backgroundColor: '#007AFF', // iOS Blue
          },
          headerTintColor: '#FFFFFF',
          headerTitleStyle: {
            fontFamily: 'SF Pro Display', // iOS system font
            fontWeight: '600',
          },
          headerLargeTitle: true, // iOS 11+ large title style
        }}>
        <Stack.Screen 
          name="Home" 
          component={HomeScreen}
          options={{
            title: 'Room Finder',
            headerLargeTitle: true,
          }}
        />
        <Stack.Screen 
          name="Details" 
          component={DetailsScreen}
          options={{
            title: 'Room Details',
          }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

export default App;