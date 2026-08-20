import { Tabs } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Text } from 'react-native';
import { colors } from '../../lib/theme';

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerStyle: { backgroundColor: colors.bg },
        headerTintColor: colors.text,
        headerTitleStyle: { fontWeight: '700' },
        tabBarStyle: { backgroundColor: colors.card, borderTopColor: colors.cardBorder },
        tabBarActiveTintColor: colors.accent,
        tabBarInactiveTintColor: colors.textDim,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'PickPulse',
          tabBarLabel: 'Home',
          tabBarIcon: ({ color, size }) => (
            <SymbolView
              name="house.fill"
              size={size}
              tintColor={color}
              fallback={<Text style={{ color, fontSize: size }}>🏠</Text>}
            />
          ),
        }}
      />
      <Tabs.Screen
        name="preview"
        options={{
          title: 'Settings',
          tabBarLabel: 'Settings',
          tabBarIcon: ({ color, size }) => (
            <SymbolView
              name="gearshape.fill"
              size={size}
              tintColor={color}
              fallback={<Text style={{ color, fontSize: size }}>⚙️</Text>}
            />
          ),
        }}
      />
    </Tabs>
  );
}
