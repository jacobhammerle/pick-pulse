import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { PicksProvider } from '../lib/picks-context';
import { colors } from '../lib/theme';

export default function RootLayout() {
  return (
    <PicksProvider>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: colors.bg },
          headerTintColor: colors.text,
          headerTitleStyle: { fontWeight: '700' },
          contentStyle: { backgroundColor: colors.bg },
        }}
      >
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen
          name="slip"
          options={{ title: 'Your Slip', presentation: 'modal' }}
        />
      </Stack>
    </PicksProvider>
  );
}
