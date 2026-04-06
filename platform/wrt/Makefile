include $(TOPDIR)/rules.mk

PKG_NAME:=inhive-core
PKG_VERSION:=4.1.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/inhive/inhive-core/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=8a877268eaea3dc52f300ddfd2f702ed1c4e37f75ddea5fcecc27cfefc849f85

PKG_LICENSE:=https://github.com/inhive/inhive-app/edit/main/LICENSE.md
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=InHive <wrt@inhive.ru>

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

GO_PKG:=github.com/inhive/inhive-core
GO_PKG_BUILD_PKG:=$(GO_PKG)/cli

GO_PKG_LDFLAGS_X:=$(GO_PKG)/constant.Version=$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include ../../lang/golang/golang-package.mk

define Package/inhive-core
  TITLE:=InHive universal proxy platform
  SECTION:=net
  CATEGORY:=Network
  URL:=https://inhive.ru/
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle +kmod-inet-diag +kmod-tun
  USERID:=inhive=15566:inhive=15566
endef

define Package/inhive-core/description
  InHive is a universal proxy platform which supports hysteria, SOCKS, Shadowsocks,
  ShadowTLS, Tor, trojan, VLess, VMess, WireGuard and so on.
endef

GO_PKG_TAGS:=with_gvisor,with_quic,with_wireguard,with_ech,with_utls,with_clash_api,with_grpc,with_low_memory,with_conntrack

define Package/inhive-core/conffiles
/etc/config/inhive
/etc/inhive/
endef

define Package/inhive-core/install

	$(INSTALL_DIR) $(1)/usr/bin/
	$(INSTALL_BIN) $(GO_PKG_BUILD_BIN_DIR)/cli $(1)/usr/bin/inhive-cli

	$(INSTALL_DIR) $(1)/etc/inhive
	$(INSTALL_DATA) ./files/inhive.json $(1)/etc/inhive/appconfig.json

	$(INSTALL_DIR) $(1)/etc/config/
	$(INSTALL_CONF) ./files/inhive.conf $(1)/etc/config/inhive

	$(INSTALL_DIR) $(1)/etc/init.d/
	$(INSTALL_BIN) ./files/inhive.init $(1)/etc/init.d/inhive

	$(CP) ./files/webui $(1)/usr/bin/
endef

$(eval $(call BuildPackage,inhive-core))
