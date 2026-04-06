package hcore

import (
	"github.com/buudesh/inhive-core/v2/service_manager"
	daemon "github.com/sagernet/sing-box/daemon"
	"github.com/sagernet/sing-box/log"
)

var _ log.PlatformWriter = (*LogInterface)(nil)

type LogInterface struct{}

func (h *LogInterface) ServiceStop() error {
	return service_manager.OnMainServiceClose()
}
func (h *LogInterface) ServiceReload() error {
	return service_manager.OnMainServiceStart()

}
func (h *LogInterface) SystemProxyStatus() (*daemon.SystemProxyStatus, error) {
	return nil, nil
}
func (h *LogInterface) SetSystemProxyEnabled(enabled bool) error {
	return nil
}

func (h *LogInterface) WriteDebugMessage(message string) {
	h.WriteMessage(log.LevelDebug, message)
}
func (h *LogInterface) WriteMessage(level log.Level, message string) {
	Log(convertLogLevel(level), LogType_SERVICE, message)
}
func convertLogLevel(level log.Level) LogLevel {
	switch level {
	case log.LevelDebug:
		return LogLevel_DEBUG
	case log.LevelInfo:
		return LogLevel_INFO
	case log.LevelWarn:
		return LogLevel_WARNING
	case log.LevelError:
		return LogLevel_ERROR
	case log.LevelFatal:
		return LogLevel_FATAL
	}
	return LogLevel(log.LevelDebug)
}
