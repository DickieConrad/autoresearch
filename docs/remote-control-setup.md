# Claude Code Remote Control — Persistent Server Setup

Access your full Claude Code environment from your phone. No third-party bridges,
no Telegram bots, no port forwarding. Uses Anthropic's built-in remote control
over outbound HTTPS.

## How It Works

`claude remote-control` (run as a standalone command, not inside a session) starts
a dedicated server for a directory. It registers with Anthropic's servers so the
Claude mobile app and claude.ai/code can discover and connect to it. You can then
start **new sessions** from your phone — not just join existing ones.

All your CLAUDE.md context, MCP servers, memory files, and project setup carry over.

## Quick Start

```bash
# One-time: enable remote control globally
# Run /config inside any Claude Code session → Enable Remote Control for all sessions

# Start the persistent server (foreground, for testing)
claude remote-control

# Or use the setup script to install as a system service
./scripts/setup-remote-control.sh /path/to/your/project
```

## Setup Script

The included `scripts/setup-remote-control.sh` automates service installation:

- **macOS**: Creates a `launchd` plist at `~/Library/LaunchAgents/com.claude.remote-control.plist`
- **Linux**: Creates a `systemd` user service at `~/.config/systemd/user/claude-remote-control.service`

Both configure the service to start on login and restart on failure.

### Usage

```bash
# Install with default directory (current working directory)
./scripts/setup-remote-control.sh

# Install with specific project directory
./scripts/setup-remote-control.sh ~/projects/my-app
```

### Management

**macOS (launchd)**:
```bash
# Stop
launchctl bootout gui/$(id -u)/com.claude.remote-control

# Start
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.claude.remote-control.plist

# Status
launchctl print gui/$(id -u)/com.claude.remote-control

# Logs
tail -f /tmp/claude-remote-control.log
```

**Linux (systemd)**:
```bash
systemctl --user stop claude-remote-control
systemctl --user start claude-remote-control
systemctl --user status claude-remote-control
journalctl --user -u claude-remote-control -f
```

## Connecting

1. Open the Claude iOS/Android app → **Claude Code** tab
2. Your machine appears as a folder option
3. Start a new session — full context, MCP servers, and memory are available

Or visit [claude.ai/code](https://claude.ai/code) from any browser.

## Limitations

- Slash commands are not yet available through remote sessions
- One server instance binds to one project directory
- Requires the Claude mobile app or claude.ai/code (no raw API access)

## References

- [Claude Code Remote Control docs](https://docs.anthropic.com/en/docs/claude-code/remote-control)
