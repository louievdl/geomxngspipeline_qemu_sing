# geomx_vm_history_public.md

# Chronological Development History

## Initial HPC Experiments

```bash
singularity --verbose build qemu.sif Singularity
singularity --verbose build --fakeroot qemu.sif Singularity
```

Both failed.

Working approach:

```bash
singularity --verbose build qemu.sif docker://qemux/qemu-docker:6.06
```

## Early QEMU Tests

```bash
singularity exec --no-home qemu.sif qemu-img create -f qcow2 myVirtualDisk.qcow2 5G
```

```bash
singularity exec --no-home qemu.sif qemu-system-x86_64 -m 4G -smp 2 -hda ubuntu_2004_geomx.vdi
```

## Networking Experiments

Tried:

```bash
-netdev user,id=net0,net=192.168.0.0/24,dhcpstart=192.168.0.9,hostfwd=tcp::44788-:22
```

Eventually settled on:

```bash
hostfwd=tcp::10022-:22
```

and

```bash
ssh -p 10022 geomxadmin@127.0.0.1
```

## Laptop Reconstruction Phase

Created new qcow2:

```bash
qemu-img create -f qcow2 ./ubuntu_2004_geomx.qcow2 20G
```

Installed Ubuntu Desktop then later Ubuntu Server.

## Shared Filesystem Discovery

Manual mount:

```bash
sudo mount -t 9p host_share /mnt/shared
```

Final fstab approach:

```text
host_share /mnt/shared 9p rw,user,sync,dirsync,relatime,access=client,trans=virtio 0 0
```

## GeoMx Installation

```bash
sudo ./GeoMxNGSPipeline_Linux_3.1.1.8.sh
```

Verified:

```bash
sudo netstat -tulpn
```

Service listens on:

```text
0.0.0.0:5000
```

## Service Dependency Discovery

Pipeline fails if started before service.

Introduced:

```bash
tmp=$(netstat -tuln | egrep "^tcp..*0.0.0.0:5000" | wc -l)
while [ "$tmp" == 0 ] ; do
  sleep 2
  tmp=$(netstat -tuln | egrep "^tcp..*0.0.0.0:5000" | wc -l)
done
```

## Multi-share Design

Migrated from:

```text
/mnt/shared
```

to:

```text
/mnt/fastq
/mnt/out
```

using:

```bash
-fsdev local,id=fsdev0,security_model=none,path=$FASTQ_PATH
-device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=host_fastqdir
```

and

```bash
-fsdev local,id=fsdev2,security_model=none,path=$OUT_PATH
-device virtio-9p-pci,id=fs2,fsdev=fsdev2,mount_tag=host_outdir
```

## Thread Discovery

Observed that:

```text
Slurm CPUs == VM CPUs == INI thread count
```

must agree.

Final command:

```bash
geomxngspipeline --in=/mnt/fastq --out=/mnt/out --ini=$INI_FILE --use-max-threads=true
```

## 2026 Refinements

Added startup timeout.

Added DCC verification before:

```text
finished.txt
```

Added:

```text
failed.txt
error.txt
```

Standard shutdown:

```bash
ssh -p 10022 geomxadmin@127.0.0.1 shut_down
```
