// Package hcore — diagnostic logging для iOS NE process до момента когда
// openTun callback в Swift InhivePlatformInterface достигнут. Build 33
// addition (2026-05-09).
//
// Background: Build 30+ висел в `NewService(ctx, *options)` (start.go:143)
// 6 минут ДО openTun callback. Swift writeSharedLog calls внутри
// InhivePlatformInterface.openTun никогда не запускались, потому что Go
// MobileStart блокировал прежде чем sing-box engine достигнет TUN inbound
// init (которое и вызывает openTun).
//
// Решение: Go-side `WriteSharedLog` пишет в same App Group shared file
// (`<workingDir>/ne_last_error.log`) что Swift writeSharedError. Главное —
// это позволяет diagnostic запись из Go ДО момента когда openTun reached.
//
// File path = `sWorkingPath/ne_last_error.log`. `sWorkingPath` set в
// `grpc_server.go:67` от `params.WorkingDir` который Swift передаёт через
// `MobileSetupOptions.workingDir = workingDir.path` (App Group container's
// `inhive-core/` directory).
//
// После tunnel up успешно — Swift `writeSharedError(nil)` (line 50 of
// PacketTunnelProvider.swift) clear файла. Так что после успешного start
// файл pусто. После hang/crash — UI показывает где конкретно остановилось.

package hcore

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

var (
	sharedLogMu sync.Mutex
)

// WriteSharedLog appends a timestamped diagnostic line to the App Group
// shared log file. Failures (file open/write) are silently swallowed —
// diagnostic logging shouldn't break tunnel startup.
//
// Use sparingly for major step boundaries (BuildConfig, NewService entry/exit,
// outbound init). NOT for per-packet or hot-path logging.
func WriteSharedLog(msg string) {
	if sWorkingPath == "" {
		return // Setup() не был вызван — нет workingDir
	}
	sharedLogMu.Lock()
	defer sharedLogMu.Unlock()

	path := filepath.Join(sWorkingPath, "ne_last_error.log")
	line := fmt.Sprintf("[%s] %s\n", time.Now().UTC().Format("2006-01-02 15:04:05.000 -0700"), msg)

	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.WriteString(line)
}

// WriteSharedLogf — convenience wrapper для format strings.
func WriteSharedLogf(format string, args ...any) {
	WriteSharedLog(fmt.Sprintf(format, args...))
}
