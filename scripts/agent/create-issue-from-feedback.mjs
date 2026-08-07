// Turns TestFlight beta feedback into a GitHub issue.
// Requires: FEEDBACK_JSON, GITHUB_TOKEN, GH_REPO (the last two via gh.mjs).
// FEEDBACK_JSON is the output of `eas testflight:feedback <id> --json`,
// which the workflow resolves from the app_store_connect.beta_feedback
// trigger context.
// Logs go to stderr; the issue number is the only thing on stdout, so the
// workflow step can capture it and pass it to set-output.
import { execFileSync } from 'node:child_process';

let payload = {};
try {
  payload = JSON.parse(process.env.FEEDBACK_JSON || '{}');
} catch {
  // keep going with an empty object; the raw payload goes in the issue body
}

// `testflight:feedback` returns { feedback: {...} } for a single-ID lookup
// but { feedback: [...] } when listing (the workflow's fallback path).
// From a list, prefer the submission the trigger reported; otherwise take
// the newest one.
const raw = payload.feedback ?? payload;
let feedback = raw;
if (Array.isArray(raw)) {
  const triggerId = process.env.ASC_FEEDBACK_ID;
  feedback =
    (triggerId && raw.find((f) => f.id === triggerId)) ??
    [...raw].sort(
      (a, b) => new Date(b.createdDate ?? 0) - new Date(a.createdDate ?? 0)
    )[0] ??
    {};
}

const comment = feedback.comment ?? '(no comment provided)';
const tester = feedback.testerEmail ?? feedback.testerName ?? 'unknown tester';
const buildVersion = feedback.buildVersion ?? 'unknown build';
const device = [feedback.deviceModel, feedback.osVersion && `iOS ${feedback.osVersion}`]
  .filter(Boolean)
  .join(', ');
const screenshots = (feedback.screenshots ?? [])
  .map((s) => (typeof s === 'string' ? s : s.url))
  .filter(Boolean);

const title = `TestFlight feedback: ${String(comment).slice(0, 80)}`;

const body = [
  '## TestFlight feedback',
  '',
  `**Tester:** ${tester}`,
  `**Build:** ${buildVersion}`,
  device ? `**Device:** ${device}` : '',
  feedback.createdDate ? `**Submitted:** ${feedback.createdDate}` : '',
  '',
  '### Comment',
  '',
  String(comment),
  '',
  // Apple's screenshot URLs are presigned and expire, so note the deadline.
  screenshots.length > 0 ? '### Screenshots' : '',
  // Markdown images render full width; an HTML img with a width keeps a
  // portrait phone screenshot thumbnail-sized. Wrapping it in a link
  // preserves click-to-open-full-size.
  ...screenshots.map(
    (url, i) =>
      `<a href="${url}"><img src="${url}" alt="screenshot-${i + 1}" width="260" /></a>`
  ),
  screenshots.length > 0 && feedback.screenshots?.[0]?.expirationDate
    ? `\n_Screenshot links expire ${feedback.screenshots[0].expirationDate}._`
    : '',
  '',
  '<details><summary>Raw feedback payload</summary>',
  '',
  '```json',
  JSON.stringify(feedback, null, 2),
  '```',
  '',
  '</details>',
  '',
  '_Filed automatically by the testflight-feedback EAS workflow._',
].join('\n');

const out = execFileSync(
  'node',
  ['scripts/agent/gh.mjs', 'create-issue', title, body],
  { encoding: 'utf8' }
);
const { number, url } = JSON.parse(out.trim().split('\n').pop());

console.error(`Created issue #${number}: ${url}`);
console.log(String(number));
