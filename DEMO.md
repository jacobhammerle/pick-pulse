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

## The demo request

Settings is currently reachable only through a small gear (⚙︎) link in
the top-right of the home header (`src/app/index.tsx`). Navigation is
a plain expo-router Stack (`src/app/_layout.tsx`).

The demo feedback asks: put Settings in a bottom tab bar, so the user
can tab between the home board and the settings screen.

What the agent has to do: restructure the Stack into expo-router Tabs
(a Home tab and a Settings tab), keep the slip working as a modal, and
remove the gear link. This is a visible, multi-file navigation change —
a stronger story than a one-line fix, and easy to see on a phone.

`scripts/agent/verify-on-simulator.sh` is hardcoded to verify exactly
this scenario: tab bar present, Settings tab shows the channel UI,
Home tab returns to the board, gear gone from the header.

(An earlier version of this demo used a planted `$NaN` payout bug.
That bug is fixed on main, and the verification no longer checks it.)

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

- Create the app in App Store Connect (bundle id
  `com.jacobhammerle.pickpulse`, under your personal Apple Developer
  team). If you change it in `app.json`, also update the two references
  in `scripts/agent/verify-on-simulator.sh`.
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

1. On your phone, in the TestFlight build: show the home screen and
   the tiny gear in the top-right corner. Take a screenshot
   (Home + power).
2. TestFlight → PickPulse → Send Feedback → attach the screenshot →
   write "Settings is buried behind the tiny gear icon in the corner.
   Please make Settings a tab at the bottom so I can switch between
   the board and settings." → Submit.
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
   phone open PickPulse → ⚙︎ → enter `pr-<N>` → Switch channel. The
   app reloads with the tab bar: Settings now sits at the bottom, and
   the gear is gone. (You use the old gear one last time to reach the
   channel switcher — that's part of the story.)
7. Comment `/agent give the Settings tab a gear icon` on the PR.
   Watch the iterate workflow push a new commit and re-verify.
8. Merge. `deploy-production` fingerprints, finds the store build,
   and ships the fix as an OTA update to the production channel.
9. On your phone: Settings tab → Reset to build channel → the change
   arrives via the normal production update.

After the dry run, revert the change so the demo is fresh:

```sh
git revert <fix-merge-commit> && git push   # restores the gear-only nav
```

(Note: the revert push to main triggers deploy-production and ships the
gear-only navigation back to the production channel — which is exactly
what you want for the live demo.)

## Live demo script (15-20 min)

1. **Hook (2 min).** Show the app on your phone. Ask someone to find
   Settings. Point at the tiny gear in the corner. "A tester filed
   this exact complaint. Watch what happens when I report it."
2. **Feedback → issue (2 min).** Submit TestFlight feedback asking
   for a Settings tab, with the screenshot. Show the GitHub issue
   appear, screenshot included.
3. **Agent builds it (3 min).** Show the workflow run on expo.dev.
   While it runs, explain: no laptop touched the code — the agent
   restructures the navigation inside EAS.
4. **Cloud simulator (3 min).** Open the simulator session page.
   The audience watches an agent tap between the new tabs, take
   screenshots, and record evidence.
5. **The PR (3 min).** Show the PR: the navigation diff, the evidence
   site with the tab-bar screenshots, the automated code review, and
   the channel-surfing comment.
6. **Channel surfing (2 min).** On your phone: ⚙︎ → `pr-N` → the app
   reloads and the tab bar is live in the store build, before merge.
   Hand them the phone and let them tab around.
7. **Iterate (2 min).** Comment `/agent give the Settings tab a gear
   icon` and show the new commit arrive.
8. **Ship (1 min).** Merge. Fingerprint decides: JS-only → instant OTA
   update; native change → new build + TestFlight submit.

## Side demo: QA agent → deterministic Maestro test

A one-off flow, separate from the main demo. One agent QAs a feature
on an EAS cloud simulator. A second agent reads the session log and
writes a deterministic Maestro test from it. The same workflow run
then executes that test with the EAS `maestro` job. Everything runs
on EAS — no laptop simulator at any point.

Trigger it with one command:

```sh
npx eas-cli@latest workflow:run .eas/workflows/qa-to-maestro.yml \
  -F feature="the pick slip payout flow"
```

The `feature` input says what to test. The how (device verbs, the
snapshot discipline, the report format) is baked into the QA prompt
in `scripts/agent/qa-to-maestro.sh`. For per-run steering — expected
values, boundaries, steps to include — add the optional second input:

```sh
npx eas-cli@latest workflow:run .eas/workflows/qa-to-maestro.yml \
  -F feature="the pick slip payout flow" \
  -F guidance="add exactly 2 picks; the payout row must show a x3 multiplier and a dollar total; do not open settings"
```

PR mode: point it at an open PR instead. The QA agent reads the PR's
diff, works out what user-visible behavior changed, writes a short
test plan, and tests exactly that. The Maestro flow becomes that PR's
regression test, and the run leaves a comment on the PR.

```sh
npx eas-cli@latest workflow:run .eas/workflows/qa-to-maestro.yml \
  -F pr_number=12
```

`feature` is optional in PR mode (defaults to the PR title), and
`guidance` still works. Build selection in PR mode: the script looks
for a finished build from the PR's head commit (pr-verify usually
made one). If none exists it warns and uses the newest
`preview-simulator` build, which may not contain the PR's changes —
pass the right one explicitly with `-F build_id=<id>` from the PR's
pr-verify run.

What the workflow does:

1. **Build.** Fingerprint → reuse or repack the cached
   `preview-simulator` build (same path as pr-verify).
2. **Phase 1 (QA agent).** A custom job starts an EAS Simulator
   session and Claude Code explores the feature. It can only touch
   the device through `scripts/agent/device.sh`, which appends every
   command and its full output (including UI snapshots) to
   `qa-run/device-log.md`. It also writes `qa-run/qa-report.md` with
   its steps and a PASS/FAIL verdict. Watch it live: expo.dev →
   Simulator sessions → the "QA to Maestro" session.
3. **Phase 2 (Maestro agent).** In the same job, a fresh Claude Code
   run reads only the log and the report. It maps session element
   refs back to stable text labels and writes
   `.maestro/flows/<slug>.yaml`. The job also opens a PR that adds
   the flow to the repo (best effort).
4. **Phase 3 (deterministic run).** A `maestro` job receives the flow
   through a job output, materializes it in an `after_checkout` hook,
   and runs it against the same build with screen recording on.

The pieces:

| Path | Purpose |
| --- | --- |
| `.eas/workflows/qa-to-maestro.yml` | The whole flow in one dispatch |
| `scripts/agent/qa-to-maestro.sh` | The two agent phases (also runs standalone on a laptop) |
| `scripts/agent/device.sh` | Logging wrapper — the QA agent cannot take an unlogged action |
| `.eas/workflows/maestro-e2e.yml` | Re-runs committed flows any time (the regression story) |

Local fallback (needs `eas` and `claude` logged in; prints the live
preview URL directly):

```sh
bash scripts/agent/qa-to-maestro.sh "the pick slip payout flow"
```

Talking point: the agent explores once, and the team keeps a
regression test forever. The device wrapper is the trick — the QA
agent cannot take an unlogged action, so the second agent always has
the complete ground truth.

## Repository map

| Path | Purpose |
| --- | --- |
| `src/app/` | Screens: board (gear link in header), slip (modal), preview (settings/channel surfing — the screen that moves into the tab bar) |
| `src/app/_layout.tsx` | The Stack the agent restructures into Tabs |
| `src/lib/payouts.ts` | Payout math (an earlier demo's planted bug, now fixed) |
| `src/lib/channel.ts` | Channel surfing (`Updates.setUpdateRequestHeadersOverride`) |
| `.eas/workflows/testflight-feedback.yml` | Feedback → issue → dispatch fix |
| `.eas/workflows/agent-fix.yml` | Claude Code fixes the issue, opens PR |
| `.eas/workflows/pr-verify.yml` | Fingerprint/repack build → simulator verification → evidence deploy → pr-N update → PR comment |
| `.eas/workflows/code-review.yml` | Automated review comment |
| `.eas/workflows/agent-iterate.yml` | `/agent` comment-driven iteration |
| `.eas/workflows/deploy-production.yml` | Merge → OTA update or build+TestFlight |
| `.eas/workflows/qa-to-maestro.yml` | Side demo: QA agent → Maestro flow → maestro run, one dispatch |
| `.eas/workflows/maestro-e2e.yml` | Re-runs committed Maestro flows on EAS (side demo) |
| `scripts/agent/qa-to-maestro.sh` | The two agent phases behind the side demo |
| `scripts/agent/device.sh` | Logging wrapper — records every device action to `qa-run/` |
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
- The tab-bar change is a real navigation restructure, not a one-line
  fix. If the dry run shows the fix agent struggling, add a stronger
  hint to the prompt in `scripts/agent/fix-issue.sh` (for example:
  "use expo-router Tabs with a (tabs) group; keep the slip modal in
  the root Stack").
- Have backup artifacts from the dry run open in tabs: the old PR, its
  evidence site, and its simulator session recording. If the live run
  stalls, narrate from the tabs.
