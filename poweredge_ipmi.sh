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
IPMIHOST=("192.168.10.12" "192.168.10.13")   # array of iDRAC IP Address
IPMIUSER=root     # iDRAC Username
IPMIPW=$IPMIPW    # iDRAC Password
INTERVAL=90       # Sleep seconds between Check
TEMP_AUTO=86
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
  echo "$1 Current CPU Temp: $CPUTemp °C"
  if [[ $CPUTemp > $TEMP_AUTO ]]; then
    SetFanAuto $1
  elif [[ $CPUTemp > $TEMP_8 ]]; then
    SetFanLevel $1 $FAN_9
  elif [[ $CPUTemp > $TEMP_7 ]]; then
    SetFanLevel $1 $FAN_8
  elif [[ $CPUTemp > $TEMP_6 ]]; then
    SetFanLevel $1 $FAN_7
  elif [[ $CPUTemp > $TEMP_5 ]]; then
    SetFanLevel $1 $FAN_6
  elif [[ $CPUTemp > $TEMP_4 ]]; then
    SetFanLevel $1 $FAN_5
  elif [[ $CPUTemp > $TEMP_3 ]]; then
    SetFanLevel $1 $FAN_4
  elif [[ $CPUTemp > $TEMP_2 ]]; then
    SetFanLevel $1 $FAN_3
  elif [[ $CPUTemp > $TEMP_1 ]]; then
    SetFanLevel $1 $FAN_2
  else
    SetFanLevel $1 $FAN_1
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
