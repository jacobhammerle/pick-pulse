import { Tabs } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Text } from 'react-native';
import { colors } from '../../lib/theme';

function TabIcon({
  ios,
  android,
  focused,
  fallback,
}: {
  ios: 'house.fill' | 'gearshape.fill';
  android: 'home_filled' | 'settings';
  focused: boolean;
  fallback: string;
}) {
  return (
    <SymbolView
      name={{ ios, android, web: android }}
      tintColor={focused ? colors.accent : colors.textDim}
      size={24}
      fallback={<Text style={{ fontSize: 20 }}>{fallback}</Text>}
    />
  );
}

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerStyle: { backgroundColor: colors.bg },
        headerTintColor: colors.text,
        headerTitleStyle: { fontWeight: '700' },
        tabBarStyle: { backgroundColor: colors.bg, borderTopColor: colors.cardBorder },
        tabBarActiveTintColor: colors.accent,
        tabBarInactiveTintColor: colors.textDim,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Home',
          headerShown: false,
          tabBarIcon: ({ focused }) => (
            <TabIcon ios="house.fill" android="home_filled" focused={focused} fallback="⌂" />
          ),
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: 'Settings',
          tabBarIcon: ({ focused }) => (
            <TabIcon ios="gearshape.fill" android="settings" focused={focused} fallback="⚙︎" />
          ),
        }}
      />
    </Tabs>
  );
}
