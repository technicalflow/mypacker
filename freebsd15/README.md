# FreeBSD 15 Universal Golden Template for Red Hat Libvirt Host (UEFI)

This template builds a generalized, clone-ready FreeBSD 15.0 UEFI qcow2 image suitable for deployment on Red Hat libvirt / KVM hosts.

## Files

- `freebsd.pkr.hcl`: Packer HCL2 configuration using the QEMU builder with KVM acceleration and UEFI (OVMF) firmware.
- `installerconfig`: Automated non-interactive installation and golden image sysprep for FreeBSD's `bsdinstall`.

## Build Instructions

Run the following commands from this directory:

```bash
packer init ./freebsd.pkr.hcl
packer validate ./freebsd.pkr.hcl
packer build ./freebsd.pkr.hcl
```

To override variables (for example, using a different ISO location, disk size, or firmware paths):

```bash
packer build \
  -var 'iso_url=/data/ISO/Unix/FreeBSD-15.0-RELEASE-amd64-disc1.iso' \
  -var 'disk_size=32768M' \
  -var 'efi_firmware_code=/usr/share/edk2/ovmf/OVMF_CODE.fd' \
  -var 'efi_firmware_vars=/usr/share/edk2/ovmf/OVMF_VARS.fd' \
  freebsd.pkr.hcl
```

> **Note on UEFI Firmware (OVMF):** On RHEL/CentOS/Fedora hosts, install `edk2-ovmf` (`/usr/share/edk2/ovmf/OVMF_CODE.fd`). On Debian/Ubuntu hosts, install `ovmf` and set `-var 'efi_firmware_code=/usr/share/OVMF/OVMF_CODE.fd' -var 'efi_firmware_vars=/usr/share/OVMF/OVMF_VARS.fd'`.

## Universal Golden Template Features

- **UEFI Boot & GPT Layout**: Installs via UEFI with an EFI System Partition (ESP) formatted as FAT32 hosting `/EFI/BOOT/BOOTX64.EFI`, ready for libvirt domains configured with `<os firmware='efi'/>`.
- **Controller-Agnostic Storage**: `/etc/fstab` uses GEOM GPT labels (`/dev/gpt/rootfs` and `/dev/gpt/swapfs`) rather than hardcoded device names. The image can boot seamlessly on VirtIO (`vtbd`), SATA (`ada`), SCSI (`da`), or NVMe (`nda`) controllers.
- **Safe Cloning & Unique IDs**:
  - Existing SSH host keys are removed at the end of installation; FreeBSD automatically regenerates fresh, unique host keys on first boot.
  - `/etc/hostid` and entropy caches are wiped; `hostid_enable="YES"` generates a unique system UUID on first boot from the new VM's SMBIOS/hardware UUID.
  - Temporary files, shell history, and lease files are cleaned up.
- **Dynamic Networking**: `ifconfig_DEFAULT="DHCP"` acquires DHCP on whichever interface type is assigned (VirtIO `vtnet`, Intel `em`, etc.).
- **Guest Integration & Packages**: Installs `qemu-guest-agent`, `doas` (wheel group enabled), `curl`, and `ca_root_nss` if network access is available during the build.
- **Automatic Disk Expansion**: `growfs_enable="YES"` automatically expands the root filesystem on first boot if a larger disk is allocated in libvirt.
- **Dual Console Access**: Configured with `comconsole,vidconsole` at 115200 baud for both VNC/SPICE graphical console and `virsh console` serial login (`ttyu0`).
- **Output**: Produces a compressed, sparsified `freebsd15.qcow2` ready for libvirt domains.
