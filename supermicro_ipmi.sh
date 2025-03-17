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
IPMIHOST=("192.168.10.14")   # array of BMC IP Address
IPMIUSER=ADMIN     # BMC Username
IPMIPW=$IPMIPW    # BMC Password
INTERVAL=30       # Sleep seconds between Check
TEMP_1=59
TEMP_2=62
TEMP_3=65
TEMP_4=68
TEMP_5=71
TEMP_6=74
TEMP_7=77
TEMP_8=80
FAN_1=12
FAN_2=15
FAN_3=18
FAN_4=22
FAN_5=26
FAN_6=30
FAN_7=35
FAN_8=40
FAN_9=45

# 反相 PWM
# 1  - 100%
# 5  - 95%
# a  - 90%
# 0f - 85%
# 14 - 80%
# 19 - 75%
# 1e - 70%
# 23 - 65%
# 28 - 60%
# 2d - 55%
# 32 - 50%
# 37 - 45%
# 3c - 40%
# 41 - 35%
# 46 - 30%
# 4b - 25%
# 50 - 20%
# 55 - 15%
# 5a - 10%
# 5f - 5%
# 64 - 0%

# $1=Host
function SetFanHeavyIO()
{
  echo "Setting $1 fan mode to HeavyIO "
  ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW raw 0x30 0x45 0x01 0x03 > /dev/null
}

# $1=Host $2=Level $3 Zone
function SetFanLevel() {
  # reverse
  local LEVEL=$(printf '0x%x' $((100-$2)))
  echo "Setting $1 Zone$3 fan speed to $2%"
  ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW raw 0x30 0x70 0x66 0x01 0x0$3 $LEVEL > /dev/null
}

# $1=Host
function GetFanLevel() {
  echo "Getting $1 fan speed: "
  ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW sdr type fan | $GREP 'FAN\d' | cut -d \| -f1,5
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

  if [[ $CPUTemp > $TEMP_8 ]]; then
    SetFanLevel $1 $FAN_9 1
  elif [[ $CPUTemp > $TEMP_7 ]]; then
    SetFanLevel $1 $FAN_8 1
  elif [[ $CPUTemp > $TEMP_6 ]]; then
    SetFanLevel $1 $FAN_7 1
  elif [[ $CPUTemp > $TEMP_5 ]]; then
    SetFanLevel $1 $FAN_6 1
  elif [[ $CPUTemp > $TEMP_4 ]]; then
    SetFanLevel $1 $FAN_5 1
  elif [[ $CPUTemp > $TEMP_3 ]]; then
    SetFanLevel $1 $FAN_4 1
  elif [[ $CPUTemp > $TEMP_2 ]]; then
    SetFanLevel $1 $FAN_3 1
  elif [[ $CPUTemp > $TEMP_1 ]]; then
    SetFanLevel $1 $FAN_2 1
  else
    SetFanLevel $1 $FAN_1 1
  fi
}

function PrintUsage() {
  echo "Usage: supermicro_ipmi.sh COMMAND HOST [SPEED]"
  echo ""
  echo "  COMMAND: "
  echo "    temp      Get Current Temperature"
  echo "    fan       Get or Set Current Fan Speed"
  echo "  HOST: "
  echo "    <number>  Host Number in List (Start from 0)"
  echo "    all       All Host"
  echo "  SPEED: "
  echo "    <number>  Set Fan Speed (1-100)"
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

  if [[ "$3" == auto ]]; then
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

