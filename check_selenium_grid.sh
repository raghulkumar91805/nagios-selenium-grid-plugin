#!/bin/bash

# default values
warn_default=70
warning=$warn_default
critical_default=95
critical=$critical_default
browsers_to_check_default="chrome,firefox,internet_explorer"
IFS=',' read -r -a browsers_to_check <<< "$browsers_to_check_default"
check_status=0 # 0 - ok, 1 - warn, 2 - critical
check_message=""
perf_data=""

# usage function
function usage {
    echo " "
    echo "  usage: $0 -u http://seleniumserver:port/grid/console [-w warning_percentage] [-c critical_precentage] [-t browser_types_to_check]"
    echo "    -u  selenium grid console url"
    echo "    -w  warn in case of '100 * busy sessions / all sessions + 1' of one of the browser types is greater than the entered value (precentage). default is: $warn_default"
    echo "    -c  error in case of '100 * busy sessions / all sessions + 1' of one of the browser types is greater than the entered value (precentage). default is: $critical_default"
    echo "    -t  browser types to check. We 'wc -l' the <browser_type>.png in the console to find all sessions and after that 'wc -l' class=busy for the busy ones. default is: $browsers_to_check_default"
    echo "    -h  display help"
    exit 2
}

# check function extracts the data from selenium grid's console, exit in case of incorrect data  and prepare the right echo data for nagios
# $1 - browser type to check ("chrome", "firefox", "ie", etc..)
function check {

  local browser_type=$1
  local all_sessions=`echo "$console_data" | grep -o $browser_type.png | wc -l`
  local busy_sessions=`echo "$console_data" | grep $browser_type.png | grep -o class=\'busy\' | wc -l`

  if (( $all_sessions <=  "0" )); then
    echo "ERROR: $browser_type all sessions list (busy+available) is $all_sessions - could be connectivity issues or availability problem or non supported browser type in selenium"
    exit 2
  fi

  local busy_div_all=$((100*$busy_sessions/$all_sessions + 1))

  # append message
  if (($busy_div_all > $critical)); then
     check_message="$check_message ### CRITICAL: browser $browser_type, reached critical limit: $critical%, busy sessions: $busy_sessions, all sessions: $all_sessions"
  elif (($busy_div_all > $warning)); then
     check_message="$check_message ### WARNING: browser $browser_type, reached warning limit: $warning%, busy sessions: $busy_sessions, all sessions: $all_sessions"
  fi

  #set check status
  if (($busy_div_all > $critical)); then
    check_status=2
  elif (($busy_div_all > $warning)) && (($check_status < "2")); then
    check_status=1
  fi

  perf_data="$perf_data all_$browser_type=$all_sessions busy_$browser_type=$busy_sessions "
  #echo $perf_data
}


# Extract parameters from command line
while [ $# -gt 0 ]
do
  case "$1" in
    -u) url="$2"; shift;;
    -w) warning="$2"; shift;;
    -c) critical="$2"; shift;;
    -t) IFS=',' read -r -a browsers_to_check <<< "$2"; shift;;
    -h) usage;;
     *) echo "unknown cli option: $1"; usage;;
  esac
  shift
done

if [[ -z $url ]]; then
  echo "url parameter is empty"
  usage
fi

console_data=$(curl -s $url)
if [ -z "$console_data" ]; then
  echo "ERROR: problems curling grid's console: $url"
  curl $url
  exit 2
fi

# Iterate the browser types to check
for i in ${browsers_to_check[@]}; do
  check $i
done

# echo the nagios data
if [ "$check_status" -eq "0" ]; then
  echo "OK - (selenium grid: $url) | $perf_data"
  exit 0
fi

if [ "$check_status" -eq "1" ]; then
  echo "WARNING ($url) - $check_message - (selenium grid: $url) | $perf_data"
  exit $check_status
fi

echo "CRITICAL - $check_message - (selenium grid: $url) | $perf_data"
exit $check_status

