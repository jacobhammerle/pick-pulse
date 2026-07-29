// Turns TestFlight beta feedback (from the app_store_connect.beta_feedback
// workflow trigger) into a GitHub issue.
// Reads FEEDBACK_JSON from the environment; shape can vary, so parse
// defensively. Emits issue_number as a step output via `set-output`.
import { execFileSync } from 'node:child_process';

let feedback = {};
try {
  feedback = JSON.parse(process.env.FEEDBACK_JSON || '{}');
} catch {
  // keep going with an empty object; the raw payload goes in the issue body
}

const comment =
  feedback.comment ??
  feedback.text ??
  feedback.feedback_text ??
  '(no comment provided)';
const tester =
  feedback.tester_email ?? feedback.tester ?? feedback.email ?? 'unknown tester';
const buildVersion =
  feedback.app_build_version ?? feedback.build_version ?? 'unknown build';
const screenshots = []
  .concat(feedback.screenshots ?? feedback.screenshot_urls ?? [])
  .filter(Boolean);

const title = `TestFlight feedback: ${String(comment).slice(0, 80)}`;

const body = [
  '## TestFlight feedback',
  '',
  `**Tester:** ${tester}`,
  `**Build:** ${buildVersion}`,
  '',
  '### Comment',
  '',
  String(comment),
  '',
  screenshots.length > 0 ? '### Screenshots' : '',
  ...screenshots.map((s, i) => `![screenshot-${i + 1}](${typeof s === 'string' ? s : s.url})`),
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
console.log(`Created issue #${number}: ${url}`);

// Expose the issue number to later workflow steps.
execFileSync('set-output', ['issue_number', String(number)], { stdio: 'inherit' });
