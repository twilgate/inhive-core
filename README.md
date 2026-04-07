<p align="center">
  <img src="https://raw.githubusercontent.com/buudesh/inhive-core/main/assets/logo.svg" alt="InHive Logo" width="128">
</p>

<h1 align="center">InHive Core</h1>

<p align="center">
  <strong>The Ultimate Universal Proxy Platform</strong><br>
  A powerful, high-performance core for the InHive ecosystem, supporting all major protocols and platforms.
</p>

<p align="center">
  <a href="https://inhive.ru"><img src="https://img.shields.io/badge/Website-inhive.ru-blue?style=flat-square" alt="Website"></a>
  <a href="https://t.me/inhive_bot"><img src="https://img.shields.io/badge/Telegram-Join-blue?style=flat-square&logo=telegram" alt="Telegram"></a>
  <img src="https://img.shields.io/github/license/buudesh/inhive-core?style=flat-square" alt="License">
  <img src="https://img.shields.io/github/v/release/buudesh/inhive-core?style=flat-square" alt="Version">
</p>

---

## Quick Setup

Install `inhive-core` on any Linux platform (Ubuntu, Debian, CentOS, OpenWrt, and more) with a single command:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/buudesh/inhive-core/main/installer.sh)
```

> **Note:** This script automatically detects your OS and architecture, installs the appropriate binary, and configures the service manager (Systemd or Procd).

---

## Key Features

- **Multi-Protocol Support**: VLESS, VMess, Trojan, Shadowsocks, ShadowTLS, WireGuard, Hysteria, SOCKS, Naive, Mieru, Tor, and more.
- **Cross-Platform**: Powering InHive on Android, macOS, Linux, Windows, and iOS.
- **Extension System**: Third-party extension capability to modify configs and add custom features.
- **High Performance**: Optimized core built on top of `sing-box` for maximum speed and stability.
- **Router Ready**: Native support for OpenWrt and other router platforms.

---

## Installation Methods

### Docker
```bash
docker pull ghcr.io/buudesh/inhive-core:latest

# Or using Docker Compose
git clone https://github.com/buudesh/inhive-core
cd inhive-core/platform/docker
docker-compose up -d
```

### OpenWrt
Install via the universal installer script — it auto-detects OpenWrt and configures procd service.

---

## Roadmap

- [x] Fork and rebrand from Hiddify Core
- [x] CI/CD pipeline with GitHub Actions
- [x] Full code audit and dead code cleanup
- [x] Critical bug fixes (tunnel service, config builder, service manager)
- [x] Dependency updates (Go 1.26, grpc v1.80, sing v0.8.4, sing-box v1.13.6)
- [x] NaiveProxy support (Chromium TLS stack, undetectable by DPI)
- [ ] Smart failover — auto-switch between servers/IPs per carrier
- [ ] MTProto FakeTLS outbound — bypass LTE DPI whitelist restrictions
- [ ] TURN proxy outbound — WebRTC-based tunneling as fallback
- [ ] Split tunnel — exclude banking/gov apps from VPN
- [ ] InHive App integration (Flutter)

---

## Building

### Desktop (C shared library)
```bash
make windows-amd64
make linux-amd64
make macos
```

### Mobile (gomobile)
```bash
make android
make ios
```

---

## Team

| Role | Who |
|------|-----|
| **Idea & Product** | [@buudesh](https://github.com/buudesh) |
| **Core Development** | [Claude](https://claude.ai) (AI-assisted engineering) |

---

## License

[GPL-3.0-or-later](LICENSE.md) — based on [Hiddify](https://github.com/hiddify/hiddify-core) open-source project.
