#!/bin/bash

###############################################################################
#
# submit_fastq_to_dcc.sh
#
# Submit a FASTQ -> DCC processing job through Slurm.
#
# Responsibilities:
#
#   1. Validate user inputs.
#   2. Create the output directory if necessary.
#   3. Copy the GeoMx configuration file into the output directory.
#   4. Extract the requested thread count from the INI file.
#   5. Convert thread count into a Slurm memory request.
#   6. Submit the actual processing script.
#
###############################################################################

set -euo pipefail

# Directory containing this script
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

###############################################################################
# Parse command-line arguments
###############################################################################

INI_FILE=""
FASTQ_DIR=""
OUTPUT_DIR=""
PARTITION=""

usage() {

cat << EOF

Usage:

submit_geomx_dcc.sh \
    --ini CONFIG.ini \
    --fastq FASTQ_DIR \
    --out OUTPUT_DIR \
    --partition PARTITION

EOF

}

while [[ $# -gt 0 ]]
do
    case "$1" in

        --ini)
            INI_FILE="$2"
            shift 2
            ;;

        --fastq)
            FASTQ_DIR="$2"
            shift 2
            ;;

        --out)
            OUTPUT_DIR="$2"
            shift 2
            ;;

        --partition)
            PARTITION="$2"
            shift 2
            ;;

        *)
            echo "Unknown argument: $1"
            usage
            exit 1
            ;;

    esac
done

# make absolute paths
INI_FILE=$(realpath "$INI_FILE")
FASTQ_DIR=$(realpath "$FASTQ_DIR")
mkdir -p "$OUTPUT_DIR"
chmod 2775 "$OUTPUT_DIR" # force mode rwxrwxr-x
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

###############################################################################
# Input validation
###############################################################################

[[ -f "$INI_FILE" ]] || {
    echo "Configuration file not found:"
    echo "$INI_FILE"
    exit 1
}

[[ -d "$FASTQ_DIR" ]] || {
    echo "FASTQ directory not found:"
    echo "$FASTQ_DIR"
    exit 1
}

mkdir -p "$OUTPUT_DIR"

###############################################################################
# Copy configuration into the output directory.
#
# The VM expects to find exactly one INI file inside the mounted output
# directory, so we place a copy there before submission.
###############################################################################

cp "$INI_FILE" "$OUTPUT_DIR"

###############################################################################
# Extract thread count from configuration file.
#
# Example:
#
# threads=16
#
###############################################################################

THREADS=$(
    grep -i "^threads" "$INI_FILE" |
    tail -1 |
    cut -d'=' -f2 |
    tr -d ' '
)

###############################################################################
# Memory model
#
# Current recommendation:
#
#     10 GB RAM per requested thread
#
###############################################################################

MEMORY_GB=$(( THREADS * 10 ))

echo "Submitting DCC generation job"
echo "Threads : $THREADS"
echo "Memory  : ${MEMORY_GB}G"

###############################################################################
# Submit job
###############################################################################

sbatch \
    --cpus-per-task="$THREADS" \
    --mem="${MEMORY_GB}G" \
    --partition="$PARTITION" \
    "${SCRIPT_DIR}/run_geomx_dcc.sh" \
    "$FASTQ_DIR" \
    "$OUTPUT_DIR"
