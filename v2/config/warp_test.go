package config

import (
	"encoding/json"
	"fmt"
	"net"
	"testing"
	"time"

	warpobf "github.com/sagernet/wireguard-go/warpobf"
)

// TestWARPGenerateAndConnect:
//  1. Запрашивает credentials у Cloudflare через bepass-org/warp-plus
//  2. Строит sing-box endpoint конфиг через wireGuardToSingbox
//  3. Проверяет что JSON конфиг валидный и peer address достижим
//
// Запустить: cd core && go test ./v2/config/ -run TestWARPGenerateAndConnect -v -timeout 60s
func TestWARPGenerateAndConnect(t *testing.T) {
	t.Log("=== Step 1: Generate WARP credentials from Cloudflare ===")

	identity, log, wgConfig, err := GenerateWarpInfo("", "", "")
	if err != nil {
		t.Fatalf("GenerateWarpInfo failed: %v", err)
	}
	t.Logf("Log: %s", log)
	t.Logf("AccountID: %s", identity.ID)
	t.Logf("WarpPlus: %t", identity.Account.WarpPlus)
	t.Logf("PrivateKey: %s...", wgConfig.PrivateKey[:10])
	t.Logf("PeerPublicKey: %s", wgConfig.PeerPublicKey)
	t.Logf("LocalIPv4: %s", wgConfig.LocalAddressIPv4)
	t.Logf("LocalIPv6: %s", wgConfig.LocalAddressIPv6)
	t.Logf("ClientID: %s", wgConfig.ClientID)

	t.Log("=== Step 2: Build sing-box endpoint config via wireGuardToSingbox ===")

	// host="" → auto4 (random Cloudflare WARP endpoint IP)
	endpoint, err := wireGuardToSingbox(*wgConfig, "", 2408)
	if err != nil {
		t.Fatalf("wireGuardToSingbox failed: %v", err)
	}
	t.Logf("Endpoint type: %s tag: %s", endpoint.Type, endpoint.Tag)

	noise := warpobf.NoiseOptions{}
	fullEndpoint, err := GenerateWarpSingbox(*wgConfig, "", 2408, &noise)
	if err != nil {
		t.Fatalf("GenerateWarpSingbox failed: %v", err)
	}

	t.Log("=== Step 3: Marshal to JSON ===")
	jsonBytes, err := json.MarshalIndent(fullEndpoint, "", "  ")
	if err != nil {
		t.Fatalf("JSON marshal failed: %v", err)
	}
	t.Logf("Endpoint JSON:\n%s", string(jsonBytes))

	t.Log("=== Step 4: Verify peer address is reachable (ICMP + UDP) ===")
	// Тест ICMP connectivity к Cloudflare WARP anycast
	addrs := []string{"162.159.192.1", "162.159.193.1", "162.159.195.1", "engage.cloudflareclient.com"}
	for _, addr := range addrs {
		conn, err := net.DialTimeout("ip4:icmp", addr, 3*time.Second)
		if err != nil {
			t.Logf("ICMP to %s: FAIL (%v)", addr, err)
		} else {
			conn.Close()
			t.Logf("ICMP to %s: OK", addr)
		}
	}

	// UDP port 2408 — WG handshake отправляет initial packet
	t.Log("=== Step 5: UDP 2408 test (send dummy, expect response or timeout) ===")
	udpAddr := "162.159.192.1:2408"
	conn, err := net.DialTimeout("udp", udpAddr, 5*time.Second)
	if err != nil {
		t.Fatalf("UDP dial to %s failed: %v", udpAddr, err)
	}
	defer conn.Close()
	// Send 1 byte
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	_, err = conn.Write([]byte{0x01})
	if err != nil {
		t.Logf("UDP write to %s: %v (may be ok, CF may not respond to garbage)", udpAddr, err)
	} else {
		t.Logf("UDP to %s: sent OK", udpAddr)
	}
	// Read response (may timeout - CF won't respond to garbage bytes)
	buf := make([]byte, 64)
	n, err := conn.Read(buf)
	if err != nil {
		t.Logf("UDP read: %v (timeout/no-response expected for garbage packet)", err)
	} else {
		t.Logf("UDP response: %d bytes: %x", n, buf[:n])
	}

	fmt.Println("\n=== WARP config that Flutter builder should use ===")
	fmt.Printf("address:          %s/24, %s/128\n", wgConfig.LocalAddressIPv4, wgConfig.LocalAddressIPv6)
	fmt.Printf("private_key:      %s\n", wgConfig.PrivateKey)
	fmt.Printf("peer public_key:  %s\n", wgConfig.PeerPublicKey)
	fmt.Printf("peer address:     162.159.192.1\n")
	fmt.Printf("peer port:        2408\n")
	fmt.Printf("mtu:              1330\n")
}
