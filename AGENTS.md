# Working in this repo

Expo has changed. Read the exact versioned docs at
https://docs.expo.dev/versions/v57.0.0/ before writing app code.

The app is small on purpose; the pipeline is the point. Product code
lives under `src/`. The agentic pipeline is `.eas/workflows/*.yml` plus
one script per stage in `scripts/agent/`; agent prompts that would push a
workflow past EAS's 16 kB YAML cap live in `.eas/*.md`. Every bot comment
shares one shape: a `## 🤖 <stage>` heading, a bold **Verdict** or
**Status** line with a status emoji, a short bullet list, screenshot
thumbnails when there are any, the full report folded away, and a
`_Posted by_` footer. Keep that shape when you add a stage.
