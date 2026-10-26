# FreeBSD 14 Packer Template for Red Hat Libvirt Host

This template builds a compressed FreeBSD 14.0 qcow2 image suitable for deployment on Red Hat libvirt / KVM hosts.

## Files

- `freebsd.pkr.hcl`: Packer HCL2 configuration using the QEMU builder with KVM acceleration.
- `installerconfig`: Automated non-interactive installation configuration for FreeBSD's `bsdinstall`.

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

## Features & Configuration

- **Storage & Network**: Uses `virtio` block (`vtbd0`) and `virtio-net` (`vtnet0`) devices for native KVM performance.
- **Console Access**: Dual console configured (`comconsole,vidconsole`) so both VNC and `virsh console` / serial console (`ttyu0` at 115200 baud) work out of the box.
- **SSH**: `sshd` is enabled on boot with password authentication and root login enabled (default password: `freebsd`).
- **Disk Expansion**: `growfs` is enabled to automatically grow the root filesystem on first boot if the disk is resized.
- **Output**: Produces a compressed `freebsd14.qcow2` file in the current directory.
