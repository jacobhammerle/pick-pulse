// Builds a static evidence page from screenshots/video in the evidence dir.
// Usage: node scripts/agent/build-evidence-site.mjs <evidenceDir> <prNumber> "<verdict>"
import { cpSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const [evidenceDir, prNumber, verdict] = process.argv.slice(2);
const siteDir = join(evidenceDir, 'site');
mkdirSync(siteDir, { recursive: true });

const files = readdirSync(evidenceDir).filter(
  (f) => /\.(png|jpg|jpeg|mp4|mov)$/i.test(f)
);
for (const f of files) {
  cpSync(join(evidenceDir, f), join(siteDir, f));
}

const media = files
  .map((f) =>
    /\.(mp4|mov)$/i.test(f)
      ? `<figure><video src="./${f}" controls muted playsinline></video><figcaption>${f}</figcaption></figure>`
      : `<figure><img src="./${f}" alt="${f}" /><figcaption>${f}</figcaption></figure>`
  )
  .join('\n');

const pass = String(verdict).startsWith('PASS');

writeFileSync(
  join(siteDir, 'index.html'),
  `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>PR #${prNumber} verification evidence</title>
<style>
  body { font-family: -apple-system, sans-serif; background: #0D0D17; color: #fff;
         max-width: 900px; margin: 0 auto; padding: 24px; }
  .verdict { padding: 12px 16px; border-radius: 10px; font-weight: 700;
             background: ${pass ? '#1d3a1d' : '#3a1d1d'};
             border: 1px solid ${pass ? '#C6F432' : '#FF4D6A'}; }
  figure { margin: 24px 0; }
  img, video { max-width: 100%; border-radius: 12px; border: 1px solid #2A2A3E; }
  figcaption { color: #9494B0; font-size: 13px; margin-top: 6px; }
</style>
</head>
<body>
<h1>PickPulse — PR #${prNumber} verification</h1>
<p class="verdict">${verdict}</p>
<p>Captured by an agent on an EAS cloud simulator session.</p>
${media || '<p>No media captured.</p>'}
</body>
</html>
`
);

console.log(`Evidence site written to ${siteDir}`);
