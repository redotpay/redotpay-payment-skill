# redotpay-payment

Enable your **AI Agent** (Cursor, Claude Code, Claude Desktop, Windsurf, Codex, Cline, and more) to handle **MPP 402 protocol payments** for you—including paid APIs and usage-based inference services—without the need to write payment code yourself.

This repository ships prebuilt binaries and a one-line install script.

## When to use

- You want your agent to handle authorization, pick a payment method, and complete payment on your behalf
- Your agent calls APIs that return `402 Payment Required`
- You already have a RedotPay account

## Install

To install immediately, run this command (no arguments needed):

```sh
curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh | sh
```

if you'd like to inspect the script before running it, do this:

```sh
curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh -o install.sh
less install.sh
sh install.sh
```

The installer will:

1. Download the latest build for your OS (macOS / Linux, with automatic CPU architecture detection)
2. Install `redotpay-payment` to `~/.local/bin` (or `/usr/local/bin` if writable)
3. Register the `redotpay-payment` MCP server in common Agent hosts
4. Install skill docs for Agents (global directories for Cursor, Claude, Codex, Cline, etc.)

**Prerequisite**: [`jq`](https://jqlang.org/) must be installed (macOS: `brew install jq`).

## After install

1. **Restart** your app (Cursor / Claude Code / Claude Desktop, etc.) so MCP is loaded.
2. Ask the agent to call a paid API. On the first use, if authorization is required, the agent will show a **QR code**—scan it with the **RedotPay App** to confirm.
3. After a successful authorization on the same device, later payments usually **do not require scanning again for every transaction**.

## Supported Agents

| Agent | MCP config | Skill |
|-------|------------|-------|
| Cursor | Global `~/.cursor/mcp.json` | `~/.cursor/skills/redotpay-payment/` |
| Claude Code | `~/.claude.json` | `~/.claude/skills/redotpay-payment/` |
| Claude Desktop | macOS app config | — |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` | — |
| Codex CLI | — | `~/.agents/skills/redotpay-payment/` |
| Cline | Add MCP manually in IDE settings | `~/.cline/skills/redotpay-payment/` |

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh | sh -s -- --uninstall
```

## FAQ

**What should I do if my agent can't find MCP after it is installed?**  
Restart the IDE / client; confirm `redotpay-payment` is enabled in MCP settings.

**What if jq is not found?**  
Install jq, then re-run the install command.

**What should I do if macOS keychain keeps prompting?**  
Choose **Always Allow** for the `~/.local/bin/redotpay-payment` binary in use. The installer uses a fixed path, so upgrades usually don't require re-authorization.

**What if I use Windows instead of Mac?**  
The one-line installer targets macOS / Linux. On Windows, download `windows_x86_64.zip` from [Releases](https://github.com/redotpay/redotpay-payment-skill/releases), unzip it, and point your Agent's MCP settings at the executable path.

## About this repo

- This contains only the install script and release artifacts
- Production traffic goes to the RedotPay API: `https://apiv2.redotpay.com`
- For support, please use RedotPay's official support channels. We look forward to serving you.
