# build_geomx_vm_final_public.md

# GeoMx VM Build Guide (Public)

## Conventions

```bash
export BFX_HOME=/shared/bioinformatics
```

Users:

```text
geomxadmin   # admin account
user1        # pipeline execution account
user2        # example HPC user
```

## Build qemu.sif

```bash
module load singularity/4.1.0
singularity --verbose build qemu.sif docker://qemux/qemu-docker:6.06
```

## Create Ubuntu Server disk

```bash
qemu-img create -f qcow2 ./ub2004svr_geomx.qcow2 20G
```

## Install Ubuntu Server 20.04

```bash
qemu-system-x86_64 -m 20G -smp 2 -hda ./ub2004svr_geomx.qcow2 -boot d -cdrom ./ubuntu-20.04.6-live-server-amd64.iso -netdev user,id=n1,hostfwd=tcp::10022-:22 -device virtio-net-pci,netdev=n1
```

## Run headless

```bash
qemu-system-x86_64 -m 20G -smp 2 -hda ./ub2004svr_geomx.qcow2 -boot c -netdev user,id=n1,hostfwd=tcp::10022-:22 -device virtio-net-pci,netdev=n1 -display none
```

## SSH

```bash
ssh -p 10022 geomxadmin@127.0.0.1
```

## Configure 9p mounts

```bash
sudo mkdir /mnt/fastq
sudo mkdir /mnt/out
```

/etc/fstab:

```text
host_fastqdir /mnt/fastq 9p ro,user,sync,dirsync,relatime,access=client,trans=virtio,msize=10485760,umask=777 0 0
host_outdir /mnt/out 9p rw,user,sync,dirsync,relatime,access=client,trans=virtio,msize=10485760,umask=777 0 0
```

## Install GeoMx

```bash
mkdir -p $BFX_HOME/software/GeoMxNGSPipeline_download
cp *.sh *.tgz ~
cd ~
sudo ./GeoMxNGSPipeline_Linux_3.1.1.8.sh
```

```bash
sudo apt install net-tools
sudo netstat -tulpn
```

## Runtime settings

```bash
sudo vi /var/GeoMxNGSPipeline/runtimesettings.xml
```

Example:

```xml
<folder path="/mnt/out" name="out"/>
```

## Autologin account

```text
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin user1 %I $TERM
Type=idle
```

## Final .profile logic

Wait for port 5000, validate ini, validate FASTQs, run:

```bash
geomxngspipeline --in=/mnt/fastq --out=/mnt/out --ini=$INI_FILE --use-max-threads=true
```

Verify DCC files exist.

Create:

```text
finished.txt
failed.txt
error.txt
```

## Shutdown helper

```bash
/usr/local/bin/shut_down
```

```bash
#!/bin/bash
echo geomx | sudo -S shutdown -h now
```

## Final production run

```bash
singularity exec --no-home   --bind $FASTQ_PATH:$FASTQ_PATH:ro   --bind $OUT_PATH:$OUT_PATH:rw   qemu.sif qemu-system-x86_64   -m $THREADSMEM -smp $THREADS   -hda ./ub2004svr_geomx.qcow2 -boot c   -netdev user,id=n1,hostfwd=tcp::10022-:22   -device virtio-net-pci,netdev=n1   -fsdev local,id=fsdev0,security_model=none,path=$FASTQ_PATH   -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=host_fastqdir   -fsdev local,id=fsdev2,security_model=none,path=$OUT_PATH   -device virtio-9p-pci,id=fs2,fsdev=fsdev2,mount_tag=host_outdir   -display none &
```
