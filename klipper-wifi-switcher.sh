#!/usr/bin/bash


# line="@reboot /path/to/command"

if [[ $* == *--run* ]]; then
    # Locate config folder
    if [ -d "$HOME/printer_data/config" ]; then
        folder="$HOME/printer_data/config"
    elif [ -d "$HOME/klipper_config" ]; then 
        folder="$HOME/klipper_config"
    else 
        echo "Could not find your klipper config folder"
    fi

    MyFile="$folder/wifi.txt"

    if [ -f $MyFile ]; then 
        echo "Reading $MyFile"

        # read each line of file
        while IFS= read -r line || [ -n "$line" ]; do
        printf 'hello %s' "$line"
        eval "arr=($line)"
        echo nmcli dev wifi connect "${arr[0]}" password "${arr[1]}"
        if nmcli dev wifi connect "${arr[0]}" password "${arr[1]}"; then 
            printf "Successfully connected to %s" "${arr[0]}"
            break
        else
            printf "Could not connect to %s" "${arr[0]}"
        fi   
        done < "$MyFile"
    else 
        echo "$MyFile does not exist; skipping"
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