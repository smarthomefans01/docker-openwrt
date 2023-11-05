#!/bin/bash

echo "检查nmap是否安装..."
if ! command -v nmap &>/dev/null; then
    echo "nmap未安装。正在尝试自动安装nmap..."
    sudo apt update && sudo apt install -y nmap
    if [ $? -ne 0 ]; then
        echo "安装nmap失败，请手动安装后重新运行脚本。"
        exit 1
    fi
fi

echo "开始查找第一个非lo（非本地）网络接口的名称..."

# 获取第一个非lo网络接口的名称
INTERFACE=$(ip link | grep -Eo '^[0-9]+: [^:]+:' | awk '{print $2}' | tr -d ':' | grep -v "lo" | head -n 1)

# 检查是否找到了接口名称
if [ -z "$INTERFACE" ]; then
    echo "未找到合适的网络接口!"
    exit 1
fi

echo "找到的网络接口是: $INTERFACE"

echo "设置 $INTERFACE 为混杂模式..."
sudo ip link set $INTERFACE promisc on
if [ $? -ne 0 ]; then
    echo "设置 $INTERFACE 为混杂模式失败!"
    exit 1
fi
echo "$INTERFACE 已设置为混杂模式"

# 获取该接口的IP地址
IP_ADDRESS=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+')

# 检查是否成功获取到IP地址
if [ -z "$IP_ADDRESS" ]; then
    echo "无法获取 $INTERFACE 的IP地址!"
    exit 1
fi

echo "$INTERFACE 的IP地址是: $IP_ADDRESS"

# 从IP地址计算子网和网关
SUBNET="$(echo $IP_ADDRESS | cut -d'.' -f1-3).0/24"
GATEWAY="$(echo $IP_ADDRESS | cut -d'.' -f1-3).1"

echo "计算得到的子网为: $SUBNET"
echo "计算得到的网关为: $GATEWAY"

# 使用docker命令创建网络
if docker network inspect macnet &> /dev/null; then
    # 如果存在，则删除macnet网络
    docker network rm macnet
fi
# 创建macnet网络
docker network create -d macvlan --subnet=$SUBNET --gateway=$GATEWAY -o parent=$INTERFACE macnet


if [ $? -eq 0 ]; then
    echo "成功创建macnet网络!"
else
    echo "创建macnet网络失败!"
    exit 1
fi

docker pull shashiikora/openwrt-redstone
if [ $? -ne 0 ]; then
    echo "拉取 shashiikora/openwrt-redstone 镜像失败!"
    exit 1
fi

docker run --restart always --name openwrt -d --network macnet --privileged shashiikora/openwrt-redstone /sbin/init
if [ $? -ne 0 ]; then
    echo "启动 openwrt 容器失败!"
    exit 1
fi


if ! command -v nmap &> /dev/null; then
    echo "请先安装nmap：sudo apt install nmap"
    exit 1
fi

echo "获取宿主机的IP地址..."

# 获取宿主机的IP地址
HOST_IP=$(hostname -I | awk '{print $1}')
echo "宿主机的IP地址是: $HOST_IP"

# 获取网络部分和路由器IP
NETWORK_PART=$(echo $HOST_IP | cut -d'.' -f1-3)
ROUTER_IP="$NETWORK_PART.1"
echo "网络部分是: $NETWORK_PART"
echo "路由器IP是: $ROUTER_IP"

# 使用nmap扫描局域网内的活跃主机
echo "正在扫描局域网内的活跃主机..."
ACTIVE_IPS=$(nmap -sn $NETWORK_PART.0/24 -oG - | grep "Up$" | awk '{print $2}')

# 从2到254中随机选择一个IP并检查它是否在活跃IP列表中
while true; do
    RANDOM_END=$((RANDOM % 253 + 2))
    CANDIDATE_IP="$NETWORK_PART.$RANDOM_END"
    if ! echo "$ACTIVE_IPS" | grep -q "$CANDIDATE_IP"; then
        # 选中的IP不在活跃列表中
        OPENWRT_IP=$CANDIDATE_IP
        break
    fi
done

echo "选定的OpenWrt IP地址是: $OPENWRT_IP"

# 使用选中的IP设置OpenWrt的配置
OPENWRT_CONFIG="
config interface 'lan'
        option type 'bridge'
        option ifname 'eth0'
        option proto 'static'
        option ipaddr '$OPENWRT_IP'
        option netmask '255.255.255.0'
        option ip6assign '60'
        option gateway '$ROUTER_IP'
        option broadcast '$NETWORK_PART.255'
        option dns '$ROUTER_IP'
"

# 写入配置到OpenWrt容器
echo "$OPENWRT_CONFIG" | docker exec -i openwrt bash -c "cat > /etc/config/network"

# 提示用户操作完成
echo "OpenWrt容器的网络配置已更新。"
echo "您可以通过以下地址访问OpenWrt: http://$OPENWRT_IP/"

