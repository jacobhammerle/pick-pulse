import { Image } from 'expo-image';
import { Link } from 'expo-router';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';
import { BOARD, type PropLine } from '../data/board';
import { usePicks, type Direction } from '../lib/picks-context';
import { colors } from '../lib/theme';

function DirectionButton({
  prop,
  direction,
  label,
}: {
  prop: PropLine;
  direction: Direction;
  label: string;
}) {
  const { togglePick, getDirection } = usePicks();
  const selected = getDirection(prop.id) === direction;
  const tint = direction === 'more' ? colors.more : colors.less;

  return (
    <Pressable
      testID={`${direction}-${prop.id}`}
      accessibilityLabel={`${label} ${prop.line} ${prop.stat} for ${prop.player}`}
      onPress={() => togglePick(prop, direction)}
      style={[
        styles.directionButton,
        selected && { backgroundColor: tint, borderColor: tint },
      ]}
    >
      <Text style={[styles.directionText, selected && styles.directionTextSelected]}>
        {label}
      </Text>
    </Pressable>
  );
}

function PropCard({ prop }: { prop: PropLine }) {
  return (
    <View style={styles.card} testID={`prop-card-${prop.id}`}>
      <View style={styles.cardHeader}>
        <Text style={styles.emoji}>{prop.emoji}</Text>
        <View style={styles.cardHeaderText}>
          <Text style={styles.player}>{prop.player}</Text>
          <Text style={styles.meta}>
            {prop.team} · {prop.position} · {prop.opponent}
          </Text>
          <Text style={styles.meta}>{prop.gameTime}</Text>
        </View>
        <View style={styles.lineBox}>
          <Text style={styles.lineValue}>{prop.line}</Text>
          <Text style={styles.lineStat}>{prop.stat}</Text>
        </View>
      </View>
      <View style={styles.cardActions}>
        <DirectionButton prop={prop} direction="more" label="More ↑" />
        <DirectionButton prop={prop} direction="less" label="Less ↓" />
      </View>
    </View>
  );
}

export default function BoardScreen() {
  const { picks } = usePicks();

  return (
    <View style={styles.container}>
      <FlatList
        data={BOARD}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => <PropCard prop={item} />}
        contentContainerStyle={styles.listContent}
        ListHeaderComponent={
          <View style={styles.headerRow}>
            <View style={styles.brand}>
              <Image
                source={require('../../assets/images/logo-mark.png')}
                style={styles.logoMark}
                contentFit="contain"
                accessibilityIgnoresInvertColors
                alt="PickPulse"
              />
              <View>
                <Text style={styles.wordmark}>PickPulse</Text>
                <Text style={styles.headerSubtitle}>Tonight&apos;s Board</Text>
              </View>
            </View>
            <Link href="/preview" style={styles.previewLink}>
              ⚙︎
            </Link>
          </View>
        }
      />
      {picks.length > 0 && (
        <Link href="/slip" asChild>
          <Pressable style={styles.slipBar} testID="open-slip">
            <Text style={styles.slipBarText}>
              View Slip · {picks.length} {picks.length === 1 ? 'pick' : 'picks'}
            </Text>
          </Pressable>
        </Link>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bg },
  listContent: { padding: 16, paddingBottom: 96 },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  brand: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  logoMark: { width: 34, height: 34 },
  wordmark: {
    color: colors.text,
    fontSize: 20,
    fontWeight: '800',
    letterSpacing: -0.4,
  },
  headerSubtitle: { color: colors.textDim, fontSize: 12, marginTop: 1 },
  previewLink: { color: colors.textDim, fontSize: 20, padding: 4 },
  card: {
    backgroundColor: colors.card,
    borderColor: colors.cardBorder,
    borderWidth: 1,
    borderRadius: 16,
    padding: 14,
    marginBottom: 12,
  },
  cardHeader: { flexDirection: 'row', alignItems: 'center' },
  emoji: { fontSize: 28, marginRight: 10 },
  cardHeaderText: { flex: 1 },
  player: { color: colors.text, fontSize: 16, fontWeight: '700' },
  meta: { color: colors.textDim, fontSize: 12, marginTop: 2 },
  lineBox: { alignItems: 'flex-end' },
  lineValue: { color: colors.accent, fontSize: 22, fontWeight: '800' },
  lineStat: { color: colors.textDim, fontSize: 11 },
  cardActions: { flexDirection: 'row', gap: 10, marginTop: 12 },
  directionButton: {
    flex: 1,
    borderWidth: 1,
    borderColor: colors.cardBorder,
    borderRadius: 10,
    paddingVertical: 10,
    alignItems: 'center',
  },
  directionText: { color: colors.text, fontWeight: '700' },
  directionTextSelected: { color: colors.bg },
  slipBar: {
    position: 'absolute',
    left: 16,
    right: 16,
    bottom: 24,
    backgroundColor: colors.purple,
    borderRadius: 14,
    paddingVertical: 16,
    alignItems: 'center',
  },
  slipBarText: { color: colors.text, fontSize: 16, fontWeight: '800' },
});
