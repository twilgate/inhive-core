// builder_outbound.go — assembles outbound proxies, WARP patching, selectors.
package config

import (
	"fmt"
	"strings"

	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/wireguard-go/hiddify"
)

func setOutbounds(options *option.Options, input *option.Options, opt *InhiveOptions, staticIPs *map[string][]string) error {
	var outbounds []option.Outbound
	var endpoints []option.Endpoint
	var tags []string
	// OutboundMainProxyTag = OutboundSelectTag
	// inbound==warp over proxies
	// outbound==proxies over warp
	OutboundMainDetour = OutboundSelectTag
	OutboundWARPConfigDetour = OutboundDirectFragmentTag
	hasPsiphon := false
	for _, out := range input.Outbounds {

		if contains(PredefinedOutboundTags, out.Tag) {
			continue
		}
		outbound, err := patchOutbound(out, *opt, staticIPs)
		if err != nil {
			return err
		}
		out = *outbound

		switch out.Type {
		case C.TypeBlock, C.TypeDNS:
			continue
		case C.TypeSelector, C.TypeURLTest:
			continue
		case C.TypeCustom:
			continue
		default:

			if contains([]string{"direct", "bypass", "block"}, out.Tag) {
				continue
			}
			if out.Type == C.TypePsiphon {
				if hasPsiphon {
					continue
				}
				hasPsiphon = true
			}
			if !strings.Contains(out.Tag, "§hide§") {
				tags = append(tags, out.Tag)
			}
			// OutboundWARPConfigDetour = OutboundSelectTag
			out = *patchHiddifyWarpFromConfig(&out, *opt)
			outbounds = append(outbounds, out)
		}
	}

	if opt.Warp.EnableWarp {
		// wg := getOrGenerateWarpLocallyIfNeeded(&opt.Warp)

		// out, err := GenerateWarpSingbox(wg, opt.Warp.CleanIP, opt.Warp.CleanPort, &option.WireGuardHiddify{
		// 	FakePackets:      opt.Warp.FakePackets,
		// 	FakePacketsSize:  opt.Warp.FakePacketSize,
		// 	FakePacketsDelay: opt.Warp.FakePacketDelay,
		// 	FakePacketsMode:  opt.Warp.FakePacketMode,
		// })
		out, err := GenerateWarpSingboxNew("p1", &hiddify.NoiseOptions{})
		if err != nil {
			return fmt.Errorf("failed to generate warp config: %v", err)
		}
		out.Tag = WARPConfigTag
		if opts, ok := out.Options.(*option.WireGuardWARPEndpointOptions); ok {
			if opt.Warp.Mode == "warp_over_proxy" {
				opts.Detour = OutboundSelectTag
				opts.MTU = 1280
			} else {
				opts.Detour = OutboundDirectTag
				opt.MTU = max(opt.MTU, 1340)
			}

		}

		OutboundMainDetour = WARPConfigTag
		// patchWarp(out, opt, true, nil)
		out, err = patchEndpoint(out, *opt, staticIPs)
		if err != nil {
			return err
		}
		endpoints = append(endpoints, *out)
	}
	for _, end := range input.Endpoints {
		if contains(PredefinedOutboundTags, end.Tag) {
			continue
		}
		if opt.Warp.EnableWarp {
			if end.Type == C.TypeWARP {
				if opts, ok := end.Options.(*option.WireGuardWARPEndpointOptions); ok {
					if opts.UniqueIdentifier == "p1" {
						continue
					}
					if opt.Warp.EnableWarp && opt.Warp.Mode == "warp_over_proxy" {
						opt.MTU = max(opt.MTU, 1340)
					}
				}
			}
			if end.Type == C.TypeWireGuard {
				if opts, ok := end.Options.(*option.WireGuardEndpointOptions); ok {
					if opts.PrivateKey == opt.Warp.WireguardConfig.PrivateKey {
						continue
					}
					if opt.Warp.EnableWarp && opt.Warp.Mode == "warp_over_proxy" {
						opt.MTU = max(opt.MTU, 1340)
					}
				}
			}
		}

		out, err := patchEndpoint(&end, *opt, staticIPs)
		if err != nil {
			return err
		}

		if !strings.Contains(out.Tag, "§hide§") {
			tags = append(tags, out.Tag)
		}

		endpoints = append(endpoints, *out)
	}
	if len(opt.ConnectionTestUrls) == 0 {
		opt.ConnectionTestUrls = []string{opt.ConnectionTestUrl, "https://www.google.com/generate_204", "http://captive.apple.com/generate_204", "https://cp.cloudflare.com"}
		if isBlockedConnectionTestUrl(opt.ConnectionTestUrl) {
			opt.ConnectionTestUrls = []string{opt.ConnectionTestUrl}
		}
	}
	// urlTest := option.Outbound{
	// 	Type: C.TypeURLTest,
	// 	Tag:  OutboundURLTestTag,
	// 	Options: &option.URLTestOutboundOptions{
	// 		Outbounds: tags,
	// 		URL:       opt.ConnectionTestUrl,
	// 		URLs:      opt.ConnectionTestUrls,
	// 		Interval:  badoption.Duration(opt.URLTestInterval.Duration()),
	// 		// IdleTimeout: badoption.Duration(opt.URLTestIdleTimeout.Duration()),
	// 		Tolerance:                 1,
	// 		IdleTimeout:               badoption.Duration(opt.URLTestInterval.Duration().Nanoseconds() * 3),
	// 		InterruptExistConnections: true,
	// 	},
	// }
	urlTest := option.Outbound{
		Type: C.TypeBalancer,
		Tag:  OutboundURLTestTag,
		Options: &option.BalancerOutboundOptions{
			Outbounds:            tags,
			Strategy:             "lowest-delay",
			DelayAcceptableRatio: 2,
			// URL:       opt.ConnectionTestUrl,
			// URLs:      opt.ConnectionTestUrls,
			// Interval:  badoption.Duration(opt.URLTestInterval.Duration()),
			// IdleTimeout: badoption.Duration(opt.URLTestIdleTimeout.Duration()),
			Tolerance: 1,
			// IdleTimeout:               badoption.Duration(opt.URLTestInterval.Duration().Nanoseconds() * 3),
			InterruptExistConnections: true,
		},
	}

	balancer := option.Outbound{
		Type: C.TypeBalancer,
		Tag:  OutboundRoundRobinTag,
		Options: &option.BalancerOutboundOptions{
			Outbounds:            tags,
			Strategy:             opt.BalancerStrategy,
			DelayAcceptableRatio: 2,
			// URL:       opt.ConnectionTestUrl,
			// URLs:      opt.ConnectionTestUrls,
			// Interval:  badoption.Duration(opt.URLTestInterval.Duration()),
			// IdleTimeout: badoption.Duration(opt.URLTestIdleTimeout.Duration()),
			Tolerance: 1,
			// IdleTimeout:               badoption.Duration(opt.URLTestInterval.Duration().Nanoseconds() * 3),
			InterruptExistConnections: true,
		},
	}
	defaultSelect := tags[0]

	for _, tag := range tags {
		if strings.Contains(tag, "§default§") {
			defaultSelect = "§default§"
		}
	}

	selectorTags := tags
	if len(tags) > 1 {
		if OutboundMainDetour == WARPConfigTag {
			outbounds = append([]option.Outbound{urlTest}, outbounds...)
			selectorTags = append([]string{urlTest.Tag}, selectorTags...)
			defaultSelect = urlTest.Tag
		} else {
			outbounds = append([]option.Outbound{balancer, urlTest}, outbounds...)
			selectorTags = append([]string{urlTest.Tag, balancer.Tag}, selectorTags...)
			defaultSelect = balancer.Tag

		}
	}
	selector := option.Outbound{
		Type: C.TypeSelector,
		Tag:  OutboundSelectTag,
		Options: &option.SelectorOutboundOptions{
			Outbounds:                 selectorTags,
			Default:                   defaultSelect,
			InterruptExistConnections: true,
		},
	}
	outbounds = append([]option.Outbound{selector}, outbounds...)

	options.Endpoints = endpoints
	options.Outbounds = append(
		outbounds,
		[]option.Outbound{
			{
				Tag:     OutboundDirectTag,
				Type:    C.TypeDirect,
				Options: &option.DirectOutboundOptions{},
			},
			{
				Tag:  OutboundDirectFragmentTag,
				Type: C.TypeDirect,
				Options: &option.DirectOutboundOptions{
					DialerOptions: option.DialerOptions{
						TCPFastOpen: false,

						TLSFragment: option.TLSFragmentOptions{
							Enabled: true,
							Size:    opt.TLSTricks.FragmentSize,
							Sleep:   opt.TLSTricks.FragmentSleep,
						},
					},
				},
			},
		}...,
	)

	return nil
}

func patchHiddifyWarpFromConfig(out *option.Outbound, opt InhiveOptions) *option.Outbound {
	if out.Type == C.TypePsiphon {
		return out
	}
	if opt.Warp.EnableWarp && opt.Warp.Mode == "proxy_over_warp" {
		if opts, ok := out.Options.(option.DialerOptionsWrapper); ok {
			dialer := opts.TakeDialerOptions()
			dialer.Detour = WARPConfigTag
			opts.ReplaceDialerOptions(dialer)
		}
	}
	return out
}
