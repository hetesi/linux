#!/bin/bash
set -e

INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
IPADDR="192.168.1.100"
NETMASK="255.255.255.0"
GATEWAY="192.168.1.1"
DNS="192.168.1.1"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m" 

DockVer="v2.27.0"

# Ellenőrizzük, hogy root vagy-e
echo -e "${YELLOW}=== Debian konfiguráló szkript ===${NC}"

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED} Ezt a szkriptet root jogosultsággal kell futtatni!${NC}"
  echo -e "${YELLOW}Lépj be root-ként: su - vagy sudo parancsal futtasd!${NC}"
  exit 1
fi
echo -e "${GREEN} Root jogosultság ellenőrizve.${NC}"

echo "Biztonsági mentés készül az interfaces fájlról..."
cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s)

echo "Hálózat konfigurálása ($INTERFACE)..."

cat <<EOF > /etc/network/interfaces
# loopback interface
auto lo
iface lo inet loopback

# statikus IP beállítása
allow-hotplug $INTERFACE
iface $INTERFACE inet static
    address $IPADDR
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS
EOF

echo "nameserver $DNS" > /etc/resolv.conf

echo "Hálózati szolgáltatás újraindítása..."
systemctl restart networking

echo -e "${YELLOW}KÉSZ – az új IP-cím: $IPADDR${NC}"
systemctl restart networking

# 1. Rendszer frissítése
echo "Rendszer frissítése..."
apt update && apt upgrade -y

echo -e "${YELLOW} Docker telepítése...${NC}"

apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Docker GPG kulcs
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Docker repo hozzáadása
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Telepítés
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo -e "${YELLOW}=== docker-compose fájl letöltése. ===${NC}"
curl -L "https://github.com/docker/compose/releases/download/${DockVer}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo -e "${YELLOW}$(docker-compose --version)${NC}"

echo -e "${GREEN}Docker sikeresen telepítve.${NC}"

