# Claude Meter

A tiny macOS menu-bar meter for your Claude usage — the same `session` and `week`
numbers that Claude Code's `/usage` command shows, sitting up next to your
battery indicator.

The glyph is **two concentric donuts**, each split into two lanes:

```
outer donut = session (5h):  outer lane = usage,  inner lane = time-left
inner donut = week   (7d):  outer lane = usage,  inner lane = time-left
```

Every lane is full when there's plenty left and is eaten away counter-clockwise
from the top as that metric is consumed — full rings at a fresh start, empty at
100% used / at reset. The lanes tint orange then red as usage gets high.

Click it for the full breakdown:

```
Session (5h):  █·········  11%  · resets 2h 14m
Week (7d):     ··········   5%  · resets 1d 3h
Week · Sonnet: ··········   1%
──────────────
Updated 8s ago
Refresh now
Refresh every  ▸
Launch at Login
Quit Claude Meter
```

## How it works

It reads the OAuth token Claude Code already stores in your login keychain
(`Claude Code-credentials`) and calls the same endpoint the CLI uses:

```
GET https://api.anthropic.com/api/oauth/usage
```

The response is exactly what powers `/usage`:

| Field              | Meaning                          |
|--------------------|----------------------------------|
| `five_hour`        | Rolling 5-hour session window    |
| `seven_day`        | 7-day (weekly) window            |
| `seven_day_opus`   | Weekly Opus-specific window      |
| `seven_day_sonnet` | Weekly Sonnet-specific window    |
| `extra_usage`      | Pay-as-you-go credit state       |

Each window reports a `utilization` percent and a `resets_at` timestamp.

### Read-only by design

Claude Meter **never refreshes or writes the OAuth token** — it only reads it.
This is deliberate: the refresh token is single-use and rotating, and shared with
Claude Code. If Claude Meter refreshed it, Claude Code's copy would be invalidated
and you'd be forced to re-login; writing to the keychain item would also disturb
its access-control list and re-prompt other processes. Instead, Claude Meter
re-reads the token on every poll, so it automatically picks up whatever token
Claude Code currently holds. If the token is expired and Claude Code isn't running,
the call simply 401s and the menu shows "open Claude Code". The only network
traffic is the single usage GET.

## Build & run

```bash
./build.sh          # builds ClaudeMeter.app (ad-hoc signed, menu-bar agent)
open ClaudeMeter.app
```

To install and auto-start:

```bash
mv ClaudeMeter.app /Applications/
# then: menu-bar dropdown → Launch at Login
```

**First launch:** macOS may prompt once for keychain access to
`Claude Code-credentials` (the app is a different code identity than Claude Code).
Click **Always Allow**.

**Stop repeated keychain prompts:** ad-hoc signatures change on every build, so
macOS treats each rebuild as a new app and re-asks. To make "Always Allow" stick,
create a one-time self-signed code-signing identity (no Apple account needed):
Keychain Access → *Certificate Assistant* → *Create a Certificate…* → name it
`ClaudeMeter Local Signing`, Identity Type *Self Signed Root*, Certificate Type
*Code Signing*. `build.sh` auto-detects it (or set `CLAUDE_METER_SIGN_ID`).

## Architecture

The logic is split so it can be tested without AppKit, the keychain, or the network:

- **`ClaudeMeterCore`** — pure, dependency-free: models, JSON parsing
  (`UsageParser`), presentation helpers (`Formatting`), and the donut/lane math
  (`RingGeometry`). All unit tests target this.
- **`ClaudeMeter`** — the executable: keychain reads (`Keychain`), the network
  client (`UsageClient`), the icon renderer (`RingIcon`), and the AppKit menu-bar
  UI (`AppDelegate`).

```bash
swift test     # 34 tests: parsing, dates, formatting, and ring/time geometry
swift build    # debug build of the executable
```

## Notes

This uses an internal, undocumented endpoint that Anthropic may change without
notice. It's a fun local utility, not an official tool.
