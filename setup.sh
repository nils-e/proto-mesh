#!/bin/bash

FILE="/etc/proto-mesh/utils/protomesh.service"
# Make sure proto-mesh is not already "installed"
if [ -f "$FILE" ] && [ "$1" != '-f' ]
then
   echo "Proto-mesh already configured to start at boot."
   echo "(Use -f if neccessary)"
   exit
fi

echo "Intiailzing..."

# Enable the batman-adv kernal module
modprobe batman-adv
if [ $? != 0 ]; then echo 'batman-adv kernal module not present!';exit 1; fi

echo "Copying Files..."
sudo cp -rf proto-mesh /etc/proto-mesh

# Get name of WiFi interface
WIFI_IFACE=$(iwconfig 2>/dev/null | grep IEEE | awk '{print $1}')

# Generate Config if Necessary
if [ ! -f /etc/proto-mesh/config ]
then
    echo "Generating Config File..."
    sudo sed -e "s:DEFAULT_IFACE=:DEFAULT_IFACE=$WIFI_IFACE:g" /etc/proto-mesh/config.sample > /etc/proto-mesh/config
fi

# Generate Ethernet Config if Necessary
if [ ! -f /etc/proto-mesh/channel/.eth/config ]
then
    echo "Generating Ethernet Config File..."
    sudo cp /etc/proto-mesh/channels/.eth/config.sample /etc/proto-mesh/channels/.eth/config
fi

# Generate WiFi Config if Necessary
if [ ! -f /etc/proto-mesh/channel/.wifi/config ]
then
    echo "Generating Wifi Config File..."
    sudo sed -e "s:IFACE=:IFACE=$WIFI_IFACE:g" /etc/proto-mesh/channels/.wifi/config.sample > /etc/proto-mesh/channels/.wifi/config
fi

if [ ! -f /etc/proto-mesh/channel/.wifi5/config ]
then
    echo "Generating Wifi (5G) Config File..."
    sudo cp /etc/proto-mesh/channels/.wifi5/config.sample /etc/proto-mesh/channels/.wifi5/config
fi

echo "Installing Pre-Reqs..."

# Load config file
source /etc/proto-mesh/config

# Verify that some packages are installed
requirepackage(){
   if [ ! -z "$2" ]
      then
         ldconfig -p | grep $2 > /dev/null
      else
         which $1 > /dev/null
   fi
   if [ $? != 0 ]
      then
         echo "Package $1: Installing..."
         apt-get install --assume-yes $1 > /dev/null
         echo "Package $1: Complete."
      else
         echo "Package $1: Already installed."
   fi
}
# Verify that some packages are installed
requiregitpackage(){
   if [ ! -d "/etc/proto-mesh/git-packages/$1" ]
      then
         echo "Git-Package $1: Installing..."
         mkdir -p "/etc/proto-mesh/git-packages/$1"
         git clone "https://github.com/$1" "/etc/proto-mesh/git-packages/$1" > /dev/null
         cd "/etc/proto-mesh/git-packages/$1"
         make > /dev/null
         sudo make install > /dev/null
         cd ../
         echo "Git-Package $1: Complete."
      else
         echo "Git-Package $1: Already installed"
   fi
}

#Install Required Packages
requirepackage batctl
requirepackage python3
requirepackage ip
requirepackage libsodium-dev libsodium
requirepackage bridge-utils

if [ $ENABLE_KADNODE == '1' ]; then
  requiregitpackage mwarning/KadNode
fi

#Generate Service File
echo "Generating Service File..."
sudo cp /etc/proto-mesh/utils/protomesh.service /etc/systemd/system/protomesh.service

#Make Start/Stop Scripts Executable
echo "Setting Permissions..."
sudo chmod +x /etc/proto-mesh/start.sh
sudo chmod +x /etc/proto-mesh/shutdown.sh

#Enable and Start Service
echo "Starting protomesh service..."

#Prompt for Boot
read -p "Start Proto-Mesh on Boot (Y/n)? " CONT
CONT=${CONT,,} # tolower
if [ "$CONT" = "n" ]; then
  sudo systemctl disable protomesh.service
else
  sudo systemctl enable protomesh.service
fi

sudo systemctl daemon-reload
sudo systemctl start protomesh.service
echo "Setup Complete!"
