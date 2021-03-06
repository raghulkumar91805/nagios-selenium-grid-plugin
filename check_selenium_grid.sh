#!/bin/bash

# default values
warn_default=70
warning=$warn_default
critical_default=95
critical=$critical_default
browsers_to_check_default="chrome,firefox,internet_explorer"
IFS=',' read -r -a browsers_to_check <<< "$browsers_to_check_default"
jenkins_jobs=""
check_status=0 # 0 - ok, 1 - warn, 2 - critical
check_message=""
perf_data=""

# usage function
function usage {
    echo " "
    echo "  usage: $0 -u http://seleniumserver:port/grid/console [-w warning_percentage] [-c critical_precentage] [-t browser_types_to_check] [-e http://jenkinsserver:port/jenkins] [-j jobs_to_monitor]"
    echo "    -u  selenium grid console url"
    echo "    -w  warn in case of '100 * busy sessions / all sessions + 1' of one of the browser types is greater than the entered value (precentage). default is: $warn_default"
    echo "    -c  error in case of '100 * busy sessions / all sessions + 1' of one of the browser types is greater than the entered value (precentage). default is: $critical_default"
    echo "    -t  browser types to check. We 'wc -l' on grep of 'browser_type.png' (fallback to 'browser_type</a>') from the console to find all sessions and after that 'wc -l' on grep of 'class=busy' for the busy ones. default is: $browsers_to_check_default"
    echo "    -e  jenkins url"
    echo "    -j  jenkins running jobs to monitor, we can use it to correlate high consumption in selenium grid with high activity in jenkins. the data presented is magnified by factor of 10 to have better visal correlation ability against selenium data. example for jobs list: jobA,jobB,jobC"
    echo "    -h  display help"
    exit 2
}

# check function extracts the data from selenium grid's console, exit in case of incorrect data  and prepare the right echo data for nagios
# $1 - browser type to check ("chrome", "firefox", "ie", etc..)
function check {

  local browser_type=$1
  local browser_type_grep_string="$browser_type.png"
  local all_sessions=`echo "$console_data" | grep -o "$browser_type_grep_string" | wc -l`

  #fallback for browser types that do not have icon, like 'htmlunit'
  if (( $all_sessions <= "0" )); then
    browser_type_grep_string="$browser_type</a>"
    all_sessions=`echo "$console_data" | grep -o "$browser_type_grep_string" | wc -l`
  fi

  local busy_sessions=`echo "$console_data" | grep "$browser_type_grep_string" | grep -o class=\'busy\' | wc -l`
  browser_type_to_print=$(echo "$browser_type" | sed -e 's/ /_/g')

  local busy_div_all="0"
  if (( $all_sessions >  "0" )); then
     busy_div_all=$((100*$busy_sessions/$all_sessions + 1))
  fi

  # append message
  if (($busy_div_all > $critical)); then
     check_message="$check_message ### CRITICAL: browser $browser_type_to_print, reached critical limit: $critical%, busy sessions: $busy_sessions, all sessions: $all_sessions"
  elif (($busy_div_all > $warning)); then
     check_message="$check_message ### WARNING: browser $browser_type_to_print, reached warning limit: $warning%, busy sessions: $busy_sessions, all sessions: $all_sessions"
  fi

  #set check status
  if (($busy_div_all > $critical)); then
    check_status=2
  elif (($busy_div_all > $warning)) && (($check_status < "2")); then
    check_status=1
  fi

  perf_data="$perf_data all_$browser_type_to_print=$all_sessions busy_$browser_type_to_print=$busy_sessions"
  #echo $perf_data
}


# Extract parameters from command line
while [ $# -gt 0 ]
do
  case "$1" in
    -u) selenium_url="$2"; shift;;
    -w) warning="$2"; shift;;
    -c) critical="$2"; shift;;
    -t) IFS=',' read -r -a browsers_to_check <<< "$2"; shift;;
    -e) jenkins_url="$2"; shift;;
    -j) IFS=',' read -r -a jenkins_jobs <<< "$2"; shift;;
    -h) usage;;
     *) echo "unknown cli option: $1"; usage;;
  esac
  shift
done

# Validate cli input
if [[ -z $selenium_url ]]; then
  echo "url parameter is empty"
  usage
fi

# fetch selenium grid data
console_data=$(curl -s $selenium_url)
if [ -z "$console_data" ]; then
  echo "ERROR: problems curling grid's console: $selenium_url"
  curl $selenium_url
  exit 2
fi

# Iterate the browser types to check usage
for i in "${browsers_to_check[@]}"; do
  check "$i"
done

# fetch jenkins data
if [ ! -z "$jenkins_url" ]; then
  all_active_jobs=$(curl -s -g "$jenkins_url/computer/api/xml?tree=computer[executors[currentExecutable[url]],oneOffExecutors[currentExecutable[url]]]&xpath=//url&wrapper=builds")

  for i in ${jenkins_jobs[@]}; do
    # we add the "<name>" to the grep to count the job only once and not twice as it is exist in the url param as well
    count=$((10*$(echo "$all_active_jobs" | grep -o "$i" | wc -l)))
    perf_data="$perf_data $i*10=$count"
  done

fi


# echo the nagios data
if [ "$check_status" -eq "0" ]; then
  echo "OK - (selenium grid: $selenium_url, jenkins: $jenkins_url) | $perf_data"
  exit 0
fi

if [ "$check_status" -eq "1" ]; then
  echo "WARNING - $check_message - (selenium grid: $selenium_url, jenkins: $jenkins_url) | $perf_data"
  exit $check_status
fi

echo "CRITICAL - $check_message - (selenium grid: $selenium_url, jenkins: $jenkins_url) | $perf_data"
exit $check_status

