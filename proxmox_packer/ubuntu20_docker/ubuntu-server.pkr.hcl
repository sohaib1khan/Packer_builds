variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

source "proxmox" "ubuntu-server-focal" {
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    insecure_skip_tls_verify = true

    # VM General Settings
    node = "pve"  # Add your Proxmox node
    vm_id = "252"
    vm_name = "ubuntu-server-focal-docker"
    template_description = "Ubuntu Server Focal"

    # VM OS Settings
    iso_url = "https://releases.ubuntu.com/20.04/ubuntu-20.04.6-live-server-amd64.iso"
    iso_checksum = "sha256:b8f31413336b9393ad5d8ef0282717b2ab19f007df2e9ed5196c13d8f9153c8b"
    iso_storage_pool = "local"
    unmount_iso = true

    # VM System Settings
    qemu_agent = true  # Enable QEMU agent

    # VM Hard Disk Settings
    scsi_controller = "virtio-scsi-pci"

    disks {
        disk_size = "20G"
        format = "raw"
        storage_pool = "local-lvm"
        type = "virtio"
    }

    # VM CPU Settings
    cores = "2"
    
    # VM Memory Settings
    memory = "6048" 

    # VM Network Settings
    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "false"
    } 

    # VM Cloud-Init Settings
    cloud_init = false
    cloud_init_storage_pool = "local-lvm"

    # PACKER Boot Commands
    boot_command = [
        "<esc><wait><esc><wait>",
        "<f6><wait><esc><wait>",
        "<bs><bs><bs><bs><bs>",
        "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ",
        "--- <enter>"
    ]
    boot = "c"
    boot_wait = "5s"

    # PACKER Autoinstall Settings
    http_directory = "http"
    ssh_username = "USERNAME"  # Use the same username from your cloud-init configuration
    # ssh_timeout = "5m"  # Optional: Increase the SSH timeout if needed
}

# Build Definition to create the VM Template
build {
    name = "ubuntu-server-focal-docker"
    sources = ["source.proxmox.ubuntu-server-focal"]

    # Install the QEMU agent inside the VM
    provisioner "shell" {
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y qemu-guest-agent",  # Install QEMU guest agent
            "sudo systemctl enable qemu-guest-agent",
            "sudo systemctl start qemu-guest-agent"
        ]
    }

    # Enable SSH password authentication
    provisioner "shell" {
        inline = [
            "echo 'skhan:yourpassword' | sudo chpasswd",  # Set the password for the user
            "sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config",  # Enable password authentication
            "sudo systemctl restart ssh",  # Restart SSH to apply changes
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo sync"
        ]
    }

    # Docker installation
    provisioner "shell" {
        inline = [
            "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
            "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
            "sudo apt-get -y update",
            "sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
        ]
    }
}
