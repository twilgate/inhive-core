#!/usr/bin/env bash
# ios_preflight.sh — Phase B-1 toolchain check + auto-install for InHive iOS build.
#
# Запускается ОДИН РАЗ на Mac перед первым `make ios`. Idempotent — можно
# гонять повторно, ничего не сломает. Печатает summary в конце:
#   ✅ — готово
#   ⚠️  — установлено через скрипт (потребует terminal restart)
#   ❌ — не смог (требует ручной операции)
#
# После успеха — следующий шаг описан в memory/project_ios_mac_day_runbook.md
# секции 3 (Build inhive-core xcframework).

set -uo pipefail   # НЕ -e: хочу пройти все checks даже если один упал

if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ macOS only. Detected: $(uname)"
    exit 1
fi

# ── Colors ──────────────────────────────────────────────────────────────────
G="\033[0;32m" Y="\033[1;33m" R="\033[0;31m" B="\033[0;34m" N="\033[0m"
PASS=()
WARN=()
FAIL=()

ok()   { echo -e "${G}✅${N} $1"; PASS+=("$1"); }
warn() { echo -e "${Y}⚠️ ${N} $1"; WARN+=("$1"); }
fail() { echo -e "${R}❌${N} $1"; FAIL+=("$1"); }
hdr()  { echo -e "\n${B}── $1 ──${N}"; }

# ── 0. Repo layout sanity ───────────────────────────────────────────────────
hdr "0. Repo layout"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -d "${REPO_ROOT}/core" || ! -d "${REPO_ROOT}/app" ]]; then
    fail "Repo layout broken: expected ${REPO_ROOT}/{core,app}"
    echo "    Запусти скрипт из папки <inhive>/scripts/ios_preflight.sh"
    exit 1
fi
ok "Repo root: ${REPO_ROOT}"

if [[ ! -f "${REPO_ROOT}/core/Makefile" ]]; then
    fail "core/Makefile отсутствует — git clone не до конца?"
    exit 1
fi
ok "core/Makefile найден"

if [[ ! -f "${REPO_ROOT}/app/ios/Base.xcconfig" ]]; then
    fail "app/ios/Base.xcconfig отсутствует — Phase A не задеплоена в этот checkout"
    exit 1
fi
ok "app/ios/Base.xcconfig найден"

if grep -q "DEVELOPMENT_TEAM=$" "${REPO_ROOT}/app/ios/Base.xcconfig" 2>/dev/null; then
    warn "DEVELOPMENT_TEAM пуст в Base.xcconfig — впиши Team ID или подставь в Xcode"
else
    TEAM_ID=$(grep -E "^DEVELOPMENT_TEAM=" "${REPO_ROOT}/app/ios/Base.xcconfig" | cut -d'=' -f2)
    ok "DEVELOPMENT_TEAM в Base.xcconfig: ${TEAM_ID}"
fi

# ── 1. Xcode & CLI tools ────────────────────────────────────────────────────
hdr "1. Xcode + Command Line Tools"

if ! command -v xcodebuild >/dev/null 2>&1; then
    fail "xcodebuild не найден — установи Xcode из App Store"
    echo "    https://apps.apple.com/app/xcode/id497799835"
    XCODE_OK=0
else
    XCODE_VER=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}')
    XCODE_MAJOR=$(echo "$XCODE_VER" | cut -d'.' -f1)
    if [[ "$XCODE_MAJOR" -lt 15 ]]; then
        fail "Xcode ${XCODE_VER} < 15 — обнови (нужен 15.4+ для iOS 17 SDK + современный NetworkExtension)"
        XCODE_OK=0
    else
        ok "Xcode ${XCODE_VER}"
        XCODE_OK=1
    fi
fi

if [[ "${XCODE_OK:-0}" == "1" ]]; then
    if xcode-select -p >/dev/null 2>&1; then
        XCS_PATH=$(xcode-select -p)
        ok "xcode-select path: ${XCS_PATH}"
    else
        warn "xcode-select не настроен — запусти: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    fi

    # Принять license если ещё не принято
    if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
        warn "Xcode first-launch ещё не пройден — запусти: sudo xcodebuild -runFirstLaunch"
    else
        ok "Xcode first-launch OK"
    fi
fi

if xcrun --find clang >/dev/null 2>&1; then
    ok "clang (Command Line Tools) — есть"
else
    warn "Command Line Tools отсутствуют — ставлю: xcode-select --install"
    xcode-select --install 2>/dev/null || true
fi

# ── 2. Homebrew ─────────────────────────────────────────────────────────────
hdr "2. Homebrew"

if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew не найден — устанавливаю..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || \
        fail "Homebrew install failed"
    # M-series Macs: brew в /opt/homebrew, Intel — /usr/local
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

if command -v brew >/dev/null 2>&1; then
    ok "brew $(brew --version | head -1 | awk '{print $2}')"
fi

# Универсальный helper: установить пакет если нет
ensure_brew_pkg() {
    local pkg="$1"
    local cmd="${2:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    warn "Устанавливаю ${pkg} через brew..."
    brew install "$pkg" >/dev/null 2>&1 || { fail "brew install ${pkg} failed"; return 1; }
    return 0
}

# ── 3. Go toolchain ─────────────────────────────────────────────────────────
hdr "3. Go (нужен 1.23+)"

if ! command -v go >/dev/null 2>&1; then
    ensure_brew_pkg "go"
fi

if command -v go >/dev/null 2>&1; then
    GO_VER=$(go version | awk '{print $3}' | sed 's/go//')
    GO_MAJOR=$(echo "$GO_VER" | cut -d'.' -f1)
    GO_MINOR=$(echo "$GO_VER" | cut -d'.' -f2)
    if [[ "$GO_MAJOR" -lt 1 || ( "$GO_MAJOR" -eq 1 && "$GO_MINOR" -lt 23 ) ]]; then
        warn "Go ${GO_VER} < 1.23 — обновляю: brew upgrade go"
        brew upgrade go >/dev/null 2>&1
        GO_VER=$(go version | awk '{print $3}' | sed 's/go//')
    fi
    ok "Go ${GO_VER}"
else
    fail "Go install failed — поставь руками: brew install go"
fi

# ── 4. gomobile (sagernet fork) ─────────────────────────────────────────────
hdr "4. gomobile (sagernet fork v0.1.12)"

GOPATH=$(go env GOPATH 2>/dev/null || echo "$HOME/go")
GOBIN="${GOPATH}/bin"

if [[ ! -x "${GOBIN}/gomobile" ]]; then
    warn "gomobile не найден — ставлю sagernet fork v0.1.12..."
    go install -v github.com/sagernet/gomobile/cmd/gomobile@v0.1.12 2>&1 | tail -3
    go install -v github.com/sagernet/gomobile/cmd/gobind@v0.1.12 2>&1 | tail -3
fi

if [[ -x "${GOBIN}/gomobile" ]]; then
    ok "gomobile в ${GOBIN}/gomobile"
    if ! echo "$PATH" | grep -q "$GOBIN"; then
        warn "GOBIN (${GOBIN}) НЕ в PATH — добавь в ~/.zshrc: export PATH=\$PATH:\$(go env GOPATH)/bin"
    fi
else
    fail "gomobile install не удался"
fi

# gomobile init — создаёт SDK references. Делается один раз.
if [[ -x "${GOBIN}/gomobile" ]]; then
    if ! "${GOBIN}/gomobile" version >/dev/null 2>&1; then
        warn "gomobile init не выполнен — запускаю..."
        "${GOBIN}/gomobile" init 2>&1 | tail -3
    fi
fi

# ── 5. Flutter ──────────────────────────────────────────────────────────────
hdr "5. Flutter (нужен 3.27+)"

if ! command -v flutter >/dev/null 2>&1; then
    warn "Flutter не найден — ставлю через brew (Flutter Cask)..."
    brew install --cask flutter 2>&1 | tail -3
fi

if command -v flutter >/dev/null 2>&1; then
    FLUTTER_VER=$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')
    FL_MAJOR=$(echo "$FLUTTER_VER" | cut -d'.' -f1)
    FL_MINOR=$(echo "$FLUTTER_VER" | cut -d'.' -f2)
    if [[ "$FL_MAJOR" -lt 3 || ( "$FL_MAJOR" -eq 3 && "$FL_MINOR" -lt 27 ) ]]; then
        warn "Flutter ${FLUTTER_VER} < 3.27 — обнови: flutter upgrade"
    fi
    ok "Flutter ${FLUTTER_VER}"

    # Flutter doctor для iOS
    if flutter doctor 2>&1 | grep -q "iOS toolchain"; then
        if flutter doctor 2>&1 | grep -A 2 "iOS toolchain" | grep -q "✓\|\[✓\]"; then
            ok "Flutter iOS toolchain ready"
        else
            warn "Flutter doctor показывает проблемы с iOS — запусти 'flutter doctor -v' для деталей"
        fi
    fi
else
    fail "Flutter install не удался — https://docs.flutter.dev/get-started/install/macos"
fi

# ── 6. CocoaPods ────────────────────────────────────────────────────────────
hdr "6. CocoaPods"

if ! command -v pod >/dev/null 2>&1; then
    warn "CocoaPods не найден — ставлю через brew..."
    brew install cocoapods 2>&1 | tail -3
fi

if command -v pod >/dev/null 2>&1; then
    POD_VER=$(pod --version 2>/dev/null)
    ok "CocoaPods ${POD_VER}"
else
    fail "CocoaPods не установлен — нужен для flutter ios pods"
fi

# ── 7. Optional: Rust + cargo-lipo (для DAITA, отложено) ───────────────────
hdr "7. Rust + cargo-lipo (опционально, DAITA отложен)"

if command -v cargo >/dev/null 2>&1; then
    ok "Rust $(rustc --version | awk '{print $2}') установлен"
    if command -v cargo-lipo >/dev/null 2>&1; then
        ok "cargo-lipo установлен"
    else
        warn "cargo-lipo не нужен прямо сейчас (DAITA в Phase A отложен)"
    fi
else
    warn "Rust не установлен — DAITA не будет, но iOS build пройдёт без него"
    echo "    Если понадобится: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
fi

# ── 8. Apple Developer signing readiness ────────────────────────────────────
hdr "8. Code signing"

# Список installed identities (Developer + Distribution certs)
if command -v security >/dev/null 2>&1; then
    # `security find-identity` пишет результат строкой `"     N valid identities found"`.
    # Раньше тут было `grep -c "valid"` — но эта же строка ВСЕГДА содержит слово "valid",
    # поэтому при N=0 grep возвращал 1 и скрипт ложно сообщал об одной identity.
    # awk достаёт N напрямую (первое поле), default 0 если security ничего не вывел.
    IDENT_COUNT=$(security find-identity -v -p codesigning 2>/dev/null | awk '/valid identities found/{print $1; exit}')
    IDENT_COUNT=${IDENT_COUNT:-0}
    if [[ "${IDENT_COUNT}" -gt 0 ]]; then
        ok "Найдено ${IDENT_COUNT} valid signing identities в keychain"
        echo "    Подробнее: security find-identity -v -p codesigning"
    else
        warn "В keychain нет signing identities. Решается через Xcode → Signing & Capabilities → Automatic"
        echo "    или через Apple Developer portal → Certificates → Apple Development"
    fi
fi

# Проверим что Xcode видит team
if [[ "${XCODE_OK:-0}" == "1" ]]; then
    if [[ -d "${HOME}/Library/MobileDevice/Provisioning Profiles" ]]; then
        PP_COUNT=$(ls "${HOME}/Library/MobileDevice/Provisioning Profiles" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "${PP_COUNT}" -gt 0 ]]; then
            ok "Provisioning profiles: ${PP_COUNT} штук"
        else
            warn "Нет provisioning profiles — будут созданы автоматически при first build из Xcode"
        fi
    fi
fi

# ── 9. Сборка готовности к make ios ────────────────────────────────────────
hdr "9. Готовность к make ios"

if [[ -x "${GOBIN}/gomobile" ]] && command -v go >/dev/null 2>&1 && [[ "${XCODE_OK:-0}" == "1" ]]; then
    ok "Можно запускать: cd ${REPO_ROOT}/core && make ios"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo -e "${B}SUMMARY${N}"
echo "═══════════════════════════════════════════════════════════════════════"
echo -e "${G}PASS:${N}  ${#PASS[@]}"
echo -e "${Y}WARN:${N}  ${#WARN[@]}"
echo -e "${R}FAIL:${N}  ${#FAIL[@]}"

if [[ ${#FAIL[@]} -gt 0 ]]; then
    echo ""
    echo -e "${R}Critical issues:${N}"
    for item in "${FAIL[@]}"; do echo "  ❌ $item"; done
    echo ""
    echo "Поправь FAIL items, потом запусти скрипт снова."
    exit 2
fi

if [[ ${#WARN[@]} -gt 0 ]]; then
    echo ""
    echo -e "${Y}Non-critical warnings:${N}"
    for item in "${WARN[@]}"; do echo "  ⚠️  $item"; done
    echo ""
    echo "WARN не блокируют — но при проблемах вернись к ним."
fi

echo ""
echo -e "${G}NEXT STEPS:${N}"
echo "  1. cd ${REPO_ROOT}/core && make ios"
echo "     → produces bin/InhiveCore.xcframework + auto-deploys to app/ios/Frameworks/"
echo ""
echo "  2. cd ${REPO_ROOT}/app"
echo "     flutter clean && flutter pub get"
echo "     cd ios && pod install --repo-update && cd .."
echo "     flutter build ios --debug --no-codesign"
echo ""
echo "  3. open ${REPO_ROOT}/app/ios/Runner.xcworkspace"
echo "     В Xcode см. memory/project_ios_mac_day_runbook.md секции 4-7:"
echo "       - Удалить red references в Project Navigator (Phase A artifacts)"
echo "       - Add Target → Network Extension → Packet Tunnel Provider"
echo "       - Использовать существующие файлы из app/ios/PacketTunnelProvider/"
echo "       - Set entitlements + signing"
echo "       - Build & Run на physical iPhone"
echo "       - Archive → TestFlight upload"
echo ""
echo "Удачи, бро."
exit 0
