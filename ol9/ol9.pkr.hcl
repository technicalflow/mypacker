packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

# ─── Variables ───────────────────────────────────────────────────────────────
variable "iso_url" {
  type    = string
  default = "/data/ISO/Linux/OracleLinux-R9-U8-x86_64-dvd.iso"
}

variable "iso_checksum" {
  type    = string
  default = "91bb95cb8e4d1ad1c496c9a87efcba3bf9d5ec976474910e9950a3fa8576428b"
}

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

source "qemu" "ol9" {
  accelerator = "kvm"
  qemu_binary = "qemu-system-x86_64"
  qemuargs = [
    ["-cpu", "host"],
    ["-machine", "q35,accel=kvm"],
    ["-serial", "stdio"]
  ]
  efi_boot          = true
  efi_firmware_code = var.ovmf_code
  efi_firmware_vars = var.ovmf_vars
  vm_name      = "packer-ol9"

  iso_url          = var.iso_url
  iso_checksum     = "sha256:${var.iso_checksum}"

  # ── Boot command ───────────────────────────────────────────────────────────
  # UEFI GRUB presents a graphical menu. We press 'e' to edit the first entry,
  # navigate to the end of the linux line, append kernel parameters, then
  # Ctrl-X to boot.
  # boot_command     = ["<up><tab> ", "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg ", "console=ttyS0 inst.cmdline", "<enter>"]

  boot_command = [
    "<wait5>c<wait>",
    "linux /images/pxeboot/vmlinuz ",
    "inst.stage2=cdrom quiet text <wait> ",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg <wait> ",
    "console=ttyS0 inst.cmdline ",
    "<enter><wait>",
    "initrd /images/pxeboot/initrd.img<enter><wait>",
    "boot<enter>",
  ]

  boot_wait        = "3s"

  disk_size        = var.disk_size
  memory           = var.memory
  cpus             = var.cpus

  disk_cache       = "writeback"
  disk_compression = false
  disk_image       = false
  disk_interface   = "virtio"
  format           = "qcow2"
  net_device       = "virtio-net"
  headless         = true
  http_directory  = "${path.root}"
  output_directory = "output-ol9"

  communicator     = "none"
  shutdown_timeout = "30m"

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 6000
}
# ─── Build ───────────────────────────────────────────────────────────────────

build {
  name = "ol9"
  sources = ["source.qemu.ol9"]

  # Post-processor 1: Image cleanup and sysprep
  post-processor "shell-local" {
    inline = [
      "set -eu",
      "export _IMAGE=\"output-ol9/packer-ol9\"",
      "export LIBGUESTFS_BACKEND=direct",
      "sudo LIBGUESTFS_BACKEND=direct virt-sysprep --operations defaults,machine-id,-ssh-userdir,-customize -a \"$_IMAGE\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-customize --no-network -a \"$_IMAGE\" --delete \"/var/lib/*/random-seed\" --firstboot-command \"/usr/local/bin/virt-sysprep-firstboot.sh\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-sparsify --in-place \"$_IMAGE\"",
      "sudo qemu-img convert -f qcow2 -O qcow2 -c \"$_IMAGE\" \"$_IMAGE.final\"",
      "sudo rm -rf \"$_IMAGE\"",
    ]
  }
}
