#!/bin/bash

# Copyright 2013 BrewPi
# This file is part of BrewPi.

# BrewPi is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# BrewPi is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with BrewPi.  If not, see <http://www.gnu.org/licenses/>.

########################
### This script assumes a clean Wheezy Raspbian install.
### Freeder, v1.0, Aug 2013
### Using a custom 'die' function shamelessly stolen from http://mywiki.wooledge.org/BashFAQ/101
### Using ideas even more shamelessly stolen from Elco and mdma. Thanks guys!
########################


############
### Functions to catch/display errors during setup
############
warn() {
  local fmt="$1"
  command shift 2>/dev/null
  echo -e "$fmt\n" "${@}"
  echo -e "\n*** ERROR ERROR ERROR ERROR ERROR ***\n----------------------------------\nSee above lines for error message\nSetup NOT completed\n"
}

die () {
  local st="$?"
  warn "$@"
  exit "$st"
}

############
### Setup questions
############

free_percentage=$(df /home | grep -vE '^Filesystem|tmpfs|cdrom|none' | awk '{ print $5 }')
free=$(df /home | grep -vE '^Filesystem|tmpfs|cdrom|none' | awk '{ print $4 }')
free_readable=$(df -H /home | grep -vE '^Filesystem|tmpfs|cdrom|none' | awk '{ print $4 }')

if [ "$free" -le "512000" ]; then
    echo "Disk usage is $free_percentage, free disk space is $free_readable"
    echo "Not enough space to continue setup. Installing BrewPi requires at least 512mb free space"
    echo "Did you forget to expand your root partition? To do so run 'sudo raspi-config', expand your root partition and reboot"
else
    echo "Disk usage is $free_percentage, free disk space is $free_readable. Enough to install BrewPi"
fi


echo "Any data in the following location will be ERASED during install!"
read -p "Where would you like to install BrewPi? [/home/brewpi]: " installPath
if [ -z "$installPath" ]; then
  installPath="/home/brewpi"
else
  case "$installPath" in
    y | Y | yes | YES| Yes )
        echo "$installPath is probably not a valid path. Press Enter to accept the default or type a valid path...";
        read -p "Where would you like to install BrewPi? [/home/brewpi]: " installPath;
        if [ -z "$installPath" ]; then
            installPath="/home/brewpi"
        fi;;
    * )
        echo "Installing script in $installPath";;
  esac
fi

if [ -d "$installPath" ]; then
  if [ "$(ls -A ${installPath})" ]; then
    read -p "Install directory is NOT empty, are you SURE you want to use this path? [y/N] " yn
    case "$yn" in
        y | Y | yes | YES| Yes ) echo "Ok, we warned you!";;
        * ) exit;;
    esac
  fi
else
  if [ "$installPath" != "/home/brewpi" ]; then
    read -p "This path does not exist, would you like to create it? [Y/n] " yn
    if [ -z "$yn" ]; then
      yn="y"
    fi
    case "$yn" in
        y | Y | yes | YES| Yes ) echo "Creating directory..."; sudo mkdir "$installPath";;
        * ) echo "Aborting..."; exit;;
    esac
  fi
fi


echo "Any data in the following location will be ERASED during install!"
read -p "What is the path to your web directory? [/var/www]: " webPath
if [ -z "$webPath" ]; then
  webPath="/var/www"
else
  case "$webPath" in
    y | Y | yes | YES| Yes )
        echo "$webPath is probably not a valid path. Press Enter to accept the default or type a valid path...";
        read -p "What is the path to your web directory? [/var/www]: " webPath
        if [ -z "$webPath" ]; then
            webPath="/var/www"
        fi;;
    * )
        echo "Installing web interface in $webPath";;
  esac
fi

if [ -d "$webPath" ]; then
  if [ "$(ls -A ${webPath})" ]; then
    read -p "Web directory is NOT empty, are you SURE you want to use this path? [y/N] " yn
    case "$yn" in
        y | Y | yes | YES| Yes ) echo "Ok, we warned you!";;
        * ) exit;;
    esac
  fi
else
  if [ "$webPath" != "/var/www" ]; then
    read -p "This path does not exist, would you like to create it? [Y/n] " yn
    if [ -z "$yn" ]; then
      yn="y"
    fi
    case "$yn" in
        y | Y | yes | YES| Yes ) echo "Creating directory..."; sudo mkdir "$webPath";;
        * ) echo "Aborting..."; exit;;
    esac
  fi
fi


############
### Install git if not found. Other dependencies are installed later by script in repo
############
if ! dpkg-query -W git > /dev/null; then
    echo "git not found, installing git..."
    sudo apt-get update
    sudo apt-get install -y git-core||die
fi


############
### Create/configure user accounts
############
echo -e "\n***** Creating and configuring user accounts... *****"
sudo chown -R www-data:www-data "$webPath"||die
if id -u brewpi >/dev/null 2>&1; then
  echo "User 'brewpi' already exists, skipping..."
else
  sudo useradd -G www-data,dialout brewpi||die
  echo -e "brewpi\nbrewpi\n" | sudo passwd brewpi||die
fi
# add pi user to brewpi and www-data group
sudo usermod -a -G www-data pi||die
sudo usermod -a -G brewpi pi||die

echo -e "\n***** Checking install directories *****"

if [ -d "$installPath" ]; then
  echo "$installPath already exists"
else
  sudo mkdir "$installPath"
fi

dirName=$(date +%F-%k:%M:%S)
if [ "$(ls -A ${installPath})" ]; then
  echo "Script install directory is NOT empty, backing up to this users home dir and then deleting contents..."
    if ! [ -a ~/brewpi-backup/ ]; then
      mkdir ~/brewpi-backup
    fi
    mkdir ~/brewpi-backup/"$dirName"
    sudo cp -R "$installPath" ~/brewpi-backup/"$dirName"/||die
    sudo rm -rf "$installPath"/*||die
    sudo find "$installPath"/ -name '.*' | sudo xargs rm -rf||die
fi

if [ -d "$webPath" ]; then
  echo "$webPath already exists"
else
  sudo mkdir "$webPath"
fi
if [ "$(ls -A ${webPath})" ]; then
  echo "Web directory is NOT empty, backing up to this users home dir and then deleting contents..."
  if ! [ -a ~/brewpi-backup/ ]; then
    mkdir ~/brewpi-backup
  fi
  if ! [ -a ~/brewpi-backup/"$dirName"/ ]; then
    mkdir ~/brewpi-backup/"$dirName"
  fi
  sudo cp -R "$webPath" ~/brewpi-backup/"$dirName"/||die
  sudo rm -rf "$webPath"/*||die
  sudo find "$webPath"/ -name '.*' | sudo xargs rm -rf||die
fi

sudo chown -R www-data:www-data "$webPath"||die
sudo chown -R brewpi:brewpi "$installPath"||die

############
### Set sticky bit! nom nom nom
############
sudo find "$installPath" -type d -exec chmod g+rwxs {} \;||die
sudo find "$webPath" -type d -exec chmod g+rwxs {} \;||die

############
### Clone BrewPi repositories
############
echo -e "\n***** Downloading most recent BrewPi codebase... *****"
sudo -u brewpi git clone https://github.com/BrewPi/brewpi-script "$installPath"||die
sudo -u www-data git clone https://github.com/BrewPi/brewpi-www "$webPath"||die

############
### Run installDependencies script from repo.
############
echo -e "\n***** Installing/fixing dependencies, with bash $installPath/installDependencies.sh *****"
echo "You can re-run this file after manually switching branches to update required dependencies."
if [ -a "$installPath"/installDependencies.sh ]; then
   sudo bash "$installPath"/installDependencies.sh
else
   echo "Could not find installDependencies.sh!"
fi

############
### Check for insecure SSH key
############
defaultKey="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLNC9E7YjW0Q9btd9aUoAg++/wa06LtBMc1eGPTdu29t89+4onZk1gPGzDYMagHnuBjgBFr4BsZHtng6uCRw8fIftgWrwXxB6ozhD9TM515U9piGsA6H2zlYTlNW99UXLZVUlQzw+OzALOyqeVxhi/FAJzAI9jPLGLpLITeMv8V580g1oPZskuMbnE+oIogdY2TO9e55BWYvaXcfUFQAjF+C02Oo0BFrnkmaNU8v3qBsfQmldsI60+ZaOSnZ0Hkla3b6AnclTYeSQHx5YqiLIFp0e8A1ACfy9vH0qtqq+MchCwDckWrNxzLApOrfwdF4CSMix5RKt9AF+6HOpuI8ZX root@raspberrypi"

if grep -q "$defaultKey" /etc/ssh/ssh_host_rsa_key.pub; then
  echo "Replacing default SSH keys. You will need to remove the previous key from known hosts on any clients that have previously connected to this rpi."
  if rm -f /etc/ssh/ssh_host_* && dpkg-reconfigure openssh-server; then
     echo "Default SSH keys replaced."
  else
    echo "ERROR - Unable to replace SSH key. You probably want to take the time to do this on your own."
  fi
fi

echo -e "\n* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
echo -e "Review the log above for any errors, otherwise, your initial environment install is complete!"
echo -e "Edit your $installPath/settings/config.cfg file if needed and then read http://docs.brewpi.com/getting-started/program-arduino.html for your next steps"
echo -e "\nYou are currently using the password 'brewpi' for the brewpi user. If you wish to change this, type 'sudo passwd brewpi' now, and follow the prompt"
echo -e "\nHappy Brewing!"



