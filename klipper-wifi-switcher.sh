#!/usr/bin/bash


# line="@reboot /path/to/command"

function wlog() {
    echo $* | tee -a $logfile
}

if [[ $* == *--run* ]]; then
    # Locate config folder
    if [ -d "$HOME/printer_data/config" ]; then
        folder="$HOME/printer_data/config"
    elif [ -d "$HOME/klipper_config" ]; then 
        folder="$HOME/klipper_config"
    else 
        echo "Could not find your klipper config folder"
    fi

    # Locate log folder
    if [ -d "$HOME/printer_data/logs" ]; then
        logfile="$HOME/printer_data/logs/wifi.log"
    else 
        echo "Could not find your klipper log folder"
        logfile="/tmp/wifi.log"
    fi

    wlog ""
    wlog "Klipper Wifi Switcher started at $(date)"

    WifiTxt="$folder/wifi.txt"

    if [ -f $WifiTxt ]; then 
        wlog "Reading $WifiTxt"

        # read each line of file
        while IFS= read -r line || [ -n "$line" ]; do
            eval "arr=($line)"
            echo nmcli dev wifi connect "${arr[0]}" password "${arr[1]}"
            if nmcli dev wifi connect "${arr[0]}" password "${arr[1]}" 2>&1 | tee -a $logfile; then 
                wlog "Successfully connected to ${arr[0]}"
                break
            else
                wlog "Could not connect to ${arr[0]}"
            fi   
        done < "$WifiTxt"
    else 
        wlog "$WifiTxt does not exist; skipping"
    fi
else 
    #Install by adding to crontab to be executed on reboot
    SCRIPT=$(realpath "$0")
    SCRIPTPATH=$(dirname "$SCRIPT")

    crontabLine="@reboot $SCRIPTPATH/$SCRIPT --run"

    # check crontab for existence of line
    crontab=$(crontab -u $(whoami) -l)

    if [[ "$crontab" != *"$crontabLine"* ]]; then
        echo "Adding to crontab"
        (crontab -u $(whoami) -l; echo "$crontabLine" ) | crontab -u $(whoami) -
    else 
        echo "Already installed"
    fi
fi