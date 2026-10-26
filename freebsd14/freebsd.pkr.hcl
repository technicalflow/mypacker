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
  default     = "/data/ISO/Unix/FreeBSD-14.0-RELEASE-amd64-disc1.iso"
  description = "Path or URL to FreeBSD 14 installation ISO"
}

variable "iso_checksum" {
  type        = string
  default     = "sha256:7200214030125877561e70718781b435b703180c12575966ad1c7584a3e60dc6"
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
}

# ─── Builder ─────────────────────────────────────────────────────────────────

source "qemu" "freebsd-14" {
  accelerator = "kvm"
  qemu_binary = "qemu-system-x86_64"
  qemuargs    = [
    ["-cpu", "host"],
    ["-machine", "q35,accel=kvm"]
  ]

  vm_name      = "packer-freebsd-14"
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
  output_directory = "output-freebsd-14"

  communicator     = "none"
  shutdown_timeout = var.timeout

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 6000
}

# ─── Build ───────────────────────────────────────────────────────────────────

build {
  name        = "freebsd-14"
  description = "FreeBSD 14.0 libvirt base image"
  sources     = ["source.qemu.freebsd-14"]

  # Post-processor: Image compression and final placement
  post-processor "shell-local" {
    inline = [
      "set -eu",
      "export _IMAGE=\"output-freebsd-14/packer-freebsd-14\"",
      "export IMAGEPATH=./freebsd14.qcow2",
      "sudo qemu-img convert -f qcow2 -O qcow2 -c \"$_IMAGE\" \"$IMAGEPATH\"",
      "sudo rm -rf output-freebsd-14",
      "sudo chmod 755 \"$IMAGEPATH\""
    ]
  }
}
