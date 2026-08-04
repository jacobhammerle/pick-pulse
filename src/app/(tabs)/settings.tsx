import { useState } from 'react';
import {
  Alert,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { getUpdateInfo, resetChannelAsync, switchChannelAsync } from '../../lib/channel';
import { colors } from '../../lib/theme';

/**
 * Settings screen. Includes channel surfing: during the demo, enter
 * the PR channel name posted on the pull request (for example,
 * "pr-4") to preview that update in this installed build.
 */
export default function SettingsScreen() {
  const [channel, setChannel] = useState('');
  const [busy, setBusy] = useState(false);
  const info = getUpdateInfo();

  const surf = async () => {
    const target = channel.trim();
    if (!target) return;
    setBusy(true);
    try {
      await switchChannelAsync(target);
    } catch (e) {
      Alert.alert(
        'Could not switch channel',
        e instanceof Error ? e.message : 'Updates are unavailable in dev builds.'
      );
    } finally {
      setBusy(false);
    }
  };

  const reset = async () => {
    setBusy(true);
    try {
      await resetChannelAsync();
    } catch (e) {
      Alert.alert(
        'Could not reset channel',
        e instanceof Error ? e.message : 'Updates are unavailable in dev builds.'
      );
    } finally {
      setBusy(false);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.label}>Current state</Text>
      <View style={styles.infoBox}>
        <Text style={styles.infoText}>Channel: {info.channel || '(none)'}</Text>
        <Text style={styles.infoText}>Runtime: {info.runtimeVersion || '(none)'}</Text>
        <Text style={styles.infoText}>
          Update: {info.isEmbedded ? 'embedded bundle' : info.updateId}
        </Text>
        <Text style={styles.infoText}>
          Updates enabled: {info.isEnabled ? 'yes' : 'no'}
        </Text>
      </View>

      <Text style={styles.label}>Surf to a channel</Text>
      <TextInput
        testID="channel-input"
        style={styles.input}
        value={channel}
        onChangeText={setChannel}
        placeholder="pr-4"
        placeholderTextColor={colors.textDim}
        autoCapitalize="none"
        autoCorrect={false}
      />
      <Pressable
        testID="surf-button"
        style={[styles.button, busy && styles.buttonDisabled]}
        disabled={busy}
        onPress={surf}
      >
        <Text style={styles.buttonText}>{busy ? 'Switching…' : 'Switch channel'}</Text>
      </Pressable>
      <Pressable
        testID="reset-button"
        style={[styles.buttonSecondary, busy && styles.buttonDisabled]}
        disabled={busy}
        onPress={reset}
      >
        <Text style={styles.buttonSecondaryText}>Reset to build channel</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg, padding: 16 },
  label: {
    color: colors.textDim,
    fontSize: 13,
    fontWeight: '600',
    marginTop: 16,
    marginBottom: 8,
  },
  infoBox: {
    backgroundColor: colors.card,
    borderColor: colors.cardBorder,
    borderWidth: 1,
    borderRadius: 12,
    padding: 14,
    gap: 4,
  },
  infoText: { color: colors.text, fontSize: 13, fontFamily: 'Menlo' },
  input: {
    backgroundColor: colors.card,
    borderColor: colors.cardBorder,
    borderWidth: 1,
    borderRadius: 10,
    color: colors.text,
    padding: 14,
    fontSize: 16,
  },
  button: {
    backgroundColor: colors.accent,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 12,
  },
  buttonText: { color: colors.bg, fontWeight: '800', fontSize: 15 },
  buttonSecondary: {
    borderColor: colors.cardBorder,
    borderWidth: 1,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 10,
  },
  buttonSecondaryText: { color: colors.text, fontWeight: '700', fontSize: 15 },
  buttonDisabled: { opacity: 0.5 },
});
