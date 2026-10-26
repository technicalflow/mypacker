packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.0.0"
    }
  }
}

# ─── Variables ───────────────────────────────────────────────────────────────

variable "iso_url" {
  type    = string
  default = "/data/ISO/Linux/debian-13.6.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:65273beed27b2df543b68b65630ba525cfbad8df2b12035732b2dff87d6664e7"
}

# variable "ssh_username" {
#   type    = string
#   default = "vagrant"
# }

# variable "ssh_password" {
#   type      = string
#   default   = "vagrant"
#   sensitive = true
# }

variable "disk_size" {
  type    = string
  default = "16384M"
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 4096
}

variable "timeout" {
  type        = string
  default     = "30m"
  description = "Timeout for building the image"
}

# ─── Builder ─────────────────────────────────────────────────────────────────

source "qemu" "debian-13" {
  accelerator = "kvm"
  qemu_binary = "qemu-system-x86_64"
  qemuargs    = [
    ["-cpu", "host"],
    ["-machine", "q35,accel=kvm"]]

  vm_name      = "packer-debian-13"
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # DVD ISO: isolinux needs ~10s to initialise before the menu appears
  boot_wait = "5s"
  boot_command = [
    "<esc><esc><esc><esc><esc><esc><esc><esc><esc><esc><wait5>",
    "/install.amd/vmlinuz <wait> ",
    "initrd=/install.amd/initrd.gz <wait> ",
    "fb=false <wait> ",
    "auto-install/enable=true <wait> ",
    "cdrom-checker/start=false <wait> ",
    "debconf/priority=critical <wait> ", 
    "console-setup/ask_detect=false <wait> ",
    "debconf/frontend=noninteractive <wait> ",
    "net.ifnames=0 biosdevname=0 systemd.unified_cgroup_hierarchy=1 <wait> ",
    "preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/preseed.cfg <wait> ",
    "---<enter>",
  ]

  cpus      = var.cpus
  memory    = var.memory
  disk_size = var.disk_size

  disk_cache       = "writeback"
  disk_compression = false
  disk_image       = false
  disk_interface   = "virtio"
  format           = "qcow2"
  net_device       = "virtio-net"
  headless         = true
  http_directory   = "${path.root}"
  output_directory = "output-debian-13"

  communicator = "none"
  shutdown_timeout = var.timeout

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 6000
}

# ─── Build ───────────────────────────────────────────────────────────────────

build {
  name        = "debian-13"
  description = "Debian 13 (Trixie) Vagrant/libvirt base image"
  sources     = ["source.qemu.debian-13"]

  # Post-processor 1: Image cleanup and sysprep
  post-processor "shell-local" {
    inline = [
      "set -eu",
      "export _IMAGE=\"output-debian-13/packer-debian-13\"",
      "export IMAGEPATH=./debian13.qcow2",
      "export LIBGUESTFS_BACKEND=direct",
#      "sudo qemu-img convert -f qcow2 -O qcow2 \"$_IMAGE\" \"$_IMAGE.convert\" && sudo rm -rf \"$_IMAGE\"",
#      "sudo chmod a+r /boot/vmlinuz*",
      "sudo LIBGUESTFS_BACKEND=direct virt-sysprep --operations defaults,machine-id,-ssh-userdir,-customize -a \"$_IMAGE\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-customize --no-network -a \"$_IMAGE\" --delete \"/var/lib/*/random-seed\" --touch \"/var/log/lastlog\" --firstboot-command \"ssh-keygen -A && systemctl reset-failed ssh.service && systemctl restart ssh.service\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-sparsify --in-place \"$_IMAGE\"",
      "sudo qemu-img convert -f qcow2 -O qcow2 -c \"$_IMAGE\" \"$_IMAGE.final\"",
      "sudo mv -f \"$_IMAGE.final\" \"$IMAGEPATH\"",
      "sudo chmod 755 \"$IMAGEPATH\""
    ]
  }
}
