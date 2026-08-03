// Builds a static evidence page from screenshots/video in the evidence dir.
// Usage: node scripts/agent/build-evidence-site.mjs <evidenceDir> <prNumber> "<verdict>"
import { cpSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const [evidenceDir, prNumber, verdict] = process.argv.slice(2);
const siteDir = join(evidenceDir, 'site');
mkdirSync(siteDir, { recursive: true });

// Natural sort so "1-home.png", "2-settings.png", "10-x.png" stay in
// capture order.
const files = readdirSync(evidenceDir)
  .filter((f) => /\.(png|jpg|jpeg|mp4|mov)$/i.test(f))
  .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
for (const f of files) {
  cpSync(join(evidenceDir, f), join(siteDir, f));
}

const esc = (s) =>
  String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// "2-settings-tab.png" -> "Settings tab"
const caption = (f) => {
  const base = f.replace(/\.[^.]+$/, '').replace(/^\d+[-_ ]*/, '').replace(/[-_]+/g, ' ').trim();
  return base ? base.charAt(0).toUpperCase() + base.slice(1) : f;
};

const images = files.filter((f) => /\.(png|jpg|jpeg)$/i.test(f));
const videos = files.filter((f) => /\.(mp4|mov)$/i.test(f));

const imageCards = images
  .map(
    (f, i) => `<a class="shot" href="./${esc(f)}" target="_blank" rel="noopener">
  <span class="shot-num">${i + 1}</span>
  <img src="./${esc(f)}" alt="${esc(caption(f))}" loading="lazy" />
  <span class="shot-caption">${esc(caption(f))}</span>
</a>`
  )
  .join('\n');

const videoBlocks = videos
  .map(
    (f) => `<figure class="clip">
  <video src="./${esc(f)}" controls muted playsinline></video>
  <figcaption>${esc(caption(f))}</figcaption>
</figure>`
  )
  .join('\n');

const pass = String(verdict).startsWith('PASS');
const verdictLabel = pass ? 'PASS' : 'FAIL';
const verdictDetail = String(verdict).replace(/^(PASS|FAIL)\s*:?\s*/i, '');

writeFileSync(
  join(siteDir, 'index.html'),
  `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>PickPulse · PR #${esc(prNumber)} verification</title>
<style>
  :root {
    --bg: #0D0D17; --card: #1A1A2A; --border: #2A2A3E;
    --text: #FFFFFF; --dim: #9494B0;
    --accent: #C6F432; --danger: #FF4D6A;
  }
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    background: var(--bg); color: var(--text);
    max-width: 1080px; margin: 0 auto; padding: 32px 24px 64px;
  }
  header { display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap; }
  .brand { font-size: 22px; font-weight: 800; letter-spacing: -0.02em; }
  .brand .pulse { color: var(--accent); }
  .pr { color: var(--dim); font-size: 15px; }
  .verdict {
    display: flex; align-items: center; gap: 12px;
    margin: 20px 0 8px; padding: 14px 16px;
    background: var(--card); border: 1px solid var(--border);
    border-radius: 12px;
  }
  .badge {
    flex: none; padding: 4px 12px; border-radius: 999px;
    font-weight: 800; font-size: 13px; letter-spacing: 0.04em;
    color: #0D0D17;
    background: ${pass ? 'var(--accent)' : 'var(--danger)'};
  }
  .verdict p { margin: 0; font-size: 15px; line-height: 1.45; }
  .meta { color: var(--dim); font-size: 13px; margin: 0 0 28px; }
  h2 { font-size: 14px; font-weight: 700; text-transform: uppercase;
       letter-spacing: 0.08em; color: var(--dim); margin: 32px 0 14px; }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
  }
  .shot {
    position: relative; display: flex; flex-direction: column;
    background: var(--card); border: 1px solid var(--border);
    border-radius: 14px; padding: 10px; text-decoration: none;
    transition: border-color 0.15s ease;
  }
  .shot:hover { border-color: var(--accent); }
  .shot img {
    width: 100%; height: 380px; object-fit: contain;
    border-radius: 8px; background: #000;
  }
  .shot-num {
    position: absolute; top: 18px; left: 18px;
    width: 24px; height: 24px; border-radius: 999px;
    display: flex; align-items: center; justify-content: center;
    background: var(--accent); color: #0D0D17;
    font-size: 12px; font-weight: 800;
  }
  .shot-caption {
    color: var(--text); font-size: 13px; font-weight: 600;
    text-align: center; padding: 10px 4px 4px;
  }
  .clip { margin: 0 0 20px; }
  .clip video {
    width: 100%; max-height: 70vh; border-radius: 14px;
    border: 1px solid var(--border); background: #000;
  }
  .clip figcaption { color: var(--dim); font-size: 13px; margin-top: 8px; }
  .empty { color: var(--dim); }
  footer { margin-top: 40px; color: var(--dim); font-size: 12px;
           border-top: 1px solid var(--border); padding-top: 16px; }
</style>
</head>
<body>
<header>
  <span class="brand">Pick<span class="pulse">Pulse</span></span>
  <span class="pr">PR #${esc(prNumber)} · agent verification</span>
</header>

<div class="verdict">
  <span class="badge">${verdictLabel}</span>
  <p>${esc(verdictDetail) || esc(verdict)}</p>
</div>
<p class="meta">Captured by an agent driving the app on an EAS cloud simulator. Click a screenshot to open it full size.</p>

${images.length ? `<h2>Screenshots</h2>\n<div class="grid">\n${imageCards}\n</div>` : ''}
${videos.length ? `<h2>Recording</h2>\n${videoBlocks}` : ''}
${!files.length ? '<p class="empty">No media captured.</p>' : ''}

<footer>Generated ${new Date().toISOString().slice(0, 16).replace('T', ' ')} UTC · pr-verify workflow · EAS Hosting</footer>
</body>
</html>
`
);

console.log(`Evidence site written to ${siteDir} (${images.length} images, ${videos.length} videos)`);
