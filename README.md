# redotpay-payment

MPP 代付 MCP server — 预编译二进制一键安装（无需 Rust 工具链）。

生产环境 API：`https://apiv2.redotpay.com`

## Install

无需任何参数：

```sh
curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh | sh
```

审阅后再执行（推荐）：

```sh
curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh -o install.sh
less install.sh
sh install.sh
```

自动行为：拉取 **latest** Release、检测本机平台、安装二进制 + MCP + 多 Agent skill。

高级选项（一般不需要）：

```sh
sh install.sh --uninstall
sh install.sh --dry-run
```

安装内容：二进制 → `~/.local/bin`（或 `--install-dir`）、MCP（Cursor / Claude Code / Claude Desktop / Windsurf）、全局 skills（cursor / claude / codex / cline）。

安装后请 **重启 Cursor / Claude Code / Claude Desktop** 以加载 MCP。

## macOS Keychain 重复弹窗

若每次启动 MCP 都提示钥匙串授权：对 **当前正在运行的** `redotpay-payment` 二进制点「始终允许」；`cargo build` 会改变 ad-hoc 签名导致需重新授权。本安装器使用固定路径 `~/.local/bin/redotpay-payment`，升级后一般无需重复授权。

## Support

问题反馈请通过 RedotPay 官方支持渠道。本仓库不含 Rust 源码。
