// warp.go — WARP config generation stub (returns empty config).
package hcore

import (
	"context"
)

func (s *CoreService) GenerateWarpConfig(ctx context.Context, in *GenerateWarpConfigRequest) (*WarpGenerationResponse, error) {
	return GenerateWarpConfig(in)
}

func GenerateWarpConfig(in *GenerateWarpConfigRequest) (*WarpGenerationResponse, error) {
	return &WarpGenerationResponse{
		Config:  &WarpWireguardConfig{},
		Account: &WarpAccount{},
	}, nil
}
