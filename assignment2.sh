#!/bin/bash

# Function to print messages
print_message() {
    echo "$1"
}

# Function to update network configuration using netplan
configure_network() {
    print_message "Configuring network..."

    # Path to the Netplan configuration file
    local netplan_config="/etc/netplan/01-network-manager-all.yaml"

    # Check if the network configuration file exists
    if [ -f "$netplan_config" ]; then
        # Modify the netplan configuration
        cat << EOF | sudo tee "$netplan_config"
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses: [192.168.16.21/24]
      gateway4: 192.168.16.1
      nameservers:
        addresses: [192.168.16.1]
        search: [home.arpa, localdomain]
EOF
        # Apply netplan changes
        sudo netplan apply
    else
        print_message "Error: Netplan configuration file not found!"
    fi
}

# Function to install required software and configure the firewall
install_software() {
    print_message "Installing software and configuring firewall..."

    # Update package repository and install required software
    sudo apt update
    sudo apt install -y openssh-server apache2 squid

    # Configure SSH, Apache, and Squid
    configure_ssh
    configure_apache
    configure_squid

    # Configure UFW (Uncomplicated Firewall)
    sudo ufw enable
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 3128/tcp
}

configure_ssh() {
    # Configure SSH to allow key authentication and disable password authentication
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
}

configure_apache() {
    # Configure Apache to listen on ports 80 and 443
    sudo sed -i 's/Listen 80/Listen 192.168.16.21:80/' /etc/apache2/ports.conf
    sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost 192.168.16.21:80>/' /etc/apache2/sites-available/000-default.conf
    sudo sed -i 's/Listen 443/Listen 192.168.16.21:443/' /etc/apache2/ports.conf
    sudo sed -i 's/<VirtualHost default:443>/<VirtualHost 192.168.16.21:443>/' /etc/apache2/sites-available/default-ssl.conf
    sudo systemctl restart apache2
}

configure_squid() {
    # Configure Squid web proxy to listen on a specific IP and port
    sudo sed -i 's/http_port 3128/http_port 192.168.16.21:3128/' /etc/squid/squid.conf
    sudo systemctl restart squid
}

# Function to create user accounts with SSH keys and sudo access
create_users() {
    print_message "Creating user accounts..."

    # Array of users to create
    local users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

    for user in "${users[@]}"; do
        # Create user and configure SSH keys
        sudo useradd -m -s /bin/bash "$user"
        sudo mkdir -p /home/$user/.ssh
        sudo touch /home/$user/.ssh/authorized_keys
        sudo chown -R $user:$user /home/$user/.ssh

        # Add SSH public keys for users (example key for 'dennis')
        if [ "$user" = "dennis" ]; then
            echo "ssh-ed25519 AAAAC3...generic-vm" | sudo tee -a /home/$user/.ssh/authorized_keys
        else
            # Add other public keys here
            echo "ssh-rsa AAAAB3...userkey" | sudo tee -a /home/$user/.ssh/authorized_keys
        fi
    done

    # Grant sudo access to 'dennis'
    sudo usermod -aG sudo dennis
}

# Main function to execute the script
main() {
    configure_network
    install_software
    create_users
    print_message "Script execution completed successfully!"
}

# Execute the main function
main
