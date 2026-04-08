// builder.go — orchestrator: constants, tags, and BuildConfig entry point.
package config

import (
	context "context"

	"github.com/sagernet/sing-box/option"
)

const (
	DNSRemoteTag         = "dns-remote"
	DNSRemoteTagFallback = "dns-remote-fallback"
	DNSLocalTag          = "dns-local"
	DNSStaticTag         = "dns-static"
	DNSDirectTag         = "dns-direct"
	DNSRemoteNoWarpTag   = "dns-remote-no-warp"
	DNSFakeTag           = "dns-fake"
	DNSTricksDirectTag   = "dns-trick-direct"
	DNSMultiDirectTag    = "dns-direct"
	DNSMultiRemoteTag    = "dns-remote"

	OutboundDirectTag         = "direct §hide§"
	OutboundBypassTag         = "bypass §hide§"
	OutboundSelectTag         = "select"
	OutboundURLTestTag        = "lowest"
	OutboundRoundRobinTag     = "balance"
	OutboundDNSTag            = "dns-out §hide§"
	OutboundDirectFragmentTag = "direct-fragment §hide§"

	WARPConfigTag = "🔒 WARP"

	InboundTUNTag    = "tun-in"
	InboundMixedTag  = "mixed-in"
	InboundTProxy    = "tproxy-in"
	InboundRedirect  = "redirect-in"
	InboundDirectTag = "dns-in"
)

var (
	OutboundMainDetour       = OutboundSelectTag
	OutboundWARPConfigDetour = OutboundDirectFragmentTag
	PredefinedOutboundTags   = []string{OutboundDirectTag, OutboundBypassTag, OutboundSelectTag, OutboundURLTestTag, OutboundDNSTag, OutboundDirectFragmentTag, WARPConfigTag}
)

func BuildConfig(ctx context.Context, hopts *InhiveOptions, inputOpt *ReadOptions) (*option.Options, error) {
	input, err := ReadSingOptions(ctx, inputOpt)
	if err != nil {
		return nil, err
	}

	var options option.Options
	if hopts.EnableFullConfig {
		options.Inbounds = input.Inbounds
		options.DNS = input.DNS
		options.Route = input.Route
	}

	setExperimental(&options, hopts)
	setLog(&options, hopts)
	setInbound(&options, hopts)

	staticIPs := make(map[string][]string)
	if err := setOutbounds(&options, input, hopts, &staticIPs); err != nil {
		return nil, err
	}
	if err := setDns(&options, hopts, &staticIPs); err != nil {
		return nil, err
	}
	if err := setRoutingOptions(&options, hopts); err != nil {
		return nil, err
	}

	return &options, nil
}
