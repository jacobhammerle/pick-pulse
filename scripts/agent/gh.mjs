// Minimal GitHub REST helper for EAS workflow jobs.
// Requires: GITHUB_TOKEN, GH_REPO (owner/repo).
// Usage:
//   node scripts/agent/gh.mjs create-issue "<title>" "<body>"
//   node scripts/agent/gh.mjs create-pr "<branch>" "<title>" "<body>"
//   node scripts/agent/gh.mjs comment <issue_or_pr_number> "<body>"
//   node scripts/agent/gh.mjs get-issue <number>
//   node scripts/agent/gh.mjs get-pr <number>

const token = process.env.GITHUB_TOKEN;
const repo = process.env.GH_REPO;

if (!token || !repo) {
  console.error('GITHUB_TOKEN and GH_REPO must be set');
  process.exit(1);
}

async function api(method, path, body) {
  const res = await fetch(`https://api.github.com${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent': 'pickpulse-eas-workflows',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.error(`GitHub API ${method} ${path} failed: ${res.status}`);
    console.error(JSON.stringify(json, null, 2));
    process.exit(1);
  }
  return json;
}

const [cmd, ...args] = process.argv.slice(2);

switch (cmd) {
  case 'create-issue': {
    const [title, body] = args;
    const issue = await api('POST', `/repos/${repo}/issues`, { title, body });
    console.log(JSON.stringify({ number: issue.number, url: issue.html_url }));
    break;
  }
  case 'create-pr': {
    const [branch, title, body] = args;
    const pr = await api('POST', `/repos/${repo}/pulls`, {
      title,
      body,
      head: branch,
      base: 'main',
    });
    console.log(JSON.stringify({ number: pr.number, url: pr.html_url }));
    break;
  }
  case 'comment': {
    const [number, body] = args;
    const comment = await api('POST', `/repos/${repo}/issues/${number}/comments`, {
      body,
    });
    console.log(JSON.stringify({ url: comment.html_url }));
    break;
  }
  case 'latest-issue': {
    // Newest open issue number (excluding PRs), on stdout by itself.
    const issues = await api(
      'GET',
      `/repos/${repo}/issues?state=open&sort=created&direction=desc&per_page=10`
    );
    const issue = issues.find((i) => !i.pull_request);
    if (!issue) {
      console.error('No open issues found');
      process.exit(1);
    }
    console.log(String(issue.number));
    break;
  }
  case 'get-issue': {
    const [number] = args;
    const issue = await api('GET', `/repos/${repo}/issues/${number}`);
    console.log(JSON.stringify({ title: issue.title, body: issue.body }));
    break;
  }
  case 'get-pr': {
    const [number] = args;
    const pr = await api('GET', `/repos/${repo}/pulls/${number}`);
    console.log(
      JSON.stringify({
        title: pr.title,
        body: pr.body,
        branch: pr.head.ref,
        sha: pr.head.sha,
      })
    );
    break;
  }
  case 'get-pr-diff': {
    // Raw unified diff on stdout (not JSON), via GitHub's diff media type.
    const [number] = args;
    const res = await fetch(`https://api.github.com/repos/${repo}/pulls/${number}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github.diff',
        'User-Agent': 'pickpulse-eas-workflows',
      },
    });
    if (!res.ok) {
      console.error(`GitHub API diff for PR #${number} failed: ${res.status}`);
      process.exit(1);
    }
    process.stdout.write(await res.text());
    break;
  }
  default:
    console.error(`Unknown command: ${cmd}`);
    process.exit(1);
}
