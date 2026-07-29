# PickPulse 🏀🏈⚾

A sports-picks demo app (Expo SDK 57 + expo-router) built to demo
**agentic EAS Workflows paired with EAS Simulators**.

Pick player props, build a slip, and watch an agent pipeline fix bugs
end to end: TestFlight feedback → GitHub issue → agent fix → cloud
simulator verification → PR with evidence → channel-surf preview →
automated review → comment-driven iteration → production deploy.

**Start with [DEMO.md](./DEMO.md)** — it has the setup checklist, the
planted bug, the dry run, and the live demo script.

## Quick start (local)

```sh
npm install
npx expo start
```

The bug: add 2 picks, open the slip, payout shows `$NaN`.
Root cause is in `src/lib/payouts.ts` (see DEMO.md).
