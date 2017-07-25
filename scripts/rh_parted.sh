#!/bin/bash
#
# Present 2x1GB virtual disks to your system. Write a singe bash shell script to create 2x800MB partitions
# on each disk upsing 'parted' and then bring both partitions into LVM control with the 'pvcreate' command.
# Create a volume group called 'vgscript' and add both PVs to it. Create three logical volumes each of size
# 500MB and name them 'lvscript1', 'lvscript2' and 'lvscript3'.
#

#---------------------------------------------------------------------------------------------------------
# declare output files

FILE="/root/output"
FILE_PROCESSED="/root/output_processed"
PART_OUT="/root/part_out"

#---------------------------------------------------------------------------------------------------------
# grab unintialised disks from parted, write them to file and remove white spaces

function get_disks {

    echo "parted --list 1> /dev/null 2> $FILE && awk -F ":" '{print $2}' $FILE > $FILE_PROCESSED && sed -i 's/^\s//g' $FILE_PROCESSED"

    # parted --list 1> /dev/null 2> $FILE \
    # && awk -F ":" '{print $2}' $FILE > $FILE_PROCESSED \
    # && sed -i 's/^\s//g' $FILE_PROCESSED
}

#---------------------------------------------------------------------------------------------------------
# read devices from $FILE_PROCESSED ; make labels on devices and partition them

function make_partition {

    local DISK
    while read -r DISK; do
        echo "Creating primary partition for $DISK"
        echo "/usr/sbin/parted --script $DISK mklabel msdos"
        # /usr/sbin/parted --script $DISK mklabel msdos
        echo "/usr/sbin/parted --script -a optimal $DISK mkpart primary 1 801MB"
        # /usr/sbin/parted --script -a optimal $DISK mkpart primary 1 801MB
        # /usr/sbin/partprobe

        if [ $? = 0 ]; then
            echo "Partition successfully created :  source $DISK"
        else
            echo "Failed to create partition."
            exit
        fi
    done < $FILE_PROCESSED
}

#---------------------------------------------------------------------------------------------------------
# initialise disks; create PV | VG | LV

function make_lvs {

    local DISK
    local PART
    local PARAM
    local VG_NAME
    local LV_NAME

    VG_NAME="vgscript"
    LV_NAME="lvscript"

    while read -r DISK; do
        PART=`echo $DISK | /usr/bin/sed 's/$/1/'`
        echo "Creating Physical Volume from source partition : $PART"
        echo "/usr/sbin/pvcreate $PART"
        # /usr/sbin/pvcreate $PART
        echo "$PART" >> $PART_OUT
    done < $FILE_PROCESSED

    PARAM=`tr '\n' ' ' < $PART_OUT`
    echo "/usr/sbin/vgcreate $VG_NAME $PARAM"
    # /usr/sbin/vgcreate $VG_NAME $PARAM

    for value in 1 2 3; do
        echo "/usr/sbin/lvcreate --name $LV_NAME$value --size 500M $VG_NAME"
        # /usr/sbin/lvcreate --name "$LV_NAME$value" --size 500M $VG_NAME
    done

}

function clean_up {

    if [[ -f $PART_OUT ]] && [[ -f $FILE ]] && [[ -f $FILE_PROCESSED ]]; then
        echo "rm -f $PART_OUT $FILE $FILE_PROCESSED"
        # rm -f $PART_OUT $FILE $FILE_PROCESSED
    fi
}

# __MAIN__

echo ""
echo "Function get_disks()"
get_disks
echo ""
echo "Function make_partition()"
make_partition
echo ""
echo "Function make_lvs()"
make_lvs
echo ""
echo "Clean files after script has run"
clean_up
