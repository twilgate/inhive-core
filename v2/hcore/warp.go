// warp.go — WARP config generation stub (returns empty config).
package hcore

import (
	"context"

	"github.com/twilgate/inhive-core/v2/config"
)

func (s *CoreService) GenerateWarpConfig(ctx context.Context, in *GenerateWarpConfigRequest) (resp *WarpGenerationResponse, err error) {
	defer config.RecoverPanicToError("CoreService.GenerateWarpConfig", func(e error) {
		Log(LogLevel_FATAL, LogType_CORE, e.Error())
		err = e
	})
	return GenerateWarpConfig(in)
}

func GenerateWarpConfig(in *GenerateWarpConfigRequest) (*WarpGenerationResponse, error) {
	return &WarpGenerationResponse{
		Config:  &WarpWireguardConfig{},
		Account: &WarpAccount{},
	}, nil
}
