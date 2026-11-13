# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

### BEGIN ADDED CODE ###

export PATH=$PATH:/var/GeoMxNGSPipeline

# indicate start date/time
date -Ins > ~/output.log

# wait till geomx pipeline service is listening on port 5000
MAX_WAIT=600
WAITED=0
LISTENING=$(netstat -tuln | egrep "^tcp..*0.0.0.0:5000" | wc -l)
while (( LISTENING == 0 )) ; do
  echo 'no listening on port 5000, waiting 2s' >> ~/output.log
  sleep 2

  WAITED=$((WAITED + 2))
  if (( WAITED >= MAX_WAIT )); then
    echo "GeoMx service failed to start within ${MAX_WAIT}s" \
        > /mnt/out/error.txt
    touch /mnt/out/failed.txt
    exit 1
  fi

  LISTENING=$(netstat -tuln | egrep "^tcp..*0.0.0.0:5000" | wc -l)
done
echo "found process listening on port 5000, $(date -Ins)" >> ~/output.log

# check for single ini file
INI_COUNT=$(ls -1 /mnt/out/*.ini | wc -l) # count ini files
if (( INI_COUNT > 1 )); then
  echo "Error: more than one config ini file in destination dir" > /mnt/out/error.txt
  exit 1
elif (( INI_COUNT == 0 )); then
  echo "Error: no config ini file found in destination dir" > /mnt/out/error.txt
  exit 1
fi
# note, numeric context with (()) does not work in /bin/sh
INI_FILE=$(ls -1 /mnt/out/*.ini) # should only be one file
echo "found project config ini file $INI_FILE" >> ~/output.log

# check for DSP-*.fastq.gz or DSP-*.fq.gz sequencing files
FASTQ_COUNT=$(ls -1 /mnt/fastq/DSP-*.f*q.gz | wc -l)
if (( FASTQ_COUNT == 0 )); then
  echo "Error: no sequencing files ( DSP-*.f*q.gz) found in fastq dir" > /mnt/out/error.txt
  exit 1
fi

# num cpus have been checked: max cpus == config cpus == requested cpus; when this is true, geomxngspipeline runs without requesting user input
# run pipeline process
geomxngspipeline --in=/mnt/fastq --out=/mnt/out --ini=$INI_FILE --use-max-threads=true

PIPELINE_STATUS=$?

echo "Pipeline exit code: $PIPELINE_STATUS" >> ~/output.log

# clean up
echo "\n\n####################\n\nLOGS\n\n ####################\n\n" >> ~/output.log
cat ~/*.log >> ~/output.log 2>/dev/null
date -Ins >> ~/output.log
cp -a ~/output.log /mnt/out
rm -f ~/*.log

if (( PIPELINE_STATUS == 0 )); then

    DCC_COUNT=$(find /mnt/out -name "*.dcc" | wc -l)

    if (( DCC_COUNT > 0 )); then
        touch /mnt/out/finished.txt
    else
        echo "Pipeline exited successfully but no DCC files found" \
            > /mnt/out/error.txt
        touch /mnt/out/failed.txt
        exit 1
    fi

else

    echo "Pipeline failed with exit code $PIPELINE_STATUS" \
        > /mnt/out/error.txt

    touch /mnt/out/failed.txt
    exit $PIPELINE_STATUS

fi


### END ADDED CODE ###
