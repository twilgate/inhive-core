#!/bin/bash
# Постобработка InhiveCore.xcframework после `make ios` для App Store
# валидации.
#
# gomobile bind v0.1.12 (sagernet fork) генерит framework со следующими
# проблемами для iOS:
#   1. Info.plist почти пустой (`<dict></dict>`) — Apple отклоняет на
#      missing CFBundleIdentifier / MinimumOSVersion / CFBundleExecutable
#   2. Структура macOS-style (`Versions/A/...`) — iOS требует flat
#      structure (`InhiveCore.framework/{InhiveCore,Headers,Modules,
#      Info.plist}` напрямую)
#
# Этот script патчит ТОЛЬКО iOS slices (`ios-arm64/`,
# `ios-arm64_x86_64-simulator/`). macOS slices (`macos-arm64_x86_64`,
# когда добавим Phase B-3) НЕ трогаются — для macOS native frameworks
# Versions/A это правильный standard.
#
# Запускать ПОСЛЕ `make ios` и ДО `xcodebuild archive`.

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${REPO_ROOT}/../app"
XCFW="${APP_DIR}/ios/Frameworks/InhiveCore.xcframework"

if [[ ! -d "$XCFW" ]]; then
    echo "❌ xcframework не найден: $XCFW"
    echo "   Сначала: cd ${REPO_ROOT} && make ios"
    exit 1
fi

write_plist() {
    local target="$1"
    local platform="$2"   # iPhoneOS | iPhoneSimulator
    local min_os="$3"     # 16.0 для iOS

    cat > "$target" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>InhiveCore</string>
    <key>CFBundleIdentifier</key>
    <string>com.twilgate.InhiveCore</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>InhiveCore</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>${platform}</string>
    </array>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>${min_os}</string>
</dict>
</plist>
EOF
}

flatten_ios_slice() {
    local slice="$1"
    local platform="$2"
    local fw="${XCFW}/${slice}/InhiveCore.framework"

    if [[ ! -d "$fw" ]]; then
        echo "⚠️  slice не существует: $slice — skip"
        return
    fi

    # Если всё ещё macOS-style (Versions/A/) — flatten.
    if [[ -d "${fw}/Versions/A" ]]; then
        echo "→ flatten ${slice}"

        # В macOS-style root содержит симлинки (InhiveCore → Versions/Current/InhiveCore,
        # Headers → ..., etc). cp не может overwrite symlink на свою цель — выдаёт
        # "identical". Сначала разорвать symlinks (но запомнить real targets),
        # потом скопировать contents в root.
        local tmp="${fw}.tmp_flatten"
        rm -rf "$tmp"
        mkdir "$tmp"

        # Скопировать real files из Versions/A/ в tmp (resolve symlinks).
        cp "${fw}/Versions/A/InhiveCore" "${tmp}/InhiveCore"
        if [[ -d "${fw}/Versions/A/Headers" ]]; then
            cp -RL "${fw}/Versions/A/Headers" "${tmp}/Headers"
        fi
        if [[ -d "${fw}/Versions/A/Modules" ]]; then
            cp -RL "${fw}/Versions/A/Modules" "${tmp}/Modules"
        fi

        # Снести оригинал с Versions/A wrapper и symlinks.
        rm -rf "$fw"
        mkdir -p "$fw"

        # Положить flat content.
        mv "${tmp}/InhiveCore" "${fw}/InhiveCore"
        [[ -d "${tmp}/Headers" ]] && mv "${tmp}/Headers" "${fw}/Headers"
        [[ -d "${tmp}/Modules" ]] && mv "${tmp}/Modules" "${fw}/Modules"
        rm -rf "$tmp"
    fi

    # Перезаписать Info.plist в **root** framework dir (flat iOS structure).
    write_plist "${fw}/Info.plist" "$platform" "16.0"
    # Удалить старый Resources/ если остался от macOS-style.
    rm -rf "${fw}/Resources"

    echo "✓ ${slice} flattened + Info.plist patched"
}

flatten_ios_slice "ios-arm64" "iPhoneOS"
flatten_ios_slice "ios-arm64_x86_64-simulator" "iPhoneSimulator"

echo ""
echo "Verify ios-arm64 structure:"
find "${XCFW}/ios-arm64/InhiveCore.framework" -maxdepth 1 -mindepth 1 | sort

echo ""
echo "Done. Теперь можно делать xcodebuild archive."
