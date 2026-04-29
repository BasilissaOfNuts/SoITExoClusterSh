#!/bin/bash

echo "ðŸš€ Starting Exo Worker Optimized Setup..."
sleep 2

# 1. Disable Spotlight Indexing
echo "ðŸ›¡ï¸  Disabling Spotlight (RAM Saver)..."
sudo mdutil -a -i off
sleep 3

# 2. Disable Background Services
echo "ðŸ§¹ Cleaning up background daemons (Siri, Photos, AI)..."
SERVICES=(
    "com.apple.Siri"
    "com.apple.assistantd"
    "com.apple.parsec-fbf"
    "com.apple.photoanalysisd"
    "com.apple.mediaanalysisd"
    "com.apple.triald"
)

for service in "${SERVICES[@]}"; do
    echo "   - Disabling $service"
    launchctl disable gui/$(id -u)/$service
    sleep 1
done

# 3. Create LaunchAgents Directory
echo "ðŸ“‚ Ensuring LaunchAgents directory exists..."
mkdir -p ~/Library/LaunchAgents
sleep 2

# 4. Create the Exo Worker Plist
echo "ðŸ“ Writing Exo Worker configuration..."
sudo nano /Library/LaunchAgents/com.exo.worker.plist

sleep 2

echo "ðŸ›¡ï¸  Configuring Kernel Power Management for Cluster Mode..."

# 1. Disable all forms of Sleep, Standby, and Hibernation
sudo pmset -a sleep 0
sudo pmset -a displaysleep 0
sudo pmset -a disksleep 0
sudo pmset -a hibernatefile /dev/null
sudo pmset -a hibernatemode 0
sudo pmset -a standby 0
sudo pmset -a autopoweroff 0

# 2. Keep the Network & Thunderbolt Bridge 'Armed'
sudo pmset -a womp 1            # Wake on Magic Packet
sudo pmset -a networkoversleep 0 # Prevents the NIC from napping
sudo pmset -a ttyskeepawake 1   # Keeps the system alive as long as a process (Exo) is active

# 3. Disable 'Power Nap' (It causes CPU spikes for maintenance that ruin inference)
sudo pmset -a powernap 0

# 4. Tahoe-Specific: Disable background task throttling
# This prevents the OS from moving Exo to the 'Efficiency' cores when the screen is off
sudo sysctl debug.lowpri_throttle_enabled=0

# 5. Set Permissions and Bootstrap
echo "ðŸ”’ Setting permissions and starting Exo in background..."
chmod 644 ~/Library/LaunchAgents/com.exo.worker.plist
sleep 2

sudo launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.exo.worker.plist
sleep 3

echo "âœ… Setup Complete! Exo is now running as a headless worker."
echo "âš ï¸  Reminder: Go to System Settings and toggle Exo 'ON' in Background Activity."

# 6. Fix for node names

# Unload the old one first
launchctl unload ~/Library/LaunchAgents/com.exo.worker.plist

sudo pkill -9 exo

# Remove the identity and cache files
rm -rf /Users/macadmin/.exo/*

sudo nano ~/Library/LaunchAgents/com.exo.worker.plist

# Load the new version with the unique name
launchctl load ~/Library/LaunchAgents/com.exo.worker.plist

# 7. Thunderbolt IP Lockdown

# Lock Bridge 1 (e.g. Incoming from Node 1)
sudo networksetup -setmanual "EXO Thunderbolt 1" 10.0.1.2 255.255.255.0

# Lock Bridge 2 (e.g. Outgoing to Node 3)
sudo networksetup -setmanual "EXO Thunderbolt 2" 10.0.2.2 255.255.255.0

# Then paste these into the shell file here
sudo nano /Library/LaunchDaemons/com.exo.networkfix.plist

sudo chown root:wheel /Library/LaunchDaemons/com.exo.networkfix.plist
sudo chmod 644 /Library/LaunchDaemons/com.exo.networkfix.plist
sudo launchctl load -w /Library/LaunchDaemons/com.exo.networkfix.plist
