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
  # default = "https://ftp.osuosl.org/pub/centos-stream/10-stream/BaseOS/x86_64/iso/CentOS-Stream-10-latest-x86_64-boot.iso"
  default = "/data/ISO/Linux/CentOS-Stream-10-latest-x86_64-boot.iso"
}

variable "iso_checksum" {
  type    = string
  default = "a3ae0bb3bbac8c07b42d2d1093504ec233fc998246580bc15ecbbb415a3dc3d6"
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

source "qemu" "centos-10" {
  accelerator = "kvm"
  qemu_binary = "qemu-system-x86_64"
  qemuargs    = [["-cpu", "host"], ["-machine", "q35,accel=kvm"]]

  vm_name      = "packer-centos-10"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  boot_wait = "3s"
  boot_command = [
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "c<wait>",
    "set gfxpayload=keep<enter><wait>",
    "linux /images/pxeboot/vmlinuz <wait>",
    "inst.stage2=cdrom quiet text <wait>",
    "net.ifnames=0 biosdevname=0 systemd.unified_cgroup_hierarchy=1 <wait>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg <wait>",
    "---<enter><wait>",
    "initrd /images/pxeboot/initrd.img<enter><wait>",
    "boot<enter>",
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
  output_directory = "output-centos-10"

  communicator = "none"
  shutdown_timeout = var.timeout

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 6000
}

# ─── Build ───────────────────────────────────────────────────────────────────

build {
  name        = "centos-10"
  description = "CentOS Stream 10 Vagrant/libvirt base image"
  sources     = ["source.qemu.centos-10"]

  # Post-processor 1: Image cleanup and sysprep
  post-processor "shell-local" {
    inline = [
      "set -eu",
      "export _IMAGE=\"output-centos-10/packer-centos-10\"",
      "export LIBGUESTFS_BACKEND=direct",
      "sudo LIBGUESTFS_BACKEND=direct virt-sysprep --operations defaults,machine-id,-ssh-userdir,-customize -a \"$_IMAGE\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-customize --no-network -a \"$_IMAGE\" --delete \"/var/lib/*/random-seed\" --firstboot-command \"/usr/local/bin/virt-sysprep-firstboot.sh\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-sparsify --in-place \"$_IMAGE\"",
      "sudo qemu-img convert -f qcow2 -O qcow2 -c \"$_IMAGE\" \"$_IMAGE.final\"",
      "sudo rm -rf \"$_IMAGE\"",
    ]
  }
}
