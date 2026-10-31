packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
  }
}

# ─── Variables ───────────────────────────────────────────────────────────────

variable "iso_url" {
  type    = string
  default = "/data/ISO/Networking/vyos-2026.03-generic-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "none" # e.g. "sha256:<hash>"
}

variable "vyos_user" {
  type      = string
  default   = "vyos"
}

variable "vyos_password" {
  type      = string
  default   = "vyos"
  sensitive = true
}

variable "disk_size" {
  type    = string
  default = "8G"
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 1024
}

variable "timeout" {
  type        = string
  default     = "30m"
  description = "Timeout for building the image"
}

# ─── Builder ─────────────────────────────────────────────────────────────────

source "qemu" "vyos" {
  accelerator  = "kvm"
  machine_type = "q35"
  qemu_binary  = "qemu-system-x86_64"
  qemuargs     = [["-cpu", "host"]]

  vm_name      = "packer-vyos"
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  cpus      = var.cpus
  memory    = var.memory
  disk_size = var.disk_size

  disk_cache       = "writeback"
  disk_compression = false
  disk_image       = false
  disk_interface   = "virtio"
  disk_discard       = "unmap" # lets fstrim shrink the qcow2
  disk_detect_zeroes = "unmap"
  format           = "qcow2"
  net_device       = "virtio-net"
  headless         = true
  vnc_bind_address = "127.0.0.1"
  output_directory = "output-vyos"
  boot_key_interval      = "20ms"
  boot_keygroup_interval = "20ms"

# ─── Boot ───────────────────────────────────────────────────────────────────
  boot_wait = "35s"
  boot_command = [
    # --- Live ISO: log in ---
    "vyos<enter><wait3s>",
    "vyos<enter><wait5s>",

    # --- Install to disk ---
    "install image<enter><wait3s>",
    "y<enter><wait3s>",                         # Would you like to continue? [y/N]
    "vyos<enter><wait3s>",                      # Image name (default)
    "${var.vyos_password}<enter><wait3s>",      # Password for vyos user
    "${var.vyos_password}<enter><wait3s>",      # Confirm password
    "<enter><wait3s>",                          # Default console (K/S) -> default
    "<enter><wait3s>",                          # Disk to install to (default /dev/vda)
    "y<enter><wait3s>",                         # Delete all data on the drive? [y/N]
    "y<enter><wait3s>",                         # Use all free space? [Y/n]
    "<enter><wait30s>",                         # Config file to copy (default)
    "sudo reboot<enter><wait50s>",

    # --- Installed system: log in ---
    "${var.vyos_user}<enter><wait3s>",
    "${var.vyos_password}<enter><wait5s>",
    "unset HISTFILE<enter><wait1s>",

    # --- Configuration ---
    "configure<enter><wait2s>",
    "set interfaces ethernet eth0 address dhcp<enter><wait1s>",
    "set system name-server 1.1.1.1<enter><wait1s>",
    "set service ssh<enter><wait1s>",
    "delete interfaces ethernet eth0 hw-id<enter><wait1s>",
    "commit<enter><wait5s>",
    "save<enter><wait3s>",
    "exit<enter><wait20s>",

    "renew dhcp interface eth0<enter><wait10s>",
    "wget -q -O /tmp/liburing2.deb http://ftp.pl.debian.org/debian/pool/main/libu/liburing/liburing2_2.3-3_amd64.deb <enter><wait5s>",
    "wget -q -O /tmp/qemu-guest-agent.deb http://ftp.pl.debian.org/debian/pool/main/q/qemu/qemu-guest-agent_7.2+dfsg-7+deb12u18+b3_amd64.deb <enter><wait10s>",
    "sudo dpkg -i /tmp/liburing2.deb /tmp/qemu-guest-agent.deb <enter><wait20s>",
    "sudo systemctl enable qemu-guest-agent.service<enter><wait10s>",
    "sudo rm -rf /tmp/liburing2.deb /tmp/qemu-guest-agent.deb<enter><wait1s>",

    "sudo sh -c 'rm -f /etc/ssh/ssh_host_* /var/lib/dhcp/*.leases /home/vyos/.bash_history /root/.bash_history'<enter><wait2s>",
    "sudo truncate -s 0 /etc/machine-id<enter><wait1s>",
    "sudo journalctl --rotate<enter><wait2s>",
    "sudo journalctl --vacuum-time=1s<enter><wait3s>",
    "sudo fstrim -av<enter><wait5s>",
    "sudo poweroff<enter>",
  ]

  # No SSH: everything is typed via boot_command, Packer just waits for the VM to power off
  communicator     = "none"
  shutdown_timeout = var.timeout
}

# ─── Build ───────────────────────────────────────────────────────────────────

build {
  name    = "vyos"
  sources = ["source.qemu.vyos"]

  post-processor "shell-local" {
      inline = [
        "set -eu",
        "export IMAGE=\"./output-vyos/packer-vyos\"",
        "export IMAGEFINAL=/data/ISO/VMIMAGES/KVM/vyos2026.qcow2",
        "sudo LIBGUESTFS_BACKEND=direct virt-sparsify --in-place \"$IMAGE\"",
        "sudo qemu-img convert -f qcow2 -O qcow2 -c \"$IMAGE\"  \"$IMAGEFINAL\"",
        "sudo rm -rf \"$IMAGE\"",
        "sudo chmod 755 \"$IMAGEFINAL\""
      ]
    }

}

