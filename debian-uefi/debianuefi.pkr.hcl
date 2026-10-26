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
  # default = "http://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-live-server-amd64.iso"
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

# Path to OVMF firmware files (adjust to match your distro's package location).
# Fedora/RHEL:  /usr/share/edk2/x64/OVMF_CODE.fd  /usr/share/edk2/x64/OVMF_VARS.fd
# Debian/Ubuntu: /usr/share/OVMF/OVMF_CODE_4M.fd   /usr/share/OVMF/OVMF_VARS_4M.fd
variable "ovmf_code" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
}

variable "ovmf_vars" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_VARS.fd"
}

# ─── Builder ─────────────────────────────────────────────────────────────────

source "qemu" "debian13-uefi" {
  accelerator = "kvm"
  qemu_binary = "qemu-system-x86_64"

  # ── UEFI firmware ──────────────────────────────────────────────────────────
  # OVMF_CODE is opened read-only; OVMF_VARS is copied to a temp file by
  # QEMU so each build starts with a clean NVRAM state.
  qemuargs = [
    ["-cpu", "host"],
    ["-machine", "q35,accel=kvm"],
    ["-global", "driver=cfi.pflash01,property=secure,value=off"],
  ]
  efi_boot          = true
  efi_firmware_code = var.ovmf_code
  efi_firmware_vars = var.ovmf_vars

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # ── Boot command ───────────────────────────────────────────────────────────
  # UEFI GRUB presents a graphical menu. We press 'e' to edit the first entry,
  # navigate to the end of the linux line, append kernel parameters, then
  # Ctrl-X to boot.
  boot_wait = "5s"
#  boot_command     = ["<wait>e<wait5>", "<down><wait><down><wait><down><wait2><end><wait5>", "<bs><bs><bs><bs><wait> autoinstall ds=\"nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\" ---<wait><f10>"]

  boot_command = [
    "<wait3>c<wait3>",
    "linux /install.amd/vmlinuz auto=true priority=critical preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg netcfg/disable_autoconfig=false ---<enter><wait3>",
    "initrd /install.amd/initrd.gz<enter><wait3>",
    "boot<enter>"
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
  http_directory   = "."
  output_directory = "output-debian13-uefi"

  communicator = "none"
  shutdown_timeout = "30m"

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 6000
}

# ─── Build ───────────────────────────────────────────────────────────────────

build {
  name    = "debian13-uefi"
  sources = ["source.qemu.debian13-uefi"]

  # Post-processor 1: Image cleanup and sysprep
  post-processor "shell-local" {
    inline = [
      "set -eu",
      "export _IMAGE=\"output-debian13-uefi/packer-debian13-uefi\"",
      "export IMAGEPATH=./debian13.qcow2",
      "export LIBGUESTFS_BACKEND=direct",
      "sudo LIBGUESTFS_BACKEND=direct virt-sysprep --operations defaults,machine-id,-ssh-userdir,-customize -a \"$_IMAGE\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-customize --no-network -a \"$_IMAGE\" --delete \"/var/lib/*/random-seed\" --touch \"/var/log/lastlog\" --firstboot-command \"ssh-keygen -A && systemctl reset-failed ssh.service && systemctl restart ssh.service\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-sparsify --in-place \"$_IMAGE\"",
      "sudo qemu-img convert -f qcow2 -O qcow2 -c \"$_IMAGE\" \"$_IMAGE.final\"",
      "sudo mv -f \"$_IMAGE.final\" \"$IMAGEPATH\""
    ]
  }
}
