# Claude Meter

A tiny macOS menu-bar meter for your Claude usage — the same `session` and `week`
percentages that Claude Code's `/usage` command shows, sitting up next to your
battery indicator.

```
􀙇 11% · 5%      ← session (5h) · week (7d)
```

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

If the access token has expired, the app refreshes it via
`https://platform.claude.com/v1/oauth/token` and writes the rotated token back to
the same keychain item, preserving every other field so it stays compatible with
Claude Code itself. No data leaves your machine except the two Anthropic calls.

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

## Architecture

The logic is split so it can be tested without AppKit, the keychain, or the network:

- **`ClaudeMeterCore`** — pure, dependency-free: models, JSON parsing
  (`UsageParser`), and presentation helpers (`Formatting`). All unit tests target this.
- **`ClaudeMeter`** — the executable: keychain I/O (`Keychain`), the network client
  (`UsageClient`), and the AppKit menu-bar UI (`AppDelegate`).

```bash
swift test     # 26 tests covering parsing, token-blob rewrite, dates, and formatting
swift build    # debug build of the executable
```

## Notes

This uses an internal, undocumented endpoint that Anthropic may change without
notice. It's a fun local utility, not an official tool.
