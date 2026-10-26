# FreeBSD 14 Universal Golden Template for Red Hat Libvirt Host

This template builds a generalized, clone-ready FreeBSD 14.0 qcow2 image suitable for deployment on Red Hat libvirt / KVM hosts.

## Files

- `freebsd.pkr.hcl`: Packer HCL2 configuration using the QEMU builder with KVM acceleration.
- `installerconfig`: Automated non-interactive installation and golden image sysprep for FreeBSD's `bsdinstall`.

## Build Instructions

Run the following commands from this directory:

```bash
packer init ./freebsd.pkr.hcl
packer validate ./freebsd.pkr.hcl
packer build ./freebsd.pkr.hcl
```

To override variables (for example, using a different ISO location or disk size):

```bash
packer build \
  -var 'iso_url=/data/ISO/Unix/FreeBSD-14.0-RELEASE-amd64-disc1.iso' \
  -var 'disk_size=32768M' \
  freebsd.pkr.hcl
```

## Universal Golden Template Features

- **Controller-Agnostic Storage**: `/etc/fstab` uses GEOM GPT labels (`/dev/gpt/rootfs` and `/dev/gpt/swapfs`) rather than hardcoded device names. The image can boot seamlessly on VirtIO (`vtbd`), SATA (`ada`), SCSI (`da`), or NVMe (`nda`) controllers.
- **Safe Cloning & Unique IDs**:
  - Existing SSH host keys are removed at the end of installation; FreeBSD automatically regenerates fresh, unique host keys on first boot.
  - `/etc/hostid` and entropy caches are wiped; `hostid_enable="YES"` generates a unique system UUID on first boot from the new VM's SMBIOS/hardware UUID.
  - Temporary files, shell history, and lease files are cleaned up.
- **Dynamic Networking**: `ifconfig_DEFAULT="DHCP"` acquires DHCP on whichever interface type is assigned (VirtIO `vtnet`, Intel `em`, etc.).
- **Guest Integration & Packages**: Installs `qemu-guest-agent`, `doas` (wheel group enabled), `curl`, and `ca_root_nss` if network access is available during the build.
- **Automatic Disk Expansion**: `growfs_enable="YES"` automatically expands the root filesystem on first boot if a larger disk is allocated in libvirt.
- **Dual Console Access**: Configured with `comconsole,vidconsole` at 115200 baud for both VNC/SPICE graphical console and `virsh console` serial login (`ttyu0`).
- **Output**: Produces a compressed, sparsified `freebsd14.qcow2` ready for libvirt domains.
