#!/usr/bin/env bash
# build_libmaybenot_ios.sh — собирает libmaybenot.a (Rust FFI) под iOS device + simulator.
#
# Назначение:
#   InHive iOS NetworkExtension использует InhiveCore.xcframework (gomobile bind).
#   Go-обёртка core/sing-box/common/daita/daita.go линкуется через cgo к
#   libmaybenot.a (staticlib из core/maybenot/crates/maybenot-ffi). Под iOS
#   нужны 2 fat-архива: device (arm64) и simulator (arm64+x86_64 lipo).
#
# Раскладка вывода (xcframework-friendly):
#   core/bin/libmaybenot/ios-arm64/libmaybenot.a                       (device)
#   core/bin/libmaybenot/ios-arm64_x86_64-simulator/libmaybenot.a      (sim universal)
#
# Mac-only — Rust apple targets кросс-собирать с Win/Linux нельзя.
#
# Usage:  ./scripts/build_libmaybenot_ios.sh

set -euo pipefail

# ── Pre-flight ────────────────────────────────────────────────────────────────

if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: macOS only (Rust apple targets требуют Xcode + ld64)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Где живёт Rust workspace maybenot. На сегодня — git-vendor внутри core/.
# Если Никита решит вынести в submodule на верхний уровень — поправить тут.
MAYBENOT_DIR="${CORE_ROOT}/maybenot"
FFI_CRATE_DIR="${MAYBENOT_DIR}/crates/maybenot-ffi"

if [[ ! -d "${MAYBENOT_DIR}" ]]; then
    cat >&2 <<EOF
ERROR: ${MAYBENOT_DIR} not found.

TODO (Никита): крейт maybenot ещё не вынесен в ожидаемое место.
Варианты:
  1. git submodule add https://github.com/maybenot-io/maybenot.git core/maybenot
  2. git subtree add --prefix=core/maybenot https://github.com/maybenot-io/maybenot.git main --squash
  3. cp -r <локальный clone> core/maybenot
Скрипт ожидает Cargo.toml workspace в:  ${MAYBENOT_DIR}/Cargo.toml
И ffi crate в:                          ${FFI_CRATE_DIR}/Cargo.toml
EOF
    exit 1
fi

if [[ ! -f "${FFI_CRATE_DIR}/Cargo.toml" ]]; then
    echo "ERROR: ${FFI_CRATE_DIR}/Cargo.toml not found — структура maybenot повредилась?" >&2
    exit 1
fi

# ── Toolchain checks ──────────────────────────────────────────────────────────

if ! command -v rustup >/dev/null 2>&1; then
    cat >&2 <<EOF
ERROR: rustup не установлен.
Install:  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
EOF
    exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
    echo "ERROR: cargo не в PATH (rustup установлен но shell не подхватил $HOME/.cargo/bin)." >&2
    exit 1
fi

if ! command -v lipo >/dev/null 2>&1; then
    echo "ERROR: lipo не найден — поставь Xcode Command Line Tools: xcode-select --install" >&2
    exit 1
fi

# Targets — добавим если нет
TARGETS=(aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios)
INSTALLED_TARGETS="$(rustup target list --installed)"
for t in "${TARGETS[@]}"; do
    if ! grep -q "^${t}$" <<<"${INSTALLED_TARGETS}"; then
        echo "[+] rustup target add ${t}"
        rustup target add "${t}"
    else
        echo "[=] target ${t} already installed"
    fi
done

# cargo-lipo опционально — мы и сами умеем lipo, но если есть, используем для красоты.
if ! command -v cargo-lipo >/dev/null 2>&1; then
    echo "[+] cargo-lipo not found, installing (optional but handy)…"
    cargo install cargo-lipo || echo "[!] cargo-lipo install failed — fallback to manual lipo (всё ОК)"
fi

# ── Build per target ──────────────────────────────────────────────────────────

# RUSTFLAGS повторяет existing Makefile maybenot-ffi (metadata=maybenot-ffi нужен
# чтобы symbol mangling совпало с тем что cbindgen зашил в maybenot.h).
export RUSTFLAGS="${RUSTFLAGS:-} -C metadata=maybenot-ffi"

CARGO_TARGET_DIR="${MAYBENOT_DIR}/target"
export CARGO_TARGET_DIR

echo
echo "────── building libmaybenot_ffi.a for iOS targets ──────"
for t in "${TARGETS[@]}"; do
    echo
    echo "── target: ${t}"
    (
        cd "${FFI_CRATE_DIR}"
        cargo build --release --target "${t}"
    )
    if [[ ! -f "${CARGO_TARGET_DIR}/${t}/release/libmaybenot_ffi.a" ]]; then
        echo "ERROR: cargo не произвёл libmaybenot_ffi.a для ${t}" >&2
        exit 1
    fi
done

# ── Layout into core/bin/libmaybenot/ ─────────────────────────────────────────

OUT_ROOT="${CORE_ROOT}/bin/libmaybenot"
DEVICE_DIR="${OUT_ROOT}/ios-arm64"
SIM_DIR="${OUT_ROOT}/ios-arm64_x86_64-simulator"
mkdir -p "${DEVICE_DIR}" "${SIM_DIR}"

# Device — просто copy, в имя без _ffi (так ожидает -lmaybenot в cgo LDFLAGS).
cp "${CARGO_TARGET_DIR}/aarch64-apple-ios/release/libmaybenot_ffi.a" \
   "${DEVICE_DIR}/libmaybenot.a"

# Simulator — lipo merge arm64-sim + x86_64-sim
lipo -create \
    "${CARGO_TARGET_DIR}/aarch64-apple-ios-sim/release/libmaybenot_ffi.a" \
    "${CARGO_TARGET_DIR}/x86_64-apple-ios/release/libmaybenot_ffi.a" \
    -output "${SIM_DIR}/libmaybenot.a"

# Также положим maybenot.h рядом (cgo берёт его относительно SRCDIR пакета,
# но для xcframework-style hand-link удобно иметь header в ту же папку).
cp "${FFI_CRATE_DIR}/maybenot.h" "${DEVICE_DIR}/maybenot.h"
cp "${FFI_CRATE_DIR}/maybenot.h" "${SIM_DIR}/maybenot.h"

# ── Verify ────────────────────────────────────────────────────────────────────

echo
echo "────── verify ──────"
echo
echo "[device]   ${DEVICE_DIR}/libmaybenot.a"
ls -lh "${DEVICE_DIR}/libmaybenot.a" | awk '{print "  size:", $5}'
lipo -info "${DEVICE_DIR}/libmaybenot.a" || true

echo
echo "[sim fat]  ${SIM_DIR}/libmaybenot.a"
ls -lh "${SIM_DIR}/libmaybenot.a" | awk '{print "  size:", $5}'
lipo -info "${SIM_DIR}/libmaybenot.a" || true

echo
echo "[symbol sanity] expecting maybenot_start / maybenot_on_events / maybenot_stop"
for arch_a in "${DEVICE_DIR}/libmaybenot.a" "${SIM_DIR}/libmaybenot.a"; do
    echo "  ${arch_a}:"
    nm -gU "${arch_a}" 2>/dev/null | grep -E '_maybenot_(start|stop|on_events|num_machines)' | head -8 || \
        echo "  WARN: ожидаемые символы не найдены (nm failed?)"
done

# ── README hint for Makefile ios target ───────────────────────────────────────

cat <<'EOF'

════════════════════════════════════════════════════════════════════════════
Готово. Чтобы линкануть libmaybenot.a в gomobile bind (ios target):

В core/Makefile, target `ios:` нужно:

  1. Добавить тэг сборки `daita` в IOS_ADD_TAGS:
       IOS_ADD_TAGS=with_dhcp,with_low_memory,with_purego,daita

  2. Передать LDFLAGS через CGO_LDFLAGS environment, разный per-arch
     (gomobile разводит сам по target). Для ios/arm64 device:
       CGO_LDFLAGS="-L$(CORE_ROOT)/bin/libmaybenot/ios-arm64 -lmaybenot -lm"
     Для iossimulator (arm64 + amd64):
       CGO_LDFLAGS="-L$(CORE_ROOT)/bin/libmaybenot/ios-arm64_x86_64-simulator -lmaybenot -lm"

  3. ВНИМАНИЕ: текущий daita.go жёстко прописывает Windows-libs в #cgo LDFLAGS:
       #cgo LDFLAGS: -L${SRCDIR} -lmaybenot -lm -lntdll -lws2_32 -luserenv -lbcrypt
     Под iOS эти `-lntdll/-lws2_32/-luserenv/-lbcrypt` сломают линковку.
     План: вынести platform-specific LDFLAGS в build-tagged файлы:
       daita_cgo_windows.go    //go:build daita && windows
       daita_cgo_darwin.go     //go:build daita && (darwin || ios)
       daita_cgo_linux.go      //go:build daita && linux
       daita_cgo_android.go    //go:build daita && android
     В darwin-варианте: `#cgo LDFLAGS: -lmaybenot -lm` (плюс System.framework
     уже линкуется gomobile дефолтно).

  4. После реструктуризации запустить:  make ios
     В bin/InhiveCore.xcframework должна быть схема ios-arm64 +
     ios-arm64_x86_64-simulator (как у этого скрипта).

Всё — Никита.
════════════════════════════════════════════════════════════════════════════
EOF

echo
echo "DONE. Output: ${OUT_ROOT}"
