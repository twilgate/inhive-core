package sdk

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"runtime"
	"strings"

	"github.com/buudesh/inhive-core/v2/config"
	hcore "github.com/buudesh/inhive-core/v2/hcore"
	"github.com/sagernet/sing-box/option"
)

func RunInstance(ctx context.Context, inhiveSettings *config.InhiveOptions, singconfig *option.Options) (*hcore.InhiveInstance, error) {
	return hcore.RunInstance(ctx, inhiveSettings, singconfig)
}

func ParseConfig(ctx context.Context, inhiveSettings *config.InhiveOptions, configStr string) (*option.Options, error) {
	if inhiveSettings == nil {
		inhiveSettings = config.DefaultInhiveOptions()
	}
	if strings.HasPrefix(configStr, "http://") || strings.HasPrefix(configStr, "https://") {
		client := &http.Client{}
		configPath := strings.Split(configStr, "\n")[0]
		// Create a new request
		req, err := http.NewRequest("GET", configPath, nil)
		if err != nil {
			fmt.Println("Error creating request:", err)
			return nil, err
		}
		req.Header.Set("User-Agent", "InHiveNext/2.3.1 ("+runtime.GOOS+") like ClashMeta v2ray sing-box")
		resp, err := client.Do(req)
		if err != nil {
			fmt.Println("Error making GET request:", err)
			return nil, err
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, fmt.Errorf("failed to read config body: %w", err)
		}
		configStr = string(body)
	}
	return config.ParseBuildConfig(ctx, inhiveSettings, &config.ReadOptions{Content: configStr})
}
