# Contributing to GuacSweep

Thanks for considering contributing. GuacSweep is a small, intentionally minimal project, but there's real room to help, especially around Leftover Sweep.

## Highest-value areas

- **Leftover Sweep matching accuracy** — the biggest open problem in the project. If you've found a false positive or false negative pattern (an installed app whose data gets flagged as orphaned, or a genuinely orphaned bundle ID that slips through), please open an issue with the specific bundle ID pattern involved. Real-world examples are far more useful than hypothetical edge cases.
- **Testing on Apple Silicon or other macOS versions** — this project was built and tested primarily on one Intel Mac. Reports of anything that behaves differently elsewhere are genuinely useful.
- **Bug reports** on any of the ten menu options.

## Ground rules

- **Keep it bash, keep it portable.** GuacSweep deliberately avoids features that require anything newer than the `bash 3.2` Apple ships by default (no associative arrays, no `${var,,}` lowercase expansion, etc.). If a PR relies on a bash 4+ feature, it needs a bash-3.2-compatible alternative, even if that's a few lines longer.
- **Keep the Trash-first safety model intact.** Any new action that touches files should move them to Trash first, not delete directly, consistent with every existing option. If something is genuinely irreversible, it needs the same level of explicit, hard-to-misfire confirmation as Empty Trash.
- **No new dependencies.** Part of the whole point of this project is that it runs with zero setup beyond `chmod +x`. Please don't introduce a dependency on Homebrew packages, external binaries, or anything not already present on a stock Mac.
- **Explain destructive changes clearly.** If a PR changes what a menu option deletes or how it's scoped, the PR description should say so plainly, and the in-script explanation text (shown before each confirm prompt) should be updated to match.

## Opening an issue

Please open an issue before starting significant work, so scope and direction can be discussed before you invest time in it.
