## Introduction
Monitoring Dell PowerEdge server temperature and control fan speed using IPMI command.  
使用 IPMI 监控 DELL PowerEdge 服务器温度并自动控制风扇转速.

## Supported Server
- Dell PowerEdge 13G Server (R530 R730 tested)
- Dell EMC PowerEdge 14G Server and iDRAC < 3.34.34.34 (R740 with iDRAC 3.21.23.22 tested)

## Supported Running Environment
- GNU Linux
- macOS

## Usage
Enable IPMI on LAN in iDRAC when you using 14G server.  
14代服务器需要在 iDRAC 中手动启用 IPMI on LAN.


Install ipmitool.  
安装 ipmitool.


Edit script and set server IP address.  
在脚本中设置服务器 IP 地址.  

```bash
IPMIHOST=("172.31.0.1" "172.31.0.2")   # array of iDRAC IP Address
IPMIUSER=root     # iDRAC Username
IPMIPW=$IPMIPW    # iDRAC Password
INTERVAL=45       # Sleep seconds between Check
TEMP_AUTO=86
# Default fan profile
TEMP_1=59
TEMP_2=62
TEMP_3=65
TEMP_4=68
TEMP_5=71
TEMP_6=74
TEMP_7=77
TEMP_8=80
FAN_1=1
FAN_2=5
FAN_3=9
FAN_4=13
FAN_5=17
FAN_6=21
FAN_7=25
FAN_8=29
FAN_9=33
```

### Running in Terminal

Set iDRAC password to ENV.  
在环境变量中设置 iDRAC 密码.  

```bash
export IPMIPW=<iDRAC password>
```

```
Usage: poweredge_ipmi.sh COMMAND HOST [SPEED]

  COMMAND:
    temp      Get Current Temperature
    fan       Get or Set Current Fan Speed
  HOST:
    <number>  Host Number in List (Start from 0)
    all       All Host
  SPEED:
    <number>  Set Fan Speed (1-100)
    idrac     Set Fan Speed to iDRAC Controlled
    auto      Set Fan Speed by Using this Script
```
### Running as service

```bash
vim /lib/systemd/system/poweredge_fan.service
```
Add following content:  
添加以下内容：  

```ini
[Unit]
Description=PowerEdge Fan Control
After=network.target

[Service]
Type=simple
Environment="IPMIPW=<iDRAC password>"
ExecStart=/opt/poweredge_fancontrol/poweredge_ipmi.sh fan all auto
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start service.  
启用和运行服务.  

```bash
systemctl daemon-reload
systemctl enable poweredge_fan
systemctl start poweredge_fan
```