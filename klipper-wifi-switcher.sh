#!/usr/bin/bash

# -------------------------------------------------------------------------
# GLOBAL VARIABLES
# These are declared here for documentation purposes. In most cases they are
# set further in the script.
# -------------------------------------------------------------------------

# Location of wifi.txt file filled in later
wifi_txt=""

# Location of wifi.log file filled in later
wifi_log=""

# The method of configuring the network -- either "nmcli" or "wpa_cli"
# filled in later
network_method=""

# Interface name to use.
wlan0="wlan0"

# As networks are added they are added to this array as string SSID<tab>ID
# where ID is how they are referred to by wpa_cli or nmcli
networks_added=()

# Scan the system and set the global variables above.
function scan_system() {
    # Locate log folder
    if [ -d "$HOME/printer_data/logs" ]; then
        wifi_log="$HOME/printer_data/logs/wifi.log"
    elif [ -d "$HOME/klipper_logs" ]; then
        wifi_log="$HOME/klipper_logs/wifi.log"
    else 
        echo "Could not find your klipper log folder"
        logfile="/tmp/wifi.log"
    fi

    # Locate config folder
    if [ -d "$HOME/printer_data/config" ]; then
        wifi_txt="$HOME/printer_data/config/wifi.txt"
    elif [ -d "$HOME/klipper_config" ]; then 
        wifi_txt="$HOME/klipper_config/wifi.txt"
    else 
        echo "Could not find your klipper config folder"
    fi

    # if wpa_supplicant.conf exists, use wpa_cli otherwise
    # use nmcli
    if [ -f "/etc/wpa_supplicant/wpa_supplicant.conf" ]; then 
        network_method="wpa_cli"
    else 
        network_method="nmcli"
    fi
}

# Log a line with timestamp to the log file.
function wlog() {
    local timestamp=$(date)
    local line="$timestamp:$*"
    if [ ! -z "$wifi_log" ]; then 
        echo "$line" | tee -a $wifi_log
    else 
        echo "$line"
    fi
}

# send a command to wpa_cli and log the errors
function my_wpa_cli() {
    wlog "wpa_cli $*"
    result=$(wpa_cli $*)
    if [ ! $result="OK" ]; then 
        wlog "Failed to execute: wpa_cli $*"
    fi
}

function logexec() {
    wlog ">$*"
    "$@"
    return $?        
}

# Trim whitespace
function trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}


# Before we start, if we are using network manager we need to remove all the 
# connections that we previously created, since they survive reboots.
function remove_old_connections() {
    echo "Removing old connections"
    if [ "$network_method" = "nmcli" ]; then
        local names
        local uuids
        readarray -t names <<<$(nmcli -f NAME c)
        readarray -t uuids <<<$(nmcli -f UUID c)
        for ((i=1; i<${#names[@]}; i++)); do
            local name="${names[$i]}";
            local uuid=$(trim "${uuids[$i]}");
            echo "$name:$uuid"
            if [[ "$name" = wifi-switcher-* ]]; then 
                logexec nmcli connection delete "$uuid"
            fi
        done
    fi 
}

# Add a connection. Takes as arguments ssid, password (can be empty) and priority (higher better)
function add_connection() {
    local SSID=$1
    local password=$2
    local priority=$3

    wlog "Adding connection '$SSID:$password' with priority $priority"

    if [ "$network_method" = "wpa_cli" ]; then 
        id=$(wpa_cli -i $wlan0 add_network)
        my_wpa_cli -i $wlan0 set_network $id ssid '"'$SSID'"'
        my_wpa_cli -i $wlan0 set_network $id psk '"'$password'"'
        my_wpa_cli -i $wlan0 set_network $id priority $priority
        my_wpa_cli -i $wlan0 enable_network $id 
        networks_added+=("$SSID\t$id")
    else 
        if [ -z "$password" ]; then 
            logexec nmcli con add type wifi con-name "wifi-switcher-$SSID" ssid "$SSID" connection.autoconnect-priority $priority connection.autoconnect TRUE
        else 
            logexec nmcli con add type wifi con-name "wifi-switcher-$SSID" ssid "$SSID" wifi-sec.psk "$password" wifi-sec.key-mgmt wpa-psk connection.autoconnect-priority $priority connection.autoconnect TRUE
        fi
    fi
}

#ensured all added networks are placed into networks_added
function get_added_networks() {
    if [ "$network_method" = "nmcli" ]; then
        local arr 
        readarray -t arr < <(nmcli -t -f NAME,UUID conn show)
        echo "result of arr is" ${arr[1]/:/"    "}
        for i in "${arr[@]}"; do 
            if [[ "$i" = wifi-switcher-* ]]; then 
                tmp=${i/wifi-switcher-/}
                networks_added+=("${tmp/:/	}")
            fi
        done
    fi
}

# Retrieve the list of networks currently visible into array passed in.
function scan_networks() {
    local -n result=$1
    if [ "$network_method" = "wpa_cli" ]; then
        wpa_cli -i $wlan0 scan
        readarray -t result < <(wpa_cli -i $wlan0 scan_results | cut -f5) 
    else
        readarray -t result < <(nmcli -t -f SSID dev wifi)
    fi
}

function containsElement() {
    local -n array=$1
    if [[ " ${array[*]} " =~ " ${2} " ]]; then 
        return 0
    fi
    return 1
}

# try to connect to the given SSID. It must be listed in
# networks_added as "$SSID<tab>network manager id"
function try_connect() {
    local ssid=$1
    for line in "${networks_added[@]}"; do 
        if [[ "$line" = "$ssid"* ]]; then 
            if [ "$network_method" = "wpa_cli" ]; then
                echo "This should not happen"
                # I think we would use my_wpa_cli -i $wlan0 select_network
            else 
                logexec nmcli conn up $(cut -f2 <<< ${line})
                if [ $? -eq 0 ]; then
                    return 0
                fi
            fi
        fi
    done
    return 1
}

# After we have finished adding all of the network, go through them in order
# listed in wifi.txt file. If that SSID can be seen, attempt to connect to it.
function reconnect() {
    if [ "$network_method" = "wpa_cli" ]; then
        # we just need to do this
        my_wpa_cli -i $wlan0 reassociate
        return 
    fi
    
    # scan the networks to see what exists
    scan_networks visible 

    while IFS= read -r line || [ -n "$line" ]; do
        eval "arr=($line)"
        local ssid="${arr[0]}"
        if containsElement visible "$ssid"; then  
            wlog "$ssid is visible. Trying to connect..."
            if try_connect "$ssid"; then 
                wlog "Connected to ${ssid}"
                break
            fi
            echo "Failed to connect to $ssid"
        else 
            wlog "$ssid is not visible."
        fi
    done < "$wifi_txt"
}

function on_computer_restart() {
    scan_system    

    if [ -z "$wifi_txt" ]; then 
        wlog "No wifi.txt file found; skipping."
    else 
        wlog "Reading $wifi_txt"
        priority=100
        
        remove_old_connections

        # read each line of file
        while IFS= read -r line || [ -n "$line" ]; do
            if [ -z "$line" ]; then 
                echo "Skip blank line"
                continue
            fi
            eval "arr=($line)"
            add_connection "${arr[0]}" "${arr[1]}" $priority
            priority=$((priority-1))
        done < "$wifi_txt"

        get_added_networks
        echo "Networks added was ${networks_added[1]}"
        for i in "${networks_added[@]}"; do 
            echo "Network added: $i"
        done

        reconnect
    fi 
}

if [[ $* == *--run* ]]; then
    on_computer_restart
else 
    #Install by adding to crontab to be executed on reboot
    SCRIPT=$(realpath "$0")

    crontabLine="@reboot $SCRIPT --run"

    # check crontab for existence of line
    crontab=$(crontab -u $(whoami) -l)

    if [[ "$crontab" != *"$crontabLine"* ]]; then
        (crontab -u $(whoami) -l; echo "$crontabLine" ) | crontab -u $(whoami) -
        echo "Adding to crontab"
    else 
        echo "Already installed"
    fi
fi
