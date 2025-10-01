#!/bin/bash

RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
BLUE_COLOR='\e[1;34m'
PINK_COLOR='\e[1;35m'
SHAN='\e[1;33;5m'
RES='\e[0m'

HELP() {
  echo -e "\r\n${GREEN_COLOR}EasyTier Installation Script Help${RES}\r\n"
  echo "Usage: ./install.sh [command] [options]"
  echo
  echo "Commands:"
  echo "  install    Install EasyTier"
  echo "  uninstall  Uninstall EasyTier"
  echo "  update     Update EasyTier (latest)"
  echo "  help       Show this help message"
  echo
  echo "Options:"
  echo "  --skip-folder-verify  Skip folder verification during installation"
  echo "  --skip-folder-fix     Skip automatic folder path fixing"
  echo "  --no-gh-proxy        Disable GitHub proxy"
  echo "  --gh-proxy URL       Set custom GitHub proxy URL"
}

if [ $# -eq 0 ] || [ "$1" = "help" ]; then
  HELP
  exit 0
fi

SKIP_FOLDER_VERIFY=false
SKIP_FOLDER_FIX=false
NO_GH_PROXY=false
GH_PROXY='https://gh.635635.xyz/'

COMMEND=$1
shift

# Check path
if [[ "$#" -ge 1 && ! "$1" == --* ]]; then
    INSTALL_PATH=$1
    shift
fi

# Check other option
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-folder-verify) SKIP_FOLDER_VERIFY=true ;;
        --skip-folder-fix) SKIP_FOLDER_FIX=true ;;
        --no-gh-proxy) NO_GH_PROXY=true ;;
        --gh-proxy) 
            if [ -n "$2" ]; then
                GH_PROXY=$2
                shift
            else
                echo "Error: --gh-proxy requires a URL"
                exit 1
            fi
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$INSTALL_PATH" ]; then
    INSTALL_PATH='/opt/easytier'
fi

if [[ "$INSTALL_PATH" == */ ]]; then
    INSTALL_PATH=${INSTALL_PATH%?}
fi

if ! $SKIP_FOLDER_FIX && ! [[ "$INSTALL_PATH" == */easytier ]]; then
    INSTALL_PATH="$INSTALL_PATH/easytier"
fi

echo INSTALL PATH : $INSTALL_PATH
echo SKIP FOLDER FIX : $SKIP_FOLDER_FIX
echo SKIP FOLDER VERIFY : $SKIP_FOLDER_VERIFY

# check unzip
if ! command -v unzip >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}Error: unzip is not installed${RES}\r\n"
  exit 1
fi

# check curl
if ! command -v curl >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}Error: curl is not installed${RES}\r\n"
  exit 1
fi

echo -e "\r\n${RED_COLOR}----------------------NOTICE----------------------${RES}\r\n"
echo " This is a temporary script to install EasyTier "
echo " EasyTier requires a dedicated empty folder to install"
echo -e "\r\n${RED_COLOR}-------------------------------------------------${RES}\r\n"

# platform
if command -v arch >/dev/null 2>&1; then
  platform=$(arch)
else
  platform=$(uname -m)
fi

case "$platform" in
  amd64 | x86_64) ARCH="x86_64" ;;
  arm64 | aarch64 | *armv8*) ARCH="aarch64" ;;
  *armv7*) ARCH="armv7" ;;
  *arm*) ARCH="arm" ;;
  mips) ARCH="mips" ;;
  mipsel) ARCH="mipsel" ;;
  *) ARCH="UNKNOWN" ;;
esac

if [[ "$ARCH" == "armv7" || "$ARCH" == "arm" ]]; then
  if cat /proc/cpuinfo | grep Features | grep -i 'half' >/dev/null 2>&1; then
    ARCH=${ARCH}hf
  fi
fi

echo -e "\r\n${GREEN_COLOR}Your platform: ${ARCH} (${platform}) ${RES}\r\n"

if [ "$(id -u)" != "0" ]; then
  echo -e "\r\n${RED_COLOR}This script requires root!${RES}\r\n"
  exit 1
elif [ "$ARCH" == "UNKNOWN" ]; then
  echo -e "\r\n${RED_COLOR}Unsupported platform${RES}\r\n"
  exit 1
fi

# detect init
if command -v systemctl >/dev/null 2>&1; then
  INIT_SYSTEM="systemd"
elif command -v rc-update >/dev/null 2>&1; then
  INIT_SYSTEM="openrc"
else
  echo -e "\r\n${RED_COLOR}Error: Unsupported init system${RES}\r\n"
  exit 1
fi

CHECK() {
  if ! $SKIP_FOLDER_VERIFY; then
    if [ -f "$INSTALL_PATH/easytier-core" ]; then
      echo "There is EasyTier in $INSTALL_PATH. Use \"update\" instead."
      exit 0
    fi
  fi

  if [ ! -d "$INSTALL_PATH/" ]; then
    mkdir -p $INSTALL_PATH
  else
    if ! $SKIP_FOLDER_VERIFY; then
      if [ -n "$(ls -A $INSTALL_PATH)" ]; then
        echo "EasyTier requires empty directory."
        exit 1
      fi
    fi
  fi
}

INSTALL() {
  echo -e "\r\n${GREEN_COLOR}Downloading EasyTier (latest)...${RES}"
  rm -rf /tmp/easytier_tmp_install.zip
  BASE_URL="https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-${ARCH}.zip"
  DOWNLOAD_URL=$($NO_GH_PROXY && echo "$BASE_URL" || echo "${GH_PROXY}${BASE_URL}")
  echo -e "Download URL: ${GREEN_COLOR}${DOWNLOAD_URL}${RES}"
  curl -L ${DOWNLOAD_URL} -o /tmp/easytier_tmp_install.zip $CURL_BAR

  echo -e "\r\n${GREEN_COLOR}Unzip resource ...${RES}"
  unzip -o /tmp/easytier_tmp_install.zip -d $INSTALL_PATH/
  mkdir -p $INSTALL_PATH/config
  mv $INSTALL_PATH/easytier-linux-${ARCH}/* $INSTALL_PATH/ 2>/dev/null
  rm -rf $INSTALL_PATH/easytier-linux-${ARCH}/
  chmod +x $INSTALL_PATH/easytier-core $INSTALL_PATH/easytier-cli
  if [ -f $INSTALL_PATH/easytier-core ]; then
    echo -e "${GREEN_COLOR} Download successfully! ${RES}"
  else
    echo -e "${RED_COLOR} Download failed! ${RES}"
    exit 1
  fi
}

INIT() {
  if [ ! -f "$INSTALL_PATH/easytier-core" ]; then
    echo -e "\r\n${RED_COLOR}Unable to find EasyTier${RES}\r\n"
    exit 1
  fi

  # config
  cat >$INSTALL_PATH/config/default.conf <<EOF
instance_name = "default"
dhcp = true
listeners = [
    "tcp://0.0.0.0:11010",
    "udp://0.0.0.0:11010"
]
exit_nodes = []
rpc_portal = "0.0.0.0:0"
[network_identity]
network_name = "default"
network_secret = "default"
EOF

  if [ "$INIT_SYSTEM" = "systemd" ]; then
    cat >/etc/systemd/system/easytier@.service <<EOF
[Unit]
Description=EasyTier Service
After=network.target
[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/easytier-core -c $INSTALL_PATH/config/%i.conf
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable easytier@default
    systemctl start easytier@default
  else
    cat >/etc/init.d/easytier <<EOF
#!/sbin/openrc-run
command="$INSTALL_PATH/easytier-core"
command_args="-c $INSTALL_PATH/config/default.conf"
command_background=true
EOF
    chmod +x /etc/init.d/easytier
    rc-update add easytier default
    rc-service easytier start
  fi

  ln -sf $INSTALL_PATH/easytier-core /usr/sbin/easytier-core
  ln -sf $INSTALL_PATH/easytier-cli /usr/sbin/easytier-cli
}

UNINSTALL() {
  echo -e "\r\n${GREEN_COLOR}Uninstall EasyTier ...${RES}\r\n"
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    systemctl stop "easytier@*"
    systemctl disable "easytier@*"
    rm -rf $INSTALL_PATH /etc/systemd/system/easytier@.service /usr/sbin/easytier-*
    systemctl daemon-reload
  else
    rc-service easytier stop
    rc-update del easytier
    rm -rf $INSTALL_PATH /etc/init.d/easytier /usr/sbin/easytier-*
  fi
  echo -e "\r\n${GREEN_COLOR}EasyTier removed.${RES}\r\n"
}

UPDATE() {
  if [ ! -f "$INSTALL_PATH/easytier-core" ]; then
    echo -e "\r\n${RED_COLOR}EasyTier not found${RES}\r\n"
    exit 1
  fi
  echo -e "${GREEN_COLOR}Updating EasyTier...${RES}"
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    systemctl stop "easytier@*"
  else
    rc-service easytier stop
  fi
  INSTALL
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    systemctl start "easytier@*"
  else
    rc-service easytier start
  fi
  echo -e "\r\n${GREEN_COLOR}EasyTier updated successfully!${RES}\r\n"
}

if curl --help | grep progress-bar >/dev/null 2>&1; then
  CURL_BAR="--progress-bar"
fi

case "$COMMEND" in
  install) CHECK; INSTALL; INIT ;;
  uninstall) UNINSTALL ;;
  update) UPDATE ;;
  *) HELP ;;
esac

rm -rf /tmp/easytier_tmp_*
