#!/bin/bash
set -e

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

echo "Starting the setup process..."

# Install Btrfs-Assistant/snapper and take the first root snapshot
echo "Installing btrfs-assistant/snapper and dependencies and taking the first root snapshot..."
dnf install -y btrfs-assistant
dnf install -y make
dnf install -y inotify-tools
dnf install -y python3-dnf-plugin-snapper
snapper -c root create-config /
snapper -c root create --description "Manual Snapshot"

# Install grub-btrfs from GitHub
echo "Installing grub-btrfs..."
git clone https://github.com/Antynea/grub-btrfs
cd grub-btrfs

# Modify grub-btrfs config for Fedora
echo "Modifying grub-btrfs configuration for Fedora..."
sed -i '/#GRUB_BTRFS_SNAPSHOT_KERNEL/a GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="systemd.volatile=state"' config
sed -i '/#GRUB_BTRFS_GRUB_DIRNAME/a GRUB_BTRFS_GRUB_DIRNAME="/boot/grub2"' config
sed -i '/#GRUB_BTRFS_MKCONFIG=/a GRUB_BTRFS_MKCONFIG=/sbin/grub2-mkconfig' config
sed -i '/#GRUB_BTRFS_SCRIPT_CHECK=/a GRUB_BTRFS_SCRIPT_CHECK=grub2-script-check' config

# Install grub-btrfs
echo "Installing grub-btrfs..."
sudo make install

# Update grub.cfg and enable grub-btrfsd service
echo "Updating grub configuration and enabling grub-btrfsd service..."
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo systemctl enable --now grub-btrfsd.service

# Clean up
echo "Cleaning up installation files..."
cd ..
rm -rf grub-btrfs

# Set up automatic Grub update after snapshot creation
echo "Setting up automatic grub update after snapshots..."
mkdir -p /etc/snapper/hooks

# Create update-grub.sh script
cat <<EOL > /etc/snapper/hooks/update-grub.sh
#!/bin/bash
if [[ "\$1" == "post" ]]; then
  echo "Running grub-mkconfig due to snapshot creation"
  sudo grub-mkconfig -o /boot/grub2/grub.cfg
fi
EOL

chmod +x /etc/snapper/hooks/update-grub.sh

# Add hooks to snapper config
echo "Adding snapper hook configuration..."
echo 'HOOKS="/etc/snapper/hooks/update-grub.sh"' >> /etc/snapper/configs/root

# Restart grub-btrfsd service
echo "Restarting grub-btrfsd service..."
sudo systemctl restart grub-btrfsd

echo "Setup complete. Grub-btrfs and automatic snapshot configuration is now active."
