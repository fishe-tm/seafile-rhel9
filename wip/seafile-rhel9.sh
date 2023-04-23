#!/bin/bash

###
### install Seafile on Rocky Linux 9 via docker compose
###

run_check() {
    if [ ! -f ~/sfscript_check_run ]; then FIRST_RUN="true"; else FIRST_RUN="false"; fi
}

first_run() {
    echo "Installing and configuring Docker..." && sleep 1
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl enable --now docker 
    sudo usermod -aG docker $(whoami)
    touch ~/sfscript_check_run
    echo "\n\n System will reboot in 10 seconds for group changes to take effect. Terminate (Ctrl + C) to stop this.\n Run the script again to continue with configuration"
    sudo reboot
}

second_run() {
    sudo mkdir /srv/www/seafile && sudo chown -R $(whoami) /srv/www/seafile
    cd /srv/www/seafile && curl -fLO https://download.seafile.com/seafhttp/files/0e1dcbfb-d4a0-49e2-9c14-dc954389053b/docker-compose.yml
    docker compose up -d
    docker compose down
    clear; sudo blkid
    echo "\n\nPlease copy the UUID of the drive you'd like to use for Seafile data and paste it here, without quotes"
    read -p "Enter here: " uuid
    echo "\nNice! Now pick a place for the drive to be mounted (something like /mnt/seafile, DO NOT ADD trailing /)"
    read -p "Enter here: " drive_loc

    filesystem=$(lsblk -f /dev/disk/by-uuid/$uuid)
    filesystem=${filesystem#*$'\n'}
    filesystem=$(echo "$filesystem" | awk  '{print $2}')

    echo "UUID=$uuid $drive_loc $filesystem  defaults  0 0" | sudo tee -a /etc/fstab
    sudo systemctl daemon-reload
    sudo mount -a

    sudo chown -R $(whoami) $drive_loc
    sudo cp -r /opt/seafile-data /opt/seafile-data_bak
    sudo cp -r /opt/seafile-data $drive_loc/
    sudo rm -rf /opt/seafile-data
    sed -i "s%- /opt/seafile-data:/shared%- $drive_loc/seafile-data:/shared%g" /srv/www/seafile/docker_compose.yml
    docker compose up -d
    
    echo "\nYou will now create an admin user. Delete the default one after logging in at System Admin -> Users."
    docker exec -it seafile /opt/seafile/seafile-server-latest/reset-admin.sh
}

tailscale() {
    echo "Installing tailscale, be ready to connect it to your tailnet" && sleep 2
    sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/9/tailscale.repo
    sudo dnf install -y tailscale
    sudo systemctl enable --now tailscaled
    sudo tailscale up
}

main() {
    if [ "$FIRSTRUN" == "true" ]; then first_run; else second_run; fi

    rm ~/sfscript_check_run
    read -p "Install and configure Tailscale? (Y/n)" tailscaler
    if [ "${tailscaler,,}" == "y" ]; then tailscale; else echo "Ok, skipped."; fi

    echo "\nDone!"
    echo "Seafile .yml file is at: /srv/www/seafile"
    echo "Seafile data drive is mounted at: $MOUNT_LOC"
}
