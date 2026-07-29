import { useState } from 'react';
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { usePicks } from '../lib/picks-context';
import {
  MIN_PICKS,
  formatMoney,
  getMultiplier,
  getPotentialPayout,
} from '../lib/payouts';
import { colors } from '../lib/theme';

const ENTRY_AMOUNTS = [5, 10, 20, 50];

export default function SlipScreen() {
  const { picks, removePick, clearPicks } = usePicks();
  const [entry, setEntry] = useState(10);
  const router = useRouter();

  const enoughPicks = picks.length >= MIN_PICKS;
  const multiplier = getMultiplier(picks.length);
  const payout = getPotentialPayout(entry, picks.length);

  const submit = () => {
    Alert.alert(
      'Entry submitted 🎉',
      `${picks.length} picks · ${formatMoney(entry)} to win ${formatMoney(payout)}`,
      [
        {
          text: 'OK',
          onPress: () => {
            clearPicks();
            router.back();
          },
        },
      ]
    );
  };

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll}>
        {picks.map(({ prop, direction }) => (
          <View key={prop.id} style={styles.pickRow} testID={`slip-row-${prop.id}`}>
            <Text style={styles.pickEmoji}>{prop.emoji}</Text>
            <View style={styles.pickInfo}>
              <Text style={styles.pickPlayer}>{prop.player}</Text>
              <Text style={styles.pickMeta}>
                {direction === 'more' ? 'More ↑' : 'Less ↓'} {prop.line} {prop.stat}
              </Text>
            </View>
            <Pressable
              onPress={() => removePick(prop.id)}
              testID={`remove-${prop.id}`}
              hitSlop={8}
            >
              <Text style={styles.remove}>✕</Text>
            </Pressable>
          </View>
        ))}

        {picks.length === 0 && (
          <Text style={styles.empty}>Your slip is empty. Go pick some props.</Text>
        )}

        <Text style={styles.sectionLabel}>Entry amount</Text>
        <View style={styles.entryRow}>
          {ENTRY_AMOUNTS.map((amount) => (
            <Pressable
              key={amount}
              testID={`entry-${amount}`}
              onPress={() => setEntry(amount)}
              style={[styles.entryButton, entry === amount && styles.entryButtonActive]}
            >
              <Text
                style={[styles.entryText, entry === amount && styles.entryTextActive]}
              >
                ${amount}
              </Text>
            </Pressable>
          ))}
        </View>
      </ScrollView>

      <View style={styles.footer}>
        <View style={styles.payoutRow}>
          <Text style={styles.payoutLabel}>
            {picks.length} picks · ×{multiplier} payout
          </Text>
          <Text style={styles.payoutValue} testID="payout-total">
            {formatMoney(payout)}
          </Text>
        </View>
        <Pressable
          testID="submit-entry"
          style={[styles.submit, !enoughPicks && styles.submitDisabled]}
          disabled={!enoughPicks}
          onPress={submit}
        >
          <Text style={styles.submitText}>
            {enoughPicks
              ? `Submit ${formatMoney(entry)} entry`
              : `Pick at least ${MIN_PICKS} to play`}
          </Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg },
  scroll: { padding: 16, paddingBottom: 24 },
  pickRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.card,
    borderColor: colors.cardBorder,
    borderWidth: 1,
    borderRadius: 12,
    padding: 12,
    marginBottom: 10,
  },
  pickEmoji: { fontSize: 22, marginRight: 10 },
  pickInfo: { flex: 1 },
  pickPlayer: { color: colors.text, fontWeight: '700' },
  pickMeta: { color: colors.textDim, fontSize: 12, marginTop: 2 },
  remove: { color: colors.danger, fontSize: 16, padding: 4 },
  empty: { color: colors.textDim, textAlign: 'center', marginVertical: 32 },
  sectionLabel: {
    color: colors.textDim,
    fontSize: 13,
    fontWeight: '600',
    marginTop: 16,
    marginBottom: 8,
  },
  entryRow: { flexDirection: 'row', gap: 10 },
  entryButton: {
    flex: 1,
    borderWidth: 1,
    borderColor: colors.cardBorder,
    borderRadius: 10,
    paddingVertical: 12,
    alignItems: 'center',
  },
  entryButtonActive: { backgroundColor: colors.accent, borderColor: colors.accent },
  entryText: { color: colors.text, fontWeight: '700' },
  entryTextActive: { color: colors.bg },
  footer: {
    borderTopWidth: 1,
    borderTopColor: colors.cardBorder,
    padding: 16,
    paddingBottom: 28,
  },
  payoutRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  payoutLabel: { color: colors.textDim, fontSize: 14 },
  payoutValue: { color: colors.accent, fontSize: 24, fontWeight: '800' },
  submit: {
    backgroundColor: colors.purple,
    borderRadius: 14,
    paddingVertical: 16,
    alignItems: 'center',
  },
  submitDisabled: { backgroundColor: colors.purpleSoft },
  submitText: { color: colors.text, fontSize: 16, fontWeight: '800' },
});
