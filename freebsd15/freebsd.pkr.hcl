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
  type        = string
  default     = "/data/ISO/Unix/FreeBSD-15.0-RELEASE-amd64-disc1.iso"
  description = "Path or URL to FreeBSD 15 installation ISO"
}

variable "iso_checksum" {
  type        = string
  default     = "sha256:cc73a14d4b1cfada880b78deb0b94ae0f439167418c32a6708f68f79563cb50c"
  description = "SHA256 checksum for the installation ISO"
}

variable "disk_size" {
  type        = string
  default     = "32768M"
  description = "Size of the VM virtual disk"
}

variable "cpus" {
  type        = number
  default     = 4
  description = "Number of vCPUs"
}

variable "memory" {
  type        = number
  default     = 2048
  description = "Amount of RAM in MB"
}

variable "timeout" {
  type        = string
  default     = "30m"
  description = "Timeout for building the image"

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
}

# ─── Builder ─────────────────────────────────────────────────────────────────

source "qemu" "freebsd-15" {
  accelerator  = "kvm"
  qemu_binary  = "qemu-system-x86_64"
#  machine_type = "q35"
  qemuargs = [
    ["-cpu", "host"],
    ["-machine", "q35,accel=kvm"],
    ["-global", "driver=cfi.pflash01,property=secure,value=off"],
  ]

  # UEFI / OVMF configuration
  efi_boot          = true
  efi_firmware_code = var.ovmf_code
  efi_firmware_vars = var.ovmf_vars
  efi_drop_efivars  = true

  vm_name      = "packer-freebsd-15"
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  boot_wait = "10s"
  boot_command = [
    "<esc><wait>",
    "boot -s<enter>",
    "<wait15s>",
    "/bin/sh<enter><wait>",
    "mdmfs -s 100m md /tmp<enter><wait>",
    "dhclient -l /tmp/dhclient.lease.vtnet0 vtnet0<enter><wait5>",
    "fetch -o /tmp/installerconfig http://{{ .HTTPIP }}:{{ .HTTPPort }}/installerconfig<enter><wait5>",
    "bsdinstall script /tmp/installerconfig<enter>"
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
  output_directory = "output-freebsd-15"

  communicator     = "none"
  shutdown_timeout = var.timeout

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 6000
}

# ─── Build ───────────────────────────────────────────────────────────────────

build {
  name        = "freebsd-15"
  description = "FreeBSD 15.0 libvirt UEFI base image"
  sources     = ["source.qemu.freebsd-15"]

  # Post-processor: Image compression and final placement
  post-processor "shell-local" {
    inline = [
      "set -eu",
      "export _IMAGE=\"output-freebsd-15/packer-freebsd-15\"",
      "export IMAGEPATH=./freebsd15.qcow2",
      "sudo qemu-img convert -f qcow2 -O qcow2 -c \"$_IMAGE\" \"$IMAGEPATH\"",
      "sudo rm -rf output-freebsd-15",
      "sudo chmod 755 \"$IMAGEPATH\""
    ]
  }
}
