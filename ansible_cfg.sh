#!/bin/bash
#
# Usage :   bash script to install 'EPEL' repository and 'Ansible' package,
#           generate a passwordless 'ssh-key' to be use for agents and customize
#           the default 'ansible.cfg' file with the following parameters:
#                       'remote_port = 22'
#                       'remote_user = root'
#                       'log_path = /var/log/ansible'
#                       'host_key_checking = False'
#                       'private_key_file = /root/.ssh/ansible.key'

#-- Clear screen
/usr/bin/clear
printf '%60s\n' | tr ' ' -

#-- Colors
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
END_COLOR="\e[0m"

#-- Check and install missing packages
function check_prerequisites {

    local EPEL_CHECK
    local ANSIBLE_CHECK

    EPEL_CHECK=`rpm -qa | grep -i epel-release`
    if [ $? != 0 ]; then
        printf "%60s\n${RED}'epel-release'${END_COLOR} not found. %-20s${GREEN}[Installing]${END_COLOR}\n"
        yum install epel-release -y 1> /dev/null
    else
    printf "%60s\n${BLUE}'epel-release'${END_COLOR} found.\n"
    fi

    ANSIBLE_CHECK=`rpm -qa | grep -i ansible`
    if [ $? != 0 ]; then
        printf "%60s\n${RED}'ansible'${END_COLOR} %5snot found. %-20s${GREEN}[Installing]${END_COLOR}\n"
        yum install ansible -y 1> /dev/null
    else
        printf "%60s\n${BLUE}'ansible'${END_COLOR} %5sfound.\n"
    fi
}

#-- Generate empty phrase ssh key for ansible
function generate_key {

    local FILE
    local SSH_DIR

    FILE="/root/.ssh/ansible.key"
    SSH_DIR="/root/.ssh"

    if [ ! -d $SSH_DIR ]; then
        printf "\n${RED}'.ssh'${END_COLOR} not found under /root.\nCreating directory and setting permissions to ${GREEN}700${END_COLOR}.\n"
        mkdir -p $SSH_DIR
        chmod 700 $SSH_DIR
    fi

    if [[ -d $SSH_DIR ]] && [[ ! -f $FILE ]]; then
        printf "\n${BLUE}$SSH_DIR${END_COLOR} found.\nGenerating \'ansible\' ssh-key : ${GREEN}$FILE${END_COLOR}\n"
        ssh-keygen -t rsa -N "" -f $FILE 1> /dev/null
    else
        printf "\n${BLUE}$FILE${END_COLOR} found in ${BLUE}$SSH_DIR${END_COLOR}. \nNo need to generate another key. \n"
    fi

}

#-- Check if ansible.cfg exists and is a regular file
function cfg_check {

    local FILE

    FILE="/etc/ansible/ansible.cfg"

    if [ -f $FILE ]; then
        printf "\nConfiguration file : ${BLUE}$FILE${END_COLOR}\n"
    else
        printf "\n${RED}Missing configuration file.${END_COLOR}\n"
        printf '\n%60s\n' | tr ' ' -
        exit 1
    fi
}

#-- Add custom changes to config file
function custom_cfg {

    local FILE

    FILE="/etc/ansible/ansible.cfg"

    cp $FILE{,.original}

    sed -i -e '/remote_port/s/^#//'       \
           -e '/remote_user/s/^#//'       \
           -e '/log_path/s/^#//'          \
           -e '/host_key_checking/s/^#//' \
           -e '/private_key_file/{s/^#//;s/\/path\/to\/file/\/root\/\.ssh\/ansible\.key/;}' $FILE
}


## __FUNCTIONS__

check_prerequisites
generate_key
cfg_check
custom_cfg

printf '\n%60s\n' | tr ' ' -
