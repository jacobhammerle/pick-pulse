# PickPulse — Agentic EAS Workflows Demo

A sports-picks demo app for showing the full agentic EAS pipeline:

```
TestFlight feedback ──▶ GitHub issue ──▶ agent fixes on a branch
        ──▶ PR opens ──▶ EAS cloud simulator verifies (screenshots + video)
        ──▶ evidence site on EAS Hosting ──▶ update on channel pr-N
        ──▶ channel surf to preview on your phone ──▶ automated code review
        ──▶ "/agent <change>" comment to iterate ──▶ merge
        ──▶ OTA update or new TestFlight build (fingerprint decides)
```

## The planted bug

`src/lib/payouts.ts` has an off-by-one bug:

```ts
export function getMultiplier(pickCount: number): number {
  return PAYOUT_MULTIPLIERS[pickCount - 1];   // should be [pickCount]
}
```

Effect: add 2 picks, open the slip, and the payout row shows
`×undefined` and `$NaN`. With 3-6 picks it shows the wrong (lower)
multiplier. Very visible, easy to screenshot, and a clean one-line fix
for the agent. The fix: remove the `- 1`.

## One-time setup (about 45 minutes)

### 1. Repo and EAS project

```sh
cd pickpulse
git init && git add -A && git commit -m "initial commit"
gh repo create <you>/pickpulse --private --source . --push
npx eas-cli@latest init          # creates/links the EAS project
npx eas-cli@latest update:configure
git add -A && git commit -m "link EAS" && git push
```

Then connect the GitHub repo to the EAS project:
expo.dev → project → Settings → GitHub → install app → connect repo.
This makes the `pull_request` and `push` workflow triggers work.

After `eas init`, validate all workflow files against the live schema:

```sh
for f in .eas/workflows/*.yml; do
  npx eas-cli@latest workflow:validate "$f"
done
```

(All files are YAML-clean and follow the documented job syntax, but the
schema evolves — validate before the dry run.)

### 2. App Store Connect (for the TestFlight feedback trigger)

- Create the app in App Store Connect (bundle id `dev.expo.pickpulse`,
  or change it in `app.json` to match your team's conventions).
- Put your ASC app ID in `eas.json` → `submit.production.ios.ascAppId`.
- Connect ASC to the EAS project: expo.dev → project → Settings →
  Connections → App Store Connect. This enables the
  `app_store_connect.beta_feedback` trigger.

### 3. EAS environment variables

Set at expo.dev → project → Environment variables. Create these in
BOTH the `production` and `preview` environments:

| Name | Value |
| --- | --- |
| `ANTHROPIC_API_KEY` | Anthropic API key (agents run Claude Code) |
| `GITHUB_TOKEN` | GitHub PAT with `repo` scope |
| `GH_REPO` | `<you>/pickpulse` |
| `EXPO_TOKEN` | EAS access token (robot user recommended) |

### 4. GitHub repository secrets (for the comment bridge)

Repo → Settings → Secrets and variables → Actions:

| Name | Value |
| --- | --- |
| `EXPO_TOKEN` | same EAS access token |
| `EAS_PROJECT_ID` | `extra.eas.projectId` from app.json after `eas init` |

### 5. EAS Simulator access

The verification workflow uses EAS Simulator sessions (limited access).
Check availability:

```sh
npx eas-cli@latest simulator:availability --json
```

If it is not enabled on your account, ask the team to flip it on, or
swap the `verify_on_simulator` job for a `maestro` job as a fallback.

### 6. Builds to have ready BEFORE the meeting

```sh
# TestFlight build (store distribution, channel: production)
npx eas-cli@latest build --platform ios --profile production
npx eas-cli@latest submit --platform ios --latest

# Simulator build cache (so PR verification repacks instead of
# doing a full 15-minute build during the demo)
npx eas-cli@latest build --platform ios --profile preview-simulator
```

Install the TestFlight build on your phone. This is the build you demo
feedback and channel surfing on. Note: channel surfing needs a release
build. It does not work in a dev client or Expo Go.

## Dry run (do this at least once before the meeting)

1. On your phone, in the TestFlight build: pick 2 props, open the
   slip, see `$NaN`. Take a screenshot (Home + power).
2. TestFlight → PickPulse → Send Feedback → attach the screenshot →
   write "Payout shows $NaN on the slip when I add two picks" → Submit.
3. Watch expo.dev → Workflows. `testflight-feedback` fires, files the
   issue, and dispatches `agent-fix`.
   - ASC feedback webhooks can lag a few minutes. Backup: run
     `npx eas-cli@latest workflow:run .eas/workflows/agent-fix.yml -F issue_number=<N>`
     after filing the issue manually.
4. `agent-fix` opens the PR. The PR triggers `pr-verify` and
   `code-review`.
5. Open the Simulator Session link from the `verify_on_simulator` job
   on the projector — you can watch the agent tapping the app live.
6. When the PR comment lands: open the evidence URL, then on your
   phone open PickPulse → ⚙︎ → enter `pr-<N>` → Switch channel. Slip
   now shows the correct payout.
7. Comment `/agent make the payout number larger and bolder` on the
   PR. Watch the iterate workflow push a new commit and re-verify.
8. Merge. `deploy-production` fingerprints, finds the store build,
   and ships the fix as an OTA update to the production channel.
9. On your phone: ⚙︎ → Reset to build channel → the fix arrives via
   the normal production update.

After the dry run, revert the fix so the demo is fresh:

```sh
git revert <fix-merge-commit> && git push   # restores the $NaN bug
```

(Note: the revert push to main triggers deploy-production and ships the
bug back to the production channel — which is exactly what you want for
the live demo.)

## Live demo script (15-20 min)

1. **Hook (2 min).** Show the app on your phone. Find the $NaN bug
   "live". "A tester just hit this. Watch what happens when I report
   it."
2. **Feedback → issue (2 min).** Submit TestFlight feedback with the
   screenshot. Show the GitHub issue appear, screenshot included.
3. **Agent fixes it (3 min).** Show the workflow run on expo.dev.
   While it runs, explain: no laptop touched the code — the agent runs
   inside EAS.
4. **Cloud simulator (3 min).** Open the simulator session page.
   The audience watches an agent tap through their exact flow, take
   screenshots, and record evidence.
5. **The PR (3 min).** Show the PR: the fix diff, the evidence site
   with before/after screenshots, the automated code review, and the
   channel-surfing comment.
6. **Channel surfing (2 min).** On your phone: ⚙︎ → `pr-N` → the fix
   is live in the store build, before merge. Hand them the phone.
7. **Iterate (2 min).** Comment `/agent <small tweak>` and show the
   new commit arrive.
8. **Ship (1 min).** Merge. Fingerprint decides: JS-only → instant OTA
   update; native change → new build + TestFlight submit.

## Repository map

| Path | Purpose |
| --- | --- |
| `src/app/` | Screens: board, slip (bug visible here), preview (channel surfing) |
| `src/lib/payouts.ts` | The planted bug |
| `src/lib/channel.ts` | Channel surfing (`Updates.setUpdateRequestHeadersOverride`) |
| `.eas/workflows/testflight-feedback.yml` | Feedback → issue → dispatch fix |
| `.eas/workflows/agent-fix.yml` | Claude Code fixes the issue, opens PR |
| `.eas/workflows/pr-verify.yml` | Fingerprint/repack build → simulator verification → evidence deploy → pr-N update → PR comment |
| `.eas/workflows/code-review.yml` | Automated review comment |
| `.eas/workflows/agent-iterate.yml` | `/agent` comment-driven iteration |
| `.eas/workflows/deploy-production.yml` | Merge → OTA update or build+TestFlight |
| `.github/workflows/eas-comment-bridge.yml` | Forwards `/agent` comments to EAS REST API |
| `scripts/agent/` | The scripts the workflows run |

## Public repo safety

No secrets live in this repo. All credentials come from EAS environment
variables and GitHub Actions secrets. `.env.eas-simulator` (which holds
a session token) and `evidence/` are gitignored.

If you make the repo public, know these three things:

1. **The `/agent` comment bridge is gated.** Only comments from the
   repo owner, org members, and collaborators dispatch the iterate
   workflow. Do not remove that gate — without it, anyone could drive
   the agent with arbitrary instructions.
2. **Fork PRs.** `pr-verify.yml` and `code-review.yml` run on
   `pull_request` and expose `ANTHROPIC_API_KEY`, `EXPO_TOKEN`, and
   `GITHUB_TOKEN` to scripts checked out from the PR branch. Confirm
   how your EAS project handles PRs from forks before accepting any.
   If in doubt, disable fork PRs (keep pushes collaborator-only) or
   keep the repo private until after the demo.
3. **Scope the tokens.** Use a fine-grained GitHub PAT restricted to
   this one repo, and an EAS robot token scoped to this project. Then
   the blast radius of any leak stays small.

## Known sharp edges

- The `app_store_connect.beta_feedback` payload shape is not fully
  documented. `create-issue-from-feedback.mjs` parses defensively and
  dumps the raw payload into the issue. After your first real feedback
  event, check the issue and tighten the field mapping if needed.
- `eas simulator:*` commands are experimental. If a flag changed,
  `--help` is authoritative. The eas-simulator skill in expo/skills is
  the best reference.
- Agent verification is agent-driven, which is the point of the demo,
  but agents can wander. The dry run matters. If you want a
  deterministic safety net, add a `maestro` job next to
  `verify_on_simulator`.
- Have backup artifacts from the dry run open in tabs: the old PR, its
  evidence site, and its simulator session recording. If the live run
  stalls, narrate from the tabs.
