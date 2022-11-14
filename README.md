# klipper-wifi-switcher
Easily switch Wifi networks by editing a config file in the web interface.

## Current status

It works for orange pi and other devices that use NetworkManager. Raspberry pi however uses wpa_supplicant instead, and it still needs some work (90% there, will accept pull requests).

## Installation
After installing klipper, paste this line into the terminal.

    curl https://raw.githubusercontent.com/smhanov/klipper-wifi-switcher/main/klipper-wifi-switcher.sh -o $HOME/klipper-wifi-switcher.sh && chmod +x $HOME/klipper-wifi-switcher.sh && $HOME/klipper-wifi-switcher.sh
    
## Usage
When you want to switch wifi networks, create a file called `wifi.txt` in the klipper config folder, using the web interface. The file is a list of Wifi SSID and passwords that you want to try to connect to on reboot. The next time the system reboots, it will configure those connections and make them available to the system's wifi connection manager. In addition, it will go through the list in order and connect to any of them currently visible.

Use quotes if the SSID or password has spaces in it.

Example wifi.txt, showing networks with passwords, spaces, and an open network with no password.

    MYHOUSE password123
    "My home network"  "password@@#!!!"
    OpenCoffeeNetwork
 
## Uninstallation
Type crontab -e and remove the line referencing klipper-wifi-switcher from the file and save.

## Exact algorithm used
It adds a line to the crontab file that says run it on system startup, not at a particular time, and at that time it is run with the "--run" option.

When run with the --run option, it does the follwing steps:

- open the wifi.txt file
- remove any networks we specificially added last reboot (distinguished using the name wifi-switcher-*). This is applicable only on NetworkManager systems where the changes are permanent.
- Add all of the networks to either wpa_supplicant or NetworkManager, setting an auto-connect priority so that the first listed is higher priority, etc. 
- Next, because the wpa_supplicant (which it also used by NetworkManager) doesn't want to autoconnect to networks it hasn't connected to before, we explicityly go through the list in order, and if any are visible, connect to it. Stop when we successfully connect to one of the networks listed, or we exhaust the list.
