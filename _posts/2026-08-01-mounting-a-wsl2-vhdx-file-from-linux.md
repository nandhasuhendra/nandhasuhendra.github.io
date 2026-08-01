---
title: "Mounting a WSL2 ext4.vhdx File From Linux"
description: "How to read the contents of a WSL2 virtual disk (ext4.vhdx) from a native Linux install, using qemu-nbd to expose it as a block device and mount its ext4 partition."
date: 2026-08-01
last_modified_at: 2026-08-01
author: Nanda Suhendra
categories:
  - General
tags:
  - Linux
  - WSL2
  - Developer Tools
cover_image:
canonical_url:
draft: false
---

I dual boot Windows and Linux, and my Windows drive is mounted read-only under `/run/media` when I'm booted into Linux. I wanted to grab a few files out of a WSL2 distro without booting back into Windows. WSL2 stores each distro's entire filesystem as a single virtual disk file, `ext4.vhdx`, and Linux does not know how to mount a `.vhdx` out of the box. Here's how I got into it.

---

## Where the file actually is

Every WSL2 distro gets its own `ext4.vhdx`, buried under the Windows user profile:

```
AppData/Local/wsl/{9583eea0-85d3-41d9-a7f5-8e5536b38b0b}/ext4.vhdx
```

The folder name is a GUID, not the distro's name, so if you have more than one distro installed you may need to check `%LOCALAPPDATA%\wsl` from Windows first to know which GUID belongs to which distro. Mine was already sitting there since the Windows partition was mounted at `/run/media/nanda-suhendra/Windows-SSD`.

---

## vhdx is a QEMU problem, not a mount problem

The Linux kernel has no native driver for VHDX. What it does have is `qemu-nbd`, which comes from `qemu-utils` and can take basically any disk image format QEMU understands, VHDX included, and serve it over the Network Block Device protocol as if it were a real `/dev/nbdX` device. Once it's a block device, mounting it is just mounting.

Check it's installed, and that the kernel's `nbd` module exists:

```bash
which qemu-nbd
modinfo nbd
```

If `qemu-nbd` is missing, install `qemu-utils` (or your distro's equivalent). The `nbd` module ships with the stock kernel on most distros, it just isn't loaded until something asks for it.

---

## Connecting the vhdx as a block device

Load the module and connect the file:

```bash
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 --format=vhdx --read-only "/path/to/ext4.vhdx"
```

`max_part=8` tells the nbd module to reserve room for partitions on each nbd device, otherwise you only get the raw disk with no `/dev/nbd0p1` node for its partition. `--format=vhdx` is not strictly required, qemu-nbd can usually autodetect it, but being explicit avoids any ambiguity. `--read-only` matters here specifically because of what this disk is.

After connecting, the kernel needs a moment to notice the partition table:

```bash
sudo partprobe /dev/nbd0
udevadm settle
lsblk /dev/nbd0
```

`lsblk` should now show `/dev/nbd0` with a child partition, `/dev/nbd0p1` in my case, and its filesystem type as `ext4`.

---

## Why read-only is not optional here

WSL2 does not cleanly unmount its ext4 filesystem the way a normal shutdown does, it keeps the vhdx around ready to be reattached the next time you launch a distro. If you mount that same filesystem read-write from the host while WSL considers it "theirs," or if WSL starts up again while you still have it mounted, you get two things writing to the same ext4 journal without knowing about each other. That is exactly the kind of situation that leaves a filesystem inconsistent.

Since all I wanted was to read a few files, `--read-only` on `qemu-nbd` was the safe choice, it refuses any write at the block device level, so there's no scenario where the host and WSL both think they own the disk. If I actually needed to write to it, the correct order would be to fully shut WSL down first with `wsl --shutdown` on the Windows side, then mount read-write, then disconnect before starting WSL again. I didn't need that this time.

---

## Mounting the partition

With the block device visible, mounting it is nothing special:

```bash
sudo mkdir -p /mnt/wsl-vhdx
sudo mount -o ro /dev/nbd0p1 /mnt/wsl-vhdx
```

From there `/mnt/wsl-vhdx` is a normal read-only view into the distro's root filesystem, home directories, `/etc`, everything.

---

## Cleaning up in the right order

Unmount the filesystem before disconnecting the nbd device, not the other way around, or the kernel is left holding a mount pointing at a block device that no longer exists:

```bash
sudo umount /mnt/wsl-vhdx
sudo qemu-nbd --disconnect /dev/nbd0
```

`qemu-nbd --disconnect` releases `/dev/nbd0` so it's free for the next thing that wants to use it, whether that's this same vhdx later or a completely different image.

---

## Wrapping it into a script

Doing this by hand a second time is when I'd forget a step, so I wrapped mount, umount, and status into one script with the paths hardcoded for this specific vhdx:

```bash
#!/usr/bin/env bash
set -euo pipefail

VHDX="/run/media/nanda-suhendra/Windows-SSD/Users/Nandha/AppData/Local/wsl/{9583eea0-85d3-41d9-a7f5-8e5536b38b0b}/ext4.vhdx"
NBD_DEV="/dev/nbd0"
MOUNT_POINT="/mnt/wsl-vhdx"

do_mount() {
    modprobe nbd max_part=8
    qemu-nbd --connect="$NBD_DEV" --format=vhdx --read-only "$VHDX"
    udevadm settle --timeout=5 || sleep 1
    partprobe "$NBD_DEV" 2>/dev/null || true
    udevadm settle --timeout=5 || sleep 1

    local part
    part=$(lsblk -lnpo NAME,FSTYPE "$NBD_DEV" | awk '$2=="ext4"{print $1; exit}')
    mkdir -p "$MOUNT_POINT"
    mount -o ro "$part" "$MOUNT_POINT"
    echo "Mounted $part -> $MOUNT_POINT (read-only)"
}

do_umount() {
    mountpoint -q "$MOUNT_POINT" && umount "$MOUNT_POINT"
    [[ -e "$NBD_DEV" ]] && qemu-nbd --disconnect "$NBD_DEV"
}

case "${1:-}" in
    mount)  do_mount ;;
    umount) do_umount ;;
    *) echo "Usage: $0 {mount|umount}" >&2; exit 1 ;;
esac
```

`sudo ./wsl-vhdx-mount.sh mount` and `sudo ./wsl-vhdx-mount.sh umount`, and the partition detection via `lsblk` means it doesn't matter if the vhdx happens to expose its filesystem as `nbd0p1` versus something else, the script just asks for whichever partition on the device is actually `ext4`.

---

## Wrapping up

The short version: a `.vhdx` is just a disk image, and `qemu-nbd` is the bridge that turns "a file QEMU understands" into "a block device the kernel understands," after which mounting it is completely ordinary. The only real gotcha is respecting that WSL2 still considers that disk its own even when no distro is currently running, which is reason enough to default to read-only unless you've explicitly shut WSL down first.
