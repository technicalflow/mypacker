# Packer Images

Packer templates for building QEMU/libvirt images on a RHEL 10 host.

The templates use KVM acceleration and have been tested with local ISO images.

## Image sets
### Standalone libvirt images

These templates build compressed qcow2 images and run the local cleanup steps
with `virt-sysprep`, `virt-customize`, and `virt-sparsify`.

- `centos/` - CentOS Stream 10
- `ol9/` - Oracle Linux 9 UEFI
- `debian/` - Debian 13 (Trixie)
- `debian-uefi/` - Debian 13 (Trixie) UEFI

### Vagrant images

The templates under `vagrant images/` also create a libvirt Vagrant box at
`output-vagrant/package.box`:

- `centos/` - CentOS Stream 10
- `debian/` - Debian 13
- `rhel/` - RHEL 10  // current template does not activate a Red Hat subscription.
- `ubuntu/24.04/` - Ubuntu 24.04
- `ubuntu/26.04/` - Ubuntu 26.04
- `uefi/` - Ubuntu 24.04 UEFI

Vagrant images create the `vagrant` user with password `vagrant` and install
the standard insecure Vagrant SSH key.

## Requirements

- Linux host
- Packer
- QEMU/KVM (`qemu-system-x86_64`)
- libvirt tooling, including `libguestfs` utilities
- A compatible Linux installation ISO

The default ISO paths point to `/data/ISO/Linux/`. Change `iso_url` and
`iso_checksum` in the template, or override them at build time, when using a
different ISO location.

## Build an image

Run these commands from the directory containing the template, eg: Centos:

```bash
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

The output directory and final image name are defined in each template. For
Vagrant builds, add the resulting box to Vagrant with:

```bash
vagrant box add mybox ./output-vagrant/package.box
```
