# Packer Images

Packer templates for building QEMU/libvirt images on a RHEL 10 host.

The templates use KVM acceleration and have been tested with local ISO images.

## Image sets

### Standalone libvirt images

These templates build compressed qcow2 images for direct use with libvirt.

| Directory      | OS                      | Firmware | Final image                               | Default login     |
| -------------- | ----------------------- | -------- | ----------------------------------------- | ----------------- |
| `centos/`      | CentOS Stream 10        | BIOS     | `output-centos-10/packer-centos-10.final` | None (root locked) |
| `ol9/`         | Oracle Linux 9          | UEFI     | `ol9withuefi.qcow2`                       | None (root locked) |
| `debian/`      | Debian 13 (Trixie)      | BIOS     | `debian13.qcow2`                          | None (root locked) |
| `debian-uefi/` | Debian 13 (Trixie)      | UEFI     | `debian13withuefi.qcow2`                  | None (root locked) |
| `freebsd14/`   | FreeBSD 14.0            | BIOS     | `freebsd14.qcow2`                         | `root` / `freebsd` |
| `vyos/`        | VyOS 2026.03            | BIOS     | `/data/ISO/VMIMAGES/KVM/vyos2026.qcow2`   | `vyos` / `vyos`   |

Relative image paths are created in the template directory. The VyOS path is
hardcoded in the post-processor, and its directory must already exist.

Cleanup differs by image:

- CentOS, Oracle Linux, and Debian use `virt-sysprep`, `virt-customize`, and
  `virt-sparsify`.
- FreeBSD cleans up during installation. See
  [`freebsd14/README.md`](freebsd14/README.md).
- VyOS is configured and cleaned up through `boot_command`, then sparsified with
  `virt-sparsify`.

The Linux images have no usable account. Add one before first use, for example
with `virt-customize --ssh-inject` or `--root-password`.

FreeBSD permits root SSH login with a password, and VyOS enables SSH with its
default password. Change these credentials before connecting either image to an
untrusted network.

### Vagrant images

The templates under `vagrant images/` also create a libvirt Vagrant box:

| Directory       | OS                      | Firmware | Vagrant box                      |
| --------------- | ----------------------- | -------- | -------------------------------- |
| `centos/`       | CentOS Stream 10        | BIOS     | `output-vagrant/package.box`     |
| `debian/`       | Debian 13               | BIOS     | `output-vagrant/package.box`     |
| `rhel/`         | RHEL 10                 | BIOS     | `output-vagrant/package.box`     |
| `ubuntu/24.04/` | Ubuntu 24.04            | BIOS     | `output-vagrant/package.box`     |
| `ubuntu/26.04/` | Ubuntu 26.04            | BIOS     | `output-vagrant/package.box`     |
| `uefi/`         | Ubuntu 24.04            | UEFI     | `output-vagrant/package-uefi.box` |

Vagrant images are for local development only:

- `vagrant` and `root` both use the password `vagrant`.
- Both accounts authorize the standard insecure Vagrant SSH key.
- `vagrant` has passwordless `sudo`.

The RHEL template does not activate a Red Hat subscription, so package updates
are unavailable until the system is registered.

The RHEL and Ubuntu BIOS templates run `sudo chmod a+r /boot/vmlinuz*` on the
build host.

## Requirements

- Linux host with KVM
- Packer, with the `qemu` plugin (and `vagrant` plugin for boxes) installed by
  `packer init`
- QEMU (`qemu-system-x86_64`, `qemu-img`)
- libvirt tooling, including `libguestfs` utilities
- `sudo` access for the post-processors
- OVMF firmware for UEFI templates
- Vagrant with a libvirt provider, to use the boxes
- Outbound internet access during builds

UEFI templates default to `/usr/share/edk2/ovmf/OVMF_CODE.fd` and
`OVMF_VARS.fd`. Override `ovmf_code` and `ovmf_vars` if your firmware is
elsewhere.

## Build an image

Run these commands from the directory containing the template, eg: CentOS.
Some templates resolve their installer files relative to the current directory,
so builds from other directories can fail.

```bash
cd centos
packer init ./centos.pkr.hcl
packer validate ./centos.pkr.hcl
packer build ./centos.pkr.hcl
```

To override a template variable:

```bash
packer build \
  -var 'iso_url=/path/to/linux.iso' \
  -var 'iso_checksum=sha256:CHECKSUM' \
  centos.pkr.hcl
```

Quote the path for Vagrant templates, because the parent directory contains a
space:

```bash
cd "vagrant images/ubuntu/26.04"
```

Add the resulting box to Vagrant with:

```bash
vagrant box add mybox ./output-vagrant/package.box
```

## Monitor a build

The VyOS, FreeBSD, CentOS, Debian, and Oracle Linux standalone builds have no SSH
communicator: Packer waits for the VM to power off, up to the shutdown timeout.
The VyOS install is typed with fixed delays, so a failed step does not stop the
build. Check the console if the resulting image looks wrong.
