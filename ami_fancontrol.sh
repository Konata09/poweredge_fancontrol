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

# Settings
IPMIHOST=("192.168.10.19")                  # Array of BMC IP Address
IPMIUSER=admin                              # BMC Username
IPMIPW=$IPMIPW                              # BMC Password
INTERVAL=60                                # Sleep seconds between Check
TEMP_AUTO=95
TEMP_1=80
TEMP_2=82
TEMP_3=84
TEMP_4=86
TEMP_5=88
TEMP_6=90
TEMP_7=92
TEMP_8=94
FAN_1=10
FAN_2=11
FAN_3=12
FAN_4=13
FAN_5=14
FAN_6=15
FAN_7=20
FAN_8=25
FAN_9=30

QSESSIONID=""
CSRFTOKEN=""

# $1=Host
function RefreshToken() {
  qsidRegex="QSESSIONID=([a-zA-Z0-9]*)"
  cftokenRegex="\"CSRFToken\":\s*?\"([a-zA-Z0-9]*)\""
  local RES=$(curl -v -s -k "https://$1/api/session" -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -d "username=$IPMIUSER&password=$IPMIPW" 2>&1)

  if [[ $RES =~ $qsidRegex ]]; then
      QSESSIONID="${BASH_REMATCH[1]}"
  else
      echo "Get QSESSIONID failed"
  fi

  if [[ $RES =~ $cftokenRegex ]]; then
      CSRFTOKEN="${BASH_REMATCH[1]}"
  else
      echo "Get CSRFTOKEN failed"
  fi

  if [[ -z "$QSESSIONID" ]] || [[ -z "$CSRFTOKEN" ]]; then
    echo "Login failed QSESSIONID ==> $QSESSIONID CSRFTOKEN ==> $CSRFTOKEN"
  else
    echo "Login success QSESSIONID ==> $QSESSIONID CSRFTOKEN ==> $CSRFTOKEN"
  fi
}

# $1=Host $2=Retry
function SetFanAuto() {
  echo "Setting $1 fan speed to BMC controlled"
  local RES=$(curl -s -k "https://$1/api/settings/FanModes" -H "Content-Type: application/json" -H "Cookie: QSESSIONID=$QSESSIONID" -H "X-CSRFTOKEN: $CSRFTOKEN" --data-raw "{\"CompletionCode\":0,\"fan_mode\":\"0\",\"fans_speed\":\"-1\"}")
  echo "Result: $RES"

  if [[ $RES =~ 'Invalid Authentication' ]] && [[ -z $2 ]]; then
    echo "Need login to $1"
    RefreshToken $1
    SetFanAuto $1 true
  fi
}

# $1=Host $2=Level $3=Retry
function SetFanLevel() {
  echo "Setting $1 fan speed to $2%"
  local RES=$(curl -s -k "https://$1/api/settings/FanModes" -H "Content-Type: application/json" -H "Cookie: QSESSIONID=$QSESSIONID" -H "X-CSRFTOKEN: $CSRFTOKEN" --data-raw "{\"CompletionCode\":0,\"fan_mode\":\"1\",\"fans_speed\":\"$2\"}")
  echo "Result: $RES"

  if [[ $RES =~ 'Invalid Authentication' ]] && [[ -z $2 ]]; then
    echo "Need login to $1"
    RefreshToken $1
    SetFanAuto $1 $2 true
  fi
}

# $1=Host
function GetFanLevel() {
  echo "Getting $1 fan speed: "
  ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW sdr type fan | cut -d \| -f1,5
}

# $1=Host
function GetTemp() {
  echo "Getting $1 temperature: "
  ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW sdr type temperature | cut -d \| -f1,5
}
# $1=Host
function GetCPUMaxTemp() {
  local CPU1TEMP
  CPU1TEMP=$(ipmitool -I lanplus -H $1 -U $IPMIUSER -P $IPMIPW sdr type temperature | $GREP 'CPU0_Temp' | cut -d \| -f5 | $GREP -o '\d+')
  echo $CPU1TEMP
}

# $1=Host
function SetFanByCPUTemp() {
  local CPUTemp=$(GetCPUMaxTemp "$1")
  echo "$1 Current CPU Temp: $CPUTemp °C"
  if [[ $CPUTemp -gt $TEMP_AUTO ]]; then
    SetFanAuto $1
  elif [[ $CPUTemp -gt $TEMP_8 ]]; then
    SetFanLevel $1 $FAN_9
  elif [[ $CPUTemp -gt $TEMP_7 ]]; then
    SetFanLevel $1 $FAN_8
  elif [[ $CPUTemp -gt $TEMP_6 ]]; then
    SetFanLevel $1 $FAN_7
  elif [[ $CPUTemp -gt $TEMP_5 ]]; then
    SetFanLevel $1 $FAN_6
  elif [[ $CPUTemp -gt $TEMP_4 ]]; then
    SetFanLevel $1 $FAN_5
  elif [[ $CPUTemp -gt $TEMP_3 ]]; then
    SetFanLevel $1 $FAN_4
  elif [[ $CPUTemp -gt $TEMP_2 ]]; then
    SetFanLevel $1 $FAN_3
  elif [[ $CPUTemp -gt $TEMP_1 ]]; then
    SetFanLevel $1 $FAN_2
  else
    SetFanLevel $1 $FAN_1
  fi
}

function PrintUsage() {
  echo "Usage: ami_fancontrol.sh COMMAND HOST [SPEED]"
  echo ""
  echo "  COMMAND: "
  echo "    temp      Get Current Temperature"
  echo "    fan       Get or Set Current Fan Speed"
  echo "  HOST: "
  echo "    <number>  Host Number in List (Start from 0)"
  echo "    all       All Host"
  echo "  SPEED: "
  echo "    <number>  Set Fan Speed (1-100)"
  echo "    bmc       Set Fan Speed to BMC Controlled"
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

  if [[ "$3" == bmc ]]; then
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
