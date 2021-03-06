#!/bin/bash

PLATFORM="unknown"

# OS Checking
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  PLATFORM="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  PLATFORM="darwin"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
  PLATFORM="bsd"
elif [[ "$OSTYPE" == "openbsd"* ]]; then
  PLATFORM="bsd"
elif [[ "$OSTYPE" == "netbsd"* ]]; then
  PLATFORM="bsd"
elif [[ "$OSTYPE" == "solaris"* ]]; then
  PLATFORM="solaris"
fi

GREP="grep -E"

if [[ "$PLATFORM" == "linux" ]]; then
  GREP="grep -P"
fi

# IPMI Setting
IPMIHOST=("192.168.12.10" "192.168.12.11")   # array of iDRAC IP Address
IPMIUSER=root     # iDRAC Username
IPMIPW=$IPMIPW    # iDRAC Password
INTERVAL=30       # Sleep seconds between Check
HIGHTEMP=85       # Fan Will Controlled by iDRAC when CPU Temp Higher than HIGHTEMP
LOWTEMP=65        # Fan Will at LOWFAN when CPU Higher than STOPTEMP but Temp Lower than LOWTEMP
STOPTEMP=55       # Fan Will at 1 percent PMW when CPU Temp Lower than STOPTEMP
MIDFAN=10         # Fan Speed when CPU Temp Higher than LOWTEMP but Lower than HIGHTEMP
LOWFAN=5          # Fan Speed when CPU Temp Higher than STOPTEMP but Lower than LOWTEMP
STOPFAN=1         # Fan Speed when CPU Temp Lower than STOPTEMP

# 1  - 1%  - 1800  RPM
# 5  - 5%  - 2400  RPM
# a  - 10% - 3360  RPM
# 0f - 15% - 4080  RPM
# 14 - 20% - 4920  RPM
# 19 - 25% - 5640  RPM
# 1e - 30% - 6480  RPM
# 23 - 35% - 7200  RPM
# 28 - 40% - 8040  RPM
# 2d - 45%
# 32 - 50%
# 3c - 60%
# 46 - 70%
# 50 - 80%
# 64 - 100%

# $1=Host
function SetFanAuto()
{
  echo "Setting $1 fan speed to iDRAC controlled "
  ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x01 > /dev/null
}

# $1=Host $2=Level
function SetFanLevel() {
  local LEVEL=$(printf '0x%x' $2)
  echo "Setting $1 fan speed to $2%"
  ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x01 0x00 > /dev/null
  ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW raw 0x30 0x30 0x02 0xff $LEVEL > /dev/null
}

# $1=Host
function GetFanLevel() {
  echo "Getting $1 fan speed: "
  ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW sdr type fan | $GREP 'Fan\d' | cut -d \| -f1,5
}

# $1=Host
function GetTemp() {
  echo "Getting $1 temperature: "
  ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW sdr type temperature | cut -d \| -f1,5
}
# $1=Host
function GetCPUMaxTemp() {
  local CPU1TEMP
  local CPU2TEMP
  CPU1TEMP=$(ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW sdr type temperature | grep 0Eh | cut -d \| -f5 | $GREP -o '\d\d')
  if [[ -z $CPU1TEMP ]]; then
    CPU1TEMP=$(ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW sdr type temperature | grep 01h | cut -d \| -f5 | $GREP -o '\d\d')
  fi
  CPU2TEMP=$(ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW sdr type temperature | grep 0Fh | cut -d \| -f5 | $GREP -o '\d\d')
  if [[ -z $CPU2TEMP ]]; then
    CPU2TEMP=$(ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW sdr type temperature | grep 02h | cut -d \| -f5 | $GREP -o '\d\d')
  fi

  if [[ -z $CPU2TEMP ]]; then
    echo "$CPU1TEMP"
  elif [[ $CPU1TEMP -ge $CPU2TEMP ]]; then
    echo "$CPU1TEMP"
  else
    echo "$CPU2TEMP"
  fi
}

# $1=Host
function SetFanByCPUTemp() {
  local CPUTemp=$(GetCPUMaxTemp "$1")
  echo "$1 Current CPU Temp: $CPUTemp ??C"
  if [[ $CPUTemp > $HIGHTEMP ]]; then
    SetFanAuto $1
  elif [[ $CPUTemp > $LOWTEMP ]]; then
    SetFanLevel $1 $MIDFAN
  elif [[ $CPUTemp > $STOPTEMP ]]; then
    SetFanLevel $1 $LOWFAN
  else
    SetFanLevel $1 $STOPFAN
  fi
}

function PrintUsage() {
  echo "Usage: poweredge_ipmi.sh COMMAND HOST [SPEED]"
  echo ""
  echo "  COMMAND: "
  echo "    temp      Get Current Temperature"
  echo "    fan       Get or Set Current Fan Speed"
  echo "  HOST: "
  echo "    <number>  Host Number in List (Start from 0)"
  echo "    all       All Host"
  echo "  SPEED: "
  echo "    <number>  Set Fan Speed (1-100)"
  echo "    idrac     Set Fan Speed to iDRAC Controlled"
  echo "    auto      Set Fan Speed by Using this Script"
}


if [[ "$1" == temp ]]; then
  if [[ -z "$2" ]] || [[ "$2" == all ]]; then
    for HOST in "${IPMIHOST[@]}"; do
      GetTemp $HOST
    done
  else
    GetTemp "${IPMIHOST[$2]}"
  fi
elif [[ "$1" == fan ]]; then

  if [[ "$3" == idrac ]]; then
    if [[ "$2" == all ]]; then
      for HOST in "${IPMIHOST[@]}"; do
        SetFanAuto $HOST
      done
    else
      SetFanAuto "${IPMIHOST[$2]}"
    fi

  elif [[ "$3" == auto ]]; then
    while :
    do
    if [[ "$2" == all ]]; then
      for HOST in "${IPMIHOST[@]}"; do
        SetFanByCPUTemp $HOST
      done
    else
      SetFanByCPUTemp "${IPMIHOST[$2]}"
    fi
    sleep $INTERVAL
    done

  elif [[ "$3" -ge 1 ]] && [[ "$3" -le 100 ]]; then
    if [[ "$2" == all ]]; then
      for HOST in "${IPMIHOST[@]}"; do
        SetFanLevel $HOST $3
      done
    else
      SetFanLevel "${IPMIHOST[$2]}" $3
    fi
  else
    if [[ "$2" == all ]]; then
      for HOST in "${IPMIHOST[@]}"; do
        GetFanLevel $HOST
      done
    else
      GetFanLevel "${IPMIHOST[$2]}"
    fi
  fi
else
  PrintUsage
fi
