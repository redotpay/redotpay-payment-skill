# 手动发布到 `redotpay/redotpay-payment-skill`

维护者本地构建 prod 二进制，**手动**上传到 GitHub Releases，并推送 `main` 上的 `install.sh` / skill / 公钥。

**首版推荐：不签名（路径 A）** — 无需 `release-signing.pem`；`install.sh` 用 `checksums.txt` 校验 SHA-256，无 `.sig` 也能安装。

## 路径 A：无签名手动发布（推荐）

### 前置

| 项 | 说明 |
|----|------|
| 公开发行仓 | `redotpay/redotpay-payment-skill`（public） |
| `jq` | 用户运行 `install.sh` 时需要 |
| 版本号 | 与 `Cargo.toml` 一致（当前 `0.1.0`） |

**不需要**：`gh`、`openssl`、Ed25519 私钥、`RELEASE_SIGNING_KEY_PATH`。

### 1. 本地构建

```sh
cd redotpay-payment-skill

./scripts/publish_distro.sh --version 0.1.0 --all-platforms build
./scripts/publish_distro.sh --version 0.1.0 checksums
```

产物目录：`dist/publish/0.1.0/`。

**Apple Silicon (M 系列)**：本机通常只有 2 个 darwin 包；linux / windows 用 GitHub Actions `release-skill-distro.yml` → **workflow_dispatch** 补全后，拷进同一 `dist/publish/0.1.0/`，再跑一次 `checksums`。

Release 应包含（**无** `*.sig` 亦可）：

| 文件 |
|------|
| `redotpay-payment_0.1.0_darwin_{aarch64,x86_64}.tar.gz` |
| `redotpay-payment_0.1.0_linux_{x86_64,aarch64}.tar.gz` |
| `redotpay-payment_0.1.0_windows_x86_64.zip` |
| `checksums.txt` |
| `latest.json` |

### 2. 手动推 `main`

仓根结构：

```text
install.sh
README.md
pubkey.pem
skills/redotpay-payment/SKILL.md
```

源文件在 monorepo `redotpay-payment-skill/distro/`（`install.sh` 在 `distro/install.sh`）。

GitHub 网页上传，或：

```sh
# 示例：本地 git 推送（不用 gh）
CRATE=/path/to/redotpay-payment/redotpay-payment-skill
git clone git@github.com:redotpay/redotpay-payment-skill.git /tmp/distro-push
cp "$CRATE/distro/install.sh" /tmp/distro-push/
cp "$CRATE/distro/README.md" /tmp/distro-push/
cp "$CRATE/distro/pubkey.pem" /tmp/distro-push/
cp -R "$CRATE/distro/skills" /tmp/distro-push/
cd /tmp/distro-push && chmod +x install.sh
git add install.sh README.md pubkey.pem skills
git commit -m "chore: sync distro for v0.1.0"
git push origin main
```

### 3. 手动创建 Release

1. `https://github.com/redotpay/redotpay-payment-skill/releases/new`
2. Tag：**`v0.1.0`**（须带 `v`）
3. 勾选 **Set as the latest release**
4. 上传 `dist/publish/0.1.0/` 里全部包 + `checksums.txt` + `latest.json`
5. Publish

### 4. 用户安装（对外唯一命令）

发布完成后，用户**只需**执行（无需任何参数）：

```sh
curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh | sh
```

安装脚本源文件：`redotpay-payment-skill/distro/install.sh` → 公开发行仓根目录 `install.sh`。

安装后重启 Cursor / Claude Code / Claude Desktop 以加载 MCP。

### 无签名时的影响

- `install.sh`：正常（SHA-256 + `checksums.txt`）
- `self_update` / Release `.sig`：首版无签名时不可用；不影响 MCP 代付

---

## 路径 B：带 Ed25519 签名（可选，以后）

需私钥与 `distro/pubkey.pem`、`src/update.rs::RELEASE_PUBKEY_HEX` 成对。若无私钥，可重新生成一对并**重编译全部 prod 二进制**后再 sign。

```sh
openssl genpkey -algorithm Ed25519 -out release-signing.pem
openssl pkey -in release-signing.pem -pubout -out distro/pubkey.pem
# 更新 src/update.rs RELEASE_PUBKEY_HEX 后重新 build
export RELEASE_SIGNING_KEY_PATH="$PWD/release-signing.pem"
./scripts/publish_distro.sh --version 0.1.0 sign
```

私钥勿提交 git；CI 用 Secret `RELEASE_SIGNING_KEY`。

---

## 平台构建说明

| 产物 | 构建方式 |
|------|----------|
| darwin aarch64 / x86_64 | 本机 `cargo`（M 系列可打两个 darwin） |
| linux / windows | Intel Mac / Linux x86_64 用 `cross`；M 系列建议 CI |

`cross` / rustup 报错见 monorepo `scripts/publish_distro.sh` 内 `ensure_cross` 注释；Apple Silicon 上 linux 目标可能 QEMU SIGSEGV。

## 用户安装

```sh
curl -fsSL https://raw.githubusercontent.com/redotpay/redotpay-payment-skill/main/install.sh | sh
```

无需参数；自动拉 **latest** Release。

## 与 CI

`.github/workflows/release-skill-distro.yml` 为可选自动化；与手动发同一版本时不要并发。
