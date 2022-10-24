# klipper-wifi-switcher
Easily switch Wifi networks by editing a config file in the web interface.

## Installation
After installing klipper, paste this line into the terminal.

    curl https://raw.githubusercontent.com/smhanov/klipper-wifi-switcher/main/klipper-wifi-switcher.sh -o $HOME/klipper-wifi-switcher.sh && chmod +x $HOME/klipper-wifi-switcher.sh && $HOME/klipper-wifi-switcher.sh
    
## Usage
When you want to switch wifi networks, create a file called `wifi.txt` in the klipper config folder, using the web interface. The file is a list of Wifi SSID and passwords that you want to try to connect to on reboot. The next time the system reboots, it will go through this list until it gets to one that works. If none of them works, the network won't be changed.

Use quotes if the SSID or password has spaces in it.

Example wifi.txt

    MYHOUSE password123
    "My home network"  "password@@#!!!"
 
 ## Uninstallation
 Type crontab -e and remove the line referencing klipper-wifi-switcher from the file and save.
