#!/bin/bash

# Define variables for target machines
TARGET1="remoteadmin@172.16.1.10"
TARGET2="remoteadmin@172.16.1.11"

# Function to execute commands on remote machines
execute_remote_command() {
    ssh "$1" "$2"
}

# Function to perform host configurations
configure_host() {
    local target=$1
    local hostname=$2
    local old_ip=$3
    local new_ip=$4

    execute_remote_command "$target" "sudo hostnamectl set-hostname $hostname"
    execute_remote_command "$target" "sudo sed -i 's/$old_ip\t$hostname/$new_ip\t$hostname/' /etc/hosts"
}

# Target 1 configuration
configure_host "$TARGET1" "loghost" "172.16.1.10" "172.16.1.3"
configure_host "$TARGET1" "webhost" "172.16.1.10" "172.16.1.4"
execute_remote_command "$TARGET1" "sudo apt-get update && sudo apt-get install -y ufw"
execute_remote_command "$TARGET1" "sudo ufw allow from 172.16.1.0/24 to any port 514 proto udp"
execute_remote_command "$TARGET1" "sudo sed -i '/imudp/s/^#//' /etc/rsyslog.conf && sudo systemctl restart rsyslog"

# Target 2 configuration
configure_host "$TARGET2" "webhost" "172.16.1.11" "172.16.1.4"
configure_host "$TARGET2" "loghost" "172.16.1.11" "172.16.1.3"
execute_remote_command "$TARGET2" "sudo apt-get update && sudo apt-get install -y ufw apache2"
execute_remote_command "$TARGET2" "sudo ufw allow 80/tcp"
execute_remote_command "$TARGET2" "echo '*.* @loghost' | sudo tee -a /etc/rsyslog.conf"
execute_remote_command "$TARGET2" "sudo systemctl restart rsyslog"

# Update NMS hosts file
echo -e "172.16.1.3\tloghost\n172.16.1.4\twebhost" | sudo tee -a /etc/hosts >/dev/null

# Check configurations
if execute_remote_command "$TARGET1" "curl -Is http://webhost &>/dev/null"; then
    if execute_remote_command "$TARGET1" "ssh remoteadmin@loghost grep webhost /var/log/syslog &>/dev/null"; then
        echo "Configuration update succeeded."
    else
        echo "Failed to retrieve logs from loghost for webhost."
    fi
else
    echo "Failed to retrieve default Apache page from webhost."
fi
