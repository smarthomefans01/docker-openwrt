#!/bin/bash

echo "开始查找第一个非lo（非本地）网络接口的名称..."

# 获取第一个非lo网络接口的名称
INTERFACE=$(ip link | grep -Eo '^[0-9]+: [^:]+:' | awk '{print $2}' | tr -d ':' | grep -v "lo" | head -n 1)

# 检查是否找到了接口名称
if [ -z "$INTERFACE" ]; then
    echo "未找到合适的网络接口!"
    exit 1
fi

echo "找到的网络接口是: $INTERFACE"

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
echo "开始使用docker命令创建网络..."
docker network create -d macvlan --subnet=$SUBNET --gateway=$GATEWAY -o parent=$INTERFACE macnet

if [ $? -eq 0 ]; then
    echo "成功创建macnet网络!"
else
    echo "创建macnet网络失败!"
    exit 1
fi
