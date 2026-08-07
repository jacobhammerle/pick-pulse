// Turns a TestFlight crash into a GitHub issue, with the symbolicated crash
// log inline so the agent has a stack trace to work from.
// Requires: CRASH_JSON, GITHUB_TOKEN, GH_REPO (the last two via gh.mjs).
// CRASH_JSON is the output of `eas testflight:crashes <id> --type crash --json`.
// Logs go to stderr; the issue number is the only thing on stdout.
import { execFileSync } from 'node:child_process';

// GitHub rejects issue bodies over 65536 characters, and the useful frames
// are at the top of a crash log anyway.
const MAX_LOG_CHARS = 30000;

let payload = {};
try {
  payload = JSON.parse(process.env.CRASH_JSON || '{}');
} catch {
  // keep going with an empty object; the raw payload goes in the issue body
}

// A single-ID lookup returns { crash, logText }; a list returns { crashes: [...] }.
const crash = payload.crash ?? (Array.isArray(payload.crashes) ? payload.crashes[0] : payload) ?? {};
const logText = payload.logText ?? '';

const tester = crash.testerEmail ?? crash.testerName ?? 'unknown tester';
const buildVersion = crash.buildVersion ?? 'unknown build';
const device = [crash.deviceModel, crash.osVersion && `iOS ${crash.osVersion}`]
  .filter(Boolean)
  .join(', ');
const uptime =
  typeof crash.appUptimeInMilliseconds === 'number'
    ? `${(crash.appUptimeInMilliseconds / 1000).toFixed(1)}s before crashing`
    : null;

const truncated = logText.length > MAX_LOG_CHARS;
const log = truncated ? logText.slice(0, MAX_LOG_CHARS) : logText;

const title = `TestFlight crash: ${device || 'unknown device'} on build ${buildVersion}`;

// null marks a line that does not apply; '' is an intentional blank line,
// which Markdown needs for paragraph and code-fence separation.
const body = [
  '## TestFlight crash',
  '',
  `**Tester:** ${tester}  `,
  `**Build:** ${buildVersion}  `,
  device ? `**Device:** ${device}  ` : null,
  crash.architecture ? `**Arch:** ${crash.architecture}  ` : null,
  uptime ? `**Uptime:** ${uptime}  ` : null,
  crash.createdDate ? `**Reported:** ${crash.createdDate}` : null,
  '',
  crash.comment ? '### Tester comment' : null,
  crash.comment ? '' : null,
  crash.comment ? crash.comment : null,
  crash.comment ? '' : null,
  '### Crash log',
  '',
  ...(log
    ? ['```', log, '```']
    : ['_No crash log was returned._']),
  truncated ? '' : null,
  truncated ? `_Log truncated to the first ${MAX_LOG_CHARS} characters._` : null,
  '',
  '_Filed automatically by the testflight-crash EAS workflow._',
]
  .filter((line) => line !== null)
  .join('\n');

const out = execFileSync(
  'node',
  ['scripts/agent/gh.mjs', 'create-issue', title, body],
  { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 }
);
const { number, url } = JSON.parse(out.trim().split('\n').pop());

console.error(`Created issue #${number}: ${url}`);
console.log(String(number));
