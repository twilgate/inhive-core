// debug.go — saves configuration snapshots to disk for debugging.
package config

import (
	context "context"
	"fmt"
	"os"
	"path/filepath"
	"runtime/debug"

	"github.com/sagernet/sing-box/option"
)

func SaveCurrentConfig(ctx context.Context, path string, options option.Options) error {
	json, err := options.MarshalJSONContext(ctx)
	if err != nil {
		return err
	}
	p, err := filepath.Abs(path)
	os.MkdirAll(filepath.Dir(p), 0o755)
	fmt.Printf("Saving config to %v %+v\n", p, err)
	if err != nil {
		return err
	}
	return os.WriteFile(p, []byte(json), 0o600)
}

// DeferPanicToError recovers a panic, wraps it (with stack trace) into an error
// and hands it to the caller-supplied callback. Identical in behavior to
// RecoverPanicToError — kept as an alias for legacy call sites that historically
// relied on a 5-second post-recovery sleep (removed: it blocked CGo callbacks
// up to 10s when the callback also slept, contributing to iOS NE startup
// violations and Flutter UI freezes during DLL recovery).
//
// If a caller really needs to flush a buffered logger before returning, do it
// explicitly inside the callback (e.g. logger.Sync()).
func DeferPanicToError(name string, err func(error)) {
	if r := recover(); r != nil {
		s := fmt.Errorf("%s panic: %s\n%s", name, r, string(debug.Stack()))
		err(s)
	}
}

// RecoverPanicToError is a non-blocking variant of DeferPanicToError intended
// for hot paths: gRPC per-RPC handlers, cgo //export wrappers and long-running
// goroutines.
func RecoverPanicToError(name string, err func(error)) {
	if r := recover(); r != nil {
		s := fmt.Errorf("%s panic: %s\n%s", name, r, string(debug.Stack()))
		err(s)
	}
}
