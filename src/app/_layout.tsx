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
        <Stack.Screen name="index" options={{ title: 'PickPulse' }} />
        <Stack.Screen
          name="slip"
          options={{ title: 'Your Slip', presentation: 'modal' }}
        />
        <Stack.Screen name="preview" options={{ title: 'Preview Channel' }} />
      </Stack>
    </PicksProvider>
  );
}
