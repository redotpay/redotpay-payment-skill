# RedotPay Payment Skill

Agent skill for use **[MPP services](https://mpp.dev/)**: discover services (`redotpay wallet services list --search`), inspect endpoints and pricing, get explicit user confirmation, then run paid calls with `redotpay request` when appropriate. Full instructions live in `[skills/redotpay-payment/SKILL.md](skills/redotpay-payment/SKILL.md)`.

## One-shot install (agent reads the URL and sets up)

These patterns are **convenience prompts**: the agent fetches the raw `SKILL.md`, then creates the right directory layout (`.../redotpay-payment/SKILL.md`) for each tool. You still need the **[redotpay CLI](https://github.com/redotpay/redotpay-cli)** on your machine; the skill only tells the agent how to use it.

### Codex

```bash
codex exec "Read https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/skills/redotpay-payment/SKILL.md and install to ~/.codex/skills/redotpay-payment/SKILL.md."
```

### Claude Code

Non-interactive one-shot (see [CLI reference](https://code.claude.com/docs/en/cli-reference)):

```bash
claude -p "Read https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/skills/redotpay-payment/SKILL.md and install to ~/.claude/skills/redotpay-payment/SKILL.md (or .claude/skills/redotpay-payment/SKILL.md in this repo)."
```

For stricter tool control in automation, add flags such as `--allowedTools`, `--max-turns`, or `--max-budget-usd` per your [headless / production docs](https://code.claude.com/docs/en/headless).

### Amp

Amp discovers skills under paths such as `~/.config/agents/skills/`, `~/.config/amp/skills/`, and `.agents/skills/` (see [Amp manual — Agent Skills](https://ampcode.com/manual)). Example:

```bash
amp -x "Read https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/skills/redotpay-payment/SKILL.md and install to ~/.config/agents/skills/redotpay-payment/SKILL.md."
```

## Using with Cursor

This repository includes a committed Cursor project rule `[.cursor/rules/redotpay-payment.mdc](.cursor/rules/redotpay-payment.mdc)`, so the same RedotPay workflow applies automatically when you open this project in Cursor.

See `[CURSOR.md](CURSOR.md)` for:

- setup checks in this repository,
- using the same rule in other projects, and
- installing as a personal/global Cursor skill (`~/.cursor/skills/...`).

