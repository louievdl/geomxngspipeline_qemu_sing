#!/bin/bash

###############################################################################
#
# run_fastq_to_dcc.sh
#
# Executes a FASTQ -> DCC conversion inside a QEMU virtual machine.
#
# Workflow:
#
#  1. Copy master QCOW2 image.
#  2. Launch VM.
#  3. Mount FASTQ directory.
#  4. Mount output directory.
#  5. Wait for completion markers.
#  6. Shutdown guest.
#  7. Remove temporary image.
#
###############################################################################

set -euo pipefail

###############################################################################
# User arguments
###############################################################################

FASTQ_DIR="$1"
OUTPUT_DIR="$2"

###############################################################################
# Configuration
###############################################################################

MASTER_IMAGE="/path/to/master.qcow2"
QEMU_CONTAINER="/path/to/qemu.sif"

SSH_PORT="10022"

THREADS="${SLURM_CPUS_PER_TASK:-1}"
MEMORY_GB=$(( THREADS * 10 ))

###############################################################################
# Logging helper
###############################################################################

log() {

    echo "[$(date '+%F %T')] $*"

}

###############################################################################
# Copy VM image
#
# VM storage must be writable during execution.
#
# Therefore we never execute the master image directly.
###############################################################################

WORKING_IMAGE="./working_geomx.qcow2"

log "Copying VM image"

cp "$MASTER_IMAGE" "$WORKING_IMAGE"

###############################################################################
# Launch virtual machine
###############################################################################

log "Launching virtual machine"

singularity exec --no-home \
    --bind /uoa:/uoa:rw \
    --bind "$FASTQ_DIR":"$FASTQ_DIR":ro \
    --bind "$OUTPUT_DIR":"$OUTPUT_DIR":rw \
    "$QEMU_CONTAINER" \
    qemu-system-x86_64 \
    -boot c \
    -display none \
    -hda "$WORKING_IMAGE" \
    -m "${MEMORY_GB}G" \
    -smp "$THREADS" \
    -netdev user,id=n1,hostfwd=tcp::${SSH_PORT}-:22 \
    -device virtio-net-pci,netdev=n1 \
    -fsdev local,id=fsFastq,security_model=none,path="$FASTQ_DIR" \
    -device virtio-9p-pci,id=fastqShare,fsdev=fsFastq,mount_tag=host_fastqdir \
    -fsdev local,id=fsOutput,security_model=none,path="$OUTPUT_DIR" \
    -device virtio-9p-pci,id=outputShare,fsdev=fsOutput,mount_tag=host_outdir \
    &

VIRTUAL_MACHINE_PID=$!

###############################################################################
# Wait for pipeline completion
#
# VM-side logic creates:
#
#     finished.txt
#     failed.txt
#     error.txt
#
###############################################################################

log "Monitoring output directory"

PIPELINE_STATUS=1

while true
do

    if [[ -f "$OUTPUT_DIR/finished.txt" ]]
    then
        log "Successful completion detected"
        PIPELINE_STATUS=0
        break
    fi

    if [[ -f "$OUTPUT_DIR/failed.txt" ]]
    then
        log "Failure marker detected"
        PIPELINE_STATUS=1
        break
    fi

    if [[ -f "$OUTPUT_DIR/error.txt" ]]
    then
        log "Error marker detected"
        PIPELINE_STATUS=1
        break
    fi

    sleep 30

done

###############################################################################
# Gracefully shutdown guest operating system
#
# The VM contains a helper command:
#
#     shut_down
#
###############################################################################

log "Requesting guest shutdown"

ssh \
    -p "${SSH_PORT}" \
    geomx@127.0.0.1 \
    shut_down \
    || true

###############################################################################
# Wait for QEMU process to exit naturally
###############################################################################

for ATTEMPT in {1..30}
do

    if ! kill -0 "$VIRTUAL_MACHINE_PID" 2>/dev/null
    then
        break
    fi

    sleep 2

done

###############################################################################
# Final safety cleanup
###############################################################################

kill "$VIRTUAL_MACHINE_PID" 2>/dev/null || true

###############################################################################
# Normalise output permissions
###############################################################################

chmod -R g+rwX "$OUTPUT_DIR" || true

###############################################################################
# Remove temporary VM image
###############################################################################

log "Removing temporary VM image"

rm -f "$WORKING_IMAGE"

###############################################################################
# Return success/failure to Slurm
###############################################################################

exit "$PIPELINE_STATUS"
