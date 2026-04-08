// independent_instance.go — standalone proxy instances for testing and extensions.
package hcore

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"

	"github.com/buudesh/inhive-core/v2/config"
	"golang.org/x/net/proxy"

	"github.com/sagernet/sing-box/option"
)

func getRandomAvailblePort() uint16 {
	// TODO: implement it
	listener, err := net.Listen("tcp", ":0")
	if err != nil {
		panic(err)
	}
	defer listener.Close()
	return uint16(listener.Addr().(*net.TCPAddr).Port)
}

func RunInstanceString(ctx context.Context, inhiveSettings *config.InhiveOptions, proxiesInput string) (*InhiveInstance, error) {
	if inhiveSettings == nil {
		inhiveSettings = config.DefaultInhiveOptions()
	}

	singconfigs, err := config.ParseConfig(ctx, &config.ReadOptions{Content: proxiesInput}, true, inhiveSettings, false)
	if err != nil {
		return nil, err
	}
	return RunInstance(ctx, inhiveSettings, singconfigs)
}

func RunInstance(ctx context.Context, inhiveSettings *config.InhiveOptions, singconfig *option.Options) (*InhiveInstance, error) {
	if inhiveSettings == nil {
		inhiveSettings = config.DefaultInhiveOptions()
	}
	inhiveSettings.EnableClashApi = false
	inhiveSettings.InboundOptions.MixedPort = getRandomAvailblePort()
	inhiveSettings.InboundOptions.EnableTun = false
	inhiveSettings.InboundOptions.EnableTunService = false
	inhiveSettings.InboundOptions.SetSystemProxy = false
	inhiveSettings.InboundOptions.TProxyPort = 0
	inhiveSettings.InboundOptions.DirectPort = 0
	inhiveSettings.InboundOptions.RedirectPort = 0
	inhiveSettings.Region = "other"
	inhiveSettings.BlockAds = false
	inhiveSettings.LogFile = "/dev/null"

	finalConfigs, err := config.BuildConfig(ctx, inhiveSettings, &config.ReadOptions{Options: singconfig})
	if err != nil {
		return nil, err
	}

	instance, err := NewService(ctx, *finalConfigs)
	if err != nil {
		return nil, err
	}

	<-time.After(250 * time.Millisecond)
	hservice := &InhiveInstance{
		StartedService: instance,
		ListenPort:     inhiveSettings.InboundOptions.MixedPort}
	hservice.PingCloudflare()
	return hservice, nil
}

// dialer, err := s.libbox.GetInstance().Router().Dialer(context.Background())

func (s *InhiveInstance) Close() error {
	return s.StartedService.CloseService()
}

func (s *InhiveInstance) GetContent(url string) (string, error) {
	return s.ContentFromURL("GET", url, 10*time.Second)
}

func (s *InhiveInstance) ContentFromURL(method string, url string, timeout time.Duration) (string, error) {
	if method == "" {
		return "", fmt.Errorf("empty method")
	}
	if url == "" {
		return "", fmt.Errorf("empty url")
	}

	req, err := http.NewRequest(method, url, nil)
	if err != nil {
		return "", err
	}

	dialer, err := proxy.SOCKS5("tcp", fmt.Sprintf("127.0.0.1:%d", s.ListenPort), nil, proxy.Direct)
	if err != nil {
		return "", err
	}

	transport := &http.Transport{
		Dial: dialer.Dial,
	}

	client := &http.Client{
		Transport: transport,
		Timeout:   timeout,
	}

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		return "", fmt.Errorf("request failed with status code: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	if body == nil {
		return "", fmt.Errorf("empty body")
	}

	return string(body), nil
}

func (s *InhiveInstance) PingCloudflare() (time.Duration, error) {
	return s.Ping("http://cp.cloudflare.com")
}

// func (s *HiddifyService) RawConnection(ctx context.Context, url string) (net.Conn, error) {
// 	return
// }

func (s *InhiveInstance) PingAverage(url string, count int) (time.Duration, error) {
	if count <= 0 {
		return -1, fmt.Errorf("count must be greater than 0")
	}

	var sum int
	real_count := 0
	for i := 0; i < count; i++ {
		delay, err := s.Ping(url)
		if err == nil {
			real_count++
			sum += int(delay.Milliseconds())
		} else if real_count == 0 && i > count/2 {
			return -1, fmt.Errorf("ping average failed")
		}

	}
	return time.Duration(sum / real_count * int(time.Millisecond)), nil
}

func (s *InhiveInstance) Ping(url string) (time.Duration, error) {
	startTime := time.Now()
	_, err := s.ContentFromURL("HEAD", url, 4*time.Second)
	if err != nil {
		return -1, err
	}
	duration := time.Since(startTime)
	return duration, nil
}
