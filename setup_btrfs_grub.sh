#!/bin/bash
set -e

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  printf "\033[1;33mPlease run as root.\033[0m\n"
  exit
fi

printf "\033[1;33mStarting the setup process...\033[0m\n"

# Install Btrfs-Assistant/snapper
printf "\033[1;33mInstalling btrfs-assistant/snapper and dependencies...\033[0m\n"
dnf install -y btrfs-assistant make inotify-tools python3-dnf-plugin-snapper git

# Create first snapper root config and create a new manual snapshot
printf "\033[1;33mCreating snapper root config and taking the first root snapshot...\033[0m\n"
snapper -c root create-config / && snapper -c root create --description "Manual Snapshot"

# Install grub-btrfs from GitHub
printf "\033[1;33mInstalling grub-btrfs...\033[0m\n"
git clone https://github.com/Antynea/grub-btrfs
cd grub-btrfs

# Modify grub-btrfs config for Fedora before installing
printf "\033[1;33mModifying grub-btrfs configuration for Fedora...\033[0m\n"
sed -i '/#GRUB_BTRFS_SNAPSHOT_KERNEL/a GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="systemd.volatile=state"' config
sed -i '/#GRUB_BTRFS_GRUB_DIRNAME/a GRUB_BTRFS_GRUB_DIRNAME="/boot/grub2"' config
sed -i '/#GRUB_BTRFS_MKCONFIG=/a GRUB_BTRFS_MKCONFIG=/sbin/grub2-mkconfig' config
sed -i '/#GRUB_BTRFS_SCRIPT_CHECK=/a GRUB_BTRFS_SCRIPT_CHECK=grub2-script-check' config

# Install grub-btrfs
printf "\033[1;33mInstalling grub-btrfs...\033[0m\n"
make install

# Update grub.cfg and enable grub-btrfsd service
printf "\033[1;33mUpdating grub configuration and enabling grub-btrfsd service...\033[0m\n"
grub2-mkconfig -o /boot/grub2/grub.cfg && systemctl enable --now grub-btrfsd.service

# Clean up
printf "\033[1;33mCleaning up installation files...\033[0m\n"
cd ..
rm -rf grub-btrfs

# Updating timeline limits
printf "\033[1;33mUpdating timeline limits...\033[0m\n"
sed -i 's/^TIMELINE_LIMIT_HOURLY="[^"]*"/TIMELINE_LIMIT_HOURLY="1"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_DAILY="[^"]*"/TIMELINE_LIMIT_DAILY="2"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_WEEKLY="[^"]*"/TIMELINE_LIMIT_WEEKLY="1"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_MONTHLY="[^"]*"/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_YEARLY="[^"]*"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

# Starting snapper-timeline.timer service
printf "\033[1;33mStarting snapper-timeline.timer service...\033[0m\n"
systemctl start snapper-timeline.timer && systemctl enable snapper-timeline.timer

# Starting snapper-cleanup.timer service
printf "\033[1;33mStarting snapper-timeline.cleanup service...\033[0m\n"
systemctl start snapper-cleanup.timer && systemctl enable snapper-cleanup.timer

# Restart grub-btrfsd service
printf "\033[1;33mRestarting grub-btrfsd service...\033[0m\n"
systemctl restart grub-btrfsd

printf "\033[1;33mSetup complete. Grub-btrfs and automatic snapshot configuration is now active.\033[0m\n"
printf "\033[1;33mHint: You can manage snapshots from the GUI with Btrfs Assistant.\033[0m\n"
