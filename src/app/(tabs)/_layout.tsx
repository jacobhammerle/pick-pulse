import { Tabs } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { colors } from '../../lib/theme';

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.accent,
        tabBarInactiveTintColor: colors.textDim,
        tabBarStyle: {
          backgroundColor: colors.bg,
          borderTopColor: colors.cardBorder,
        },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Board',
          tabBarIcon: ({ color, size }) => (
            <SymbolView name="list.bullet" tintColor={color} size={size} />
          ),
        }}
      />
      <Tabs.Screen
        name="preview"
        options={{
          title: 'Admin',
          tabBarIcon: ({ color, size }) => (
            <SymbolView name="gearshape.fill" tintColor={color} size={size} />
          ),
        }}
      />
    </Tabs>
  );
}
