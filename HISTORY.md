# Changelog

All notable changes to InHive Core will be documented in this file.

---

## [1.0.0] — 2026-04-07

### The Fork

InHive Core is born — a fork of [Hiddify Core](https://github.com/hiddify/hiddify-core) (v4.1.0, sing-box v1.13.0), rebranded and cleaned up for the InHive ecosystem.

### Added
- New branding: InHive Core (`github.com/buudesh/inhive-core`)
- CI/CD pipeline with GitHub Actions (build + vet on every push)
- Recursive submodule checkout with SSH→HTTPS rewrite for CI
- New logo and assets

### Fixed
- **`fmt.Sprint` → `fmt.Sprintf`** in tunnel service — port number was not formatted into address string
- **Reversed `strings.HasPrefix` arguments** in config builder — domain prefix check was always false
- **Unreachable code in `patchWarp`** — entire WARP key generation block after premature `return nil`
- **`RegisterPreService` appending to wrong slice** — pre-services were added to regular services slice
- **Infinite recursion in `UnmarshalJSON`** — `Form.UnmarshalJSON` called itself instead of using alias pattern (fixed earlier)
- **USE-AFTER-FREE in desktop CGO** — removed dangerous signal handling code

### Removed
- ~375 lines of dead/commented-out code across 15 files
- Deleted entirely dead files: `rules.go`, `system_proxy.go`
- Removed deprecated Xray outbound support code (128 lines)
- Removed unused `DesktopPlatformInterface` implementation (64 lines)
- Removed legacy gRPC streaming implementations
- Removed pprof debug import from mobile platform
- Cleaned up root directory: removed `.prettierrc`, `.stignore`, `.gitchangelog.rc`, `cmd.bat`, `cmd.sh`, `build_windows.bat`, `CONTRIBUTING.md`

### Changed
- Full rebrand: HiddifyOptions → InhiveOptions, hiddify-core → inhive-core across all files
- Updated `Info.plist` bundle ID: `ios.hiddifycore.hiddify` → `ru.inhive.core`
- Updated `Makefile` library names: `hiddify-core` → `inhive-core`
- Updated `installer.sh` repo path and binary search pattern
- Updated `.fpm_openwrt` and `.fpm_systemd` config paths and maintainer
- Cleaned platform/desktop/custom.go — removed all commented-out signal handling
- Cleaned platform/mobile/mobile.go — removed unused alternative Start signature

---

## Pre-fork History

For the complete changelog of Hiddify Core (v0.1.0 through v4.1.0), see the [original repository](https://github.com/hiddify/hiddify-core/blob/main/HISTORY.md).
