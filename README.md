# guacsweep 🥑🧹

**A lean and transparent terminal-only macOS maintenance tool.**

guacsweep is a single, dependency-free bash script that clears the junk CleanMyMac X clears, without the subscription, the closed source, the bloat, or the compiled binary. It empties caches and logs, clears recent-items and history traces, thins Time Machine snapshots, and scans for orphaned app data left behind by things you've long since uninstalled. Every action moves files to the Trash first, never straight deletion, except one clearly marked option that empties the Trash itself.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash%203.2%2B-4EAA25?logo=gnubash&logoColor=white)]()
[![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white)]()
[![Dependencies](https://img.shields.io/badge/Dependencies-None-brightgreen)]()

![guacsweep demo](docs/demo.gif)

*(Demo GIF coming soon)*

---

## 🔍 What it does

guacsweep presents a numbered menu and runs one action at a time. Ten options total: seven safe, reversible cleanup actions; one review-before-you-move scan for orphaned app data; one shortcut to run all seven safe actions in sequence; and one, and only one, action that's genuinely irreversible.

Nothing here requires Homebrew, a compiled toolchain, or any third-party library. It's plain POSIX-ish bash, compatible with the ancient `bash 3.2` that Apple still ships by default on every Mac, and it runs the moment you `chmod +x` it.

---

## 🌱 Why I built this

I used to have a one-time CleanMyMac X license, but I only used a few of its features. Instead of paying for a subscription cleaner or upgrading, I wanted something that did those same things for free, with no hidden catches.

There are already two great free and open-source options: [PureMac](https://github.com/momenbasel/PureMac), a native macOS uninstaller and system cleaner (MIT-licensed), and [Mole](https://github.com/tw93/Mole), a powerful command-line cleaner (GPL-3.0-licensed) with lots of features like disk analysis, a live dashboard, and developer artifact cleanup. Both are actively maintained and fully open source. guacsweep isn’t trying to compete with them on features.

1. First, I wanted something you could read from start to finish in plain text before running it. PureMac ships as a signed native app. Mole, to its real credit, is mostly plain shell script itself, genuinely impressive for a tool this feature-rich, but it does compile a real Go component for some of its more advanced features. With a compiled tool, you have to trust that the binary matches the source code. guacsweep's promise is narrower but absolute: there is no compiled component anywhere in the project, for any feature. The file you download *is* the whole program.

2. Second, I wanted something simple and focused on just the features I use most, not a full toolkit. If you need more than what guacsweep offers, both PureMac and especially Mole are great choices. Either one is a solid option for anything guacsweep doesn’t handle.

---

## 🛡️ Safety model

Every design decision in this script follows from one rule: **nothing is ever silently destructive.**

- **Trash-first, always.** Every cleanup action moves files into a dated, clearly labeled folder inside `~/.Trash` rather than deleting anything directly. If something turns out to matter, drag it back out. This applies to every option except one.
- **One irreversible action, clearly marked.** `🔥 Empty Trash (Permanent Delete)` is the only action in the entire script that finalizes deletion. It's visually set apart, requires typing the literal word `EMPTY` (not just `y`) to confirm, and its warning text explains exactly why it's different from everything else in the menu.
- **Confirm before anything runs.** Every action explains what it's about to do and asks for confirmation first. Nothing fires on a stray keypress.
- **Ctrl+C always gets you out.** Hitting Ctrl+C at any prompt, including a sudo password prompt, cancels cleanly and drops you back at the main menu rather than leaving you stuck or killing the script outright.
- **`mv`-based Trash, deliberately, not AppleScript.** Files are moved into Trash with plain `mv`, not by asking Finder to delete them via AppleScript. This is a conscious tradeoff: `mv` needs zero extra permissions and adds no dependency on Finder automation access, which matches the "as little trust surface as possible" philosophy of the whole project. The cost is that Finder's right-click **"Put Back"** feature won't work on anything guacsweep trashes, since that requires the original-location metadata Finder's own delete API attaches. You can still manually drag anything back to where it came from; you just won't get the one-click shortcut.
- **Every `sudo` call is announced first.** Three options and part of the Full Sweep need elevated permissions (clearing system-wide caches, flushing DNS, thinning Time Machine snapshots). Each one tells you up front that macOS is about to ask for your password, and that Ctrl+C cancels cleanly if you change your mind.

---

## ⚙️ Features

| # | Option | What it does |
|---|---|---|
| 1 | **Delete User Junk Files (Cache + Logs)** | Clears `~/Library/Caches`, `~/Library/Logs`, and Xcode's `DerivedData` build cache, if present. All regenerate automatically. |
| 2 | **Delete System Junk Files (sudo)** | Clears `/Library/Caches`, the shared system-level cache folder. Requires sudo since it's root-owned. |
| 3 | **Delete Recent Items Lists** | Clears Apple menu Recent Documents/Applications/Servers and each app's own File > Open Recent menu. Shortcuts only, not the files themselves. |
| 4 | **Delete Terminal History** | Clears `~/.zsh_history` and `~/.bash_history`. Your currently-open terminal session keeps its own in-memory history regardless, see [Known limitations](#%EF%B8%8F-known-limitations). |
| 5 | **Delete Download History** | Clears macOS's download-quarantine metadata (source and date of downloads). Does not touch the downloaded files themselves. |
| 6 | **Flush DNS Cache** | Clears the local DNS lookup cache. Touches zero files; requires sudo. |
| 7 | **Time Machine Snapshot Thinning** | Removes local Time Machine snapshots (on-disk checkpoints for offline "Browse in Time," not your real backups). Requires sudo. |
| 8 | **Leftover Sweep Scan (orphaned app data)** | Scans `~/Library` for data left behind by apps no longer installed, matched by bundle identifier. Reports a grouped, human-readable summary; nothing moves until you explicitly select what to trash. |
| 9 | **Run Full Sweep (all safe options)** | Runs options 1 through 7 in sequence behind a single confirmation. Excludes Leftover Sweep and Empty Trash, since both need manual review. |
| 10 | **🔥 Empty Trash (Permanent Delete)** | The only irreversible action in the script. Empties `~/.Trash` and any connected external drives' Trash for good. |

---

## 📊 Comparison to similar apps

| | guacsweep | PureMac | Mole | CleanMyMac X |
|---|---|---|---|---|
| Price | Free | Free | CLI free / GUI paid | $40+/yr |
| Open source | Yes (MIT) | Yes (MIT) | CLI only (GPL-3.0)¹ | No |
| Distribution | Plain shell script | Native macOS app | Mostly shell, partial compiled Go² | Native macOS app |
| Native Mac GUI | No | Yes | Paid | Yes |
| Fully human-readable before running³ | Yes | Partial | Partial | No |
| Telemetry-free | Yes | Yes | Yes | No |
| Subscription-free | Yes | Yes | Yes | No |
| Signed and notarized | N/A⁴ | Yes | Yes | Yes |
| App uninstaller / orphan finder | Partial⁵ | Yes | Yes | Yes |
| Trash-only (recoverable) | Yes | Yes | Partial | Partial |
| Install footprint | None, single file | App bundle in `/Applications` | Shell + compiled component, via Homebrew/script | App bundle + installer |

¹ Mole, the CLI tool, (what's compared throughout this table) is GPL-3.0 licensed and fully open source. Mole for Mac is a separate, proprietary GUI app from the same author.
² Per GitHub's own language breakdown of the repository: roughly 82% shell, 18% Go. The large majority of Mole is genuinely plain, readable shell script; a real but minority portion, notably its live status dashboard and disk analyzer, compiles down to a Go binary.
³ The core differentiator this project exists for: a plain-text script you can read end to end has no gap between "the source" and "what runs," unlike anything that goes through a compile step.
⁴ Code-signing and notarization exist to satisfy Gatekeeper's checks on compiled executables. A plain shell script isn't in that category to begin with, so this isn't a workaround, it's simply a different distribution model.
⁵ Leftover Sweep matches by bundle identifier and reports a reviewable summary, but intentionally stops short of PureMac's and Mole's deeper heuristics (normalized-name matching, Team ID resolution). See [Known limitations](#%EF%B8%8F-known-limitations).

---

## ⚠️ Known limitations

- **Leftover Sweep can both over-flag and under-flag.** Apps with unconventional helper naming (concatenated suffixes with no separating dot, Team-ID-prefixed containers, vendors that use multiple unrelated bundle-ID families for one product) can show up as false positives even though they're installed. Shared SDKs used across many unrelated apps (Sparkle, Firebase, Bugsnag, Google Keystone) will also appear, since they don't map to any single parent app. 

> [!IMPORTANT]
> Always review the Leftover Sweep Scan summary **before** selecting anything to move.

- **System-level junk clearing is deliberately conservative.** `/System/Library/Caches` is skipped entirely, since it's SIP-protected on any modern Mac and writes there simply fail. System log files (`/var/log` and friends) are also out of scope by design, not oversight: routinely wiping them trades away a diagnostic and forensic trail that some users (including the original author) actively rely on.
- **No Finder "Put Back."** Since Trash moves use plain `mv` rather than Finder's own delete API, restoring a trashed item means manually moving it back to its original location. See [Safety model](#%EF%B8%8F-safety-model) for why this tradeoff was made deliberately.
- **Terminal history clearing only affects the file on disk.** Your currently-open terminal session keeps its own command history in memory. For a fully clean sweep, run that option from a window you're about to close, or open a fresh one afterward.
- **Tested primarily on Intel Mac hardware, on one machine.** Community testing on other configurations is welcome.

---

## 🗺️ Roadmap

- [ ] Homebrew tap (`avocadoattack/homebrew-tap`), so installation becomes `brew install avocadoattack/tap/guacsweep`
- [ ] Continued refinement of Leftover Sweep's matching heuristics as real-world false-positive patterns get reported
- [ ] Optional: Xcode Archives cleanup, deliberately excluded from Xcode DerivedData handling since archives can hold real value, would need its own explicit opt-in

---

## 🤝 Contributing

PRs are welcome. The highest-value area to help with is **Leftover Sweep**: its bundle-identifier matching is deliberately conservative, and there's real room to improve how it handles Team-ID-prefixed containers, concatenated helper suffixes, and shared-SDK false positives, without sacrificing the review-before-anything-moves safety model.

Bug reports, scope suggestions, and reports of behavior on other macOS versions or Apple Silicon hardware are welcome too.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the process.

---

## 🙏 Acknowledgments

- **[PureMac](https://github.com/momenbasel/PureMac)** (MIT licensed), whose bundle-identifier matching approach directly informed how Leftover Sweep detects orphaned app data, and whose README was a direct inspiration for this one's structure and tone. No PureMac code was used, Swift and bash aren't interchangeable anyway, but the underlying technique was the model to build from.
- **[Mole](https://github.com/tw93/Mole)** (GPL-3.0 licensed; not to be confused with Mole for Mac, a separate proprietary app from the same author), whose dry-run safety UX and categorized reporting style shaped several of guacsweep's own UX decisions. A genuinely excellent, far more feature-complete tool if you want more than guacsweep's deliberately narrow scope.

---

## 📄 License

MIT, see [LICENSE](LICENSE).
