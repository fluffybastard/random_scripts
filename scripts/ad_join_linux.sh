#!/bin/bash

#---------------------------------------------------------------------------------------
#  Description:
#    Bash script frame for AD integration of a Linux client, using Kerberos and
#    SSSD, and creation of a user white list to grant login capabilities.
#    It overwrites the default OS behaviour, which is to allow all AD users from
#    a configured domain to be able to login.
#
#    Example configuration provided (RHEL7 only).
#    You will need an AD admin account for the realm join.
#        $ realm discover [AD domain controller/IP]
#        $ realm join [AD domain controller/IP] --user=ADMIN
#    NTP must be synchronised.
#    DNS must be able to resolve hosts.
#
#    Run the script once you joined a realm.
#    Locally:
#        $ /bin/bash ad_join.sh
#
#    Remotely:
#        - add your servers to the 'server_list' file
#        - run a loop over that file and collect the output locally
#        - default output is to STDOUT
#        - output contains some server info and changes that were made
#
#        $ for server in `cat server_list`; \
#          do echo "Configuring $server .."; \
#          ssh -T root@$server 'bash -s' < ad_join.sh \
#          >>  output.local.$(date '+%F'); done 2> /dev/null
#---------------------------------------------------------------------------------------

#--------------------- SAMPLE OUTPUT ---------------------------------------------------
# --------------------------------------------------------------------------------
# HOST                                                         test-vm
# UP SINCE                                                     2017-07-06 17:43:41
# USERS LOGGED IN                                              1
#
# -- Check dependency packages and install missing ones
#
# + realmd                                                     [FOUND]
# - krb5-workstation                                           [INSTALLING]
# - pam_krb5                                                   [INSTALLING]
# - sssd                                                       [INSTALLING]
#
# -- Backup original configuration files to FILE.06-07-2017
#
# /etc/krb5.conf --> /etc/krb5.conf.06-07-2017                 [MOVED]
# /etc/sssd/sssd.conf --> /etc/sssd/sssd.conf.06-07-2017       [MOVED]
#
# -- Copy new configuration to files
#
# + /etc/krb5.conf                                             [DONE]
# + /etc/sssd/sssd.conf                                        [DONE]
#
# -- Grant users access
#
# realm permit user1@DOMAIN.COM
# realm permit user2@DOMAIN.COM
# realm permit user3@DOMAIN.COM
# realm permit user4@DOMAIN.COM
# realm permit user5@DOMAIN.COM
# --------------------------------------------------------------------------------

#--------------------- SAMPLE OUTPUT w/ ERROR ------------------------------------------
# --------------------------------------------------------------------------------
# HOST                                                         server
# UP SINCE                                                     2017-07-17 12:31:31
# USERS LOGGED IN                                              2
# /etc/os-release                                              [MISSING]
#--------------------------------------------------------------------------------

# -- Clear screen before running the script | Usefull when you run the script locally
/usr/bin/clear

# -- Improve variable visibility
declare OS_VERSION
declare DATE
declare KRB5_LOCATION
declare SSSD_LOCATION
declare -a WHITE_LIST

# -- Populate global variables
OS_VERSION=$(awk '/^ID=/ {print $1}' /etc/os-release | awk -F "\=" '{print $2}' 2> /dev/null | sed 's/\"//g')
DATE=$(date +"%d-%m-%Y")
KRB5_LOCATION=/etc/krb5.conf
SSSD_LOCATION=/etc/sssd/sssd.conf
WHITE_LIST=( 'user1' 'user2' 'user3' 'user4' 'user5' )

# -- Format ouline table
function outline {

    printf '%80s\n' | tr ' ' -
}

# -- Print some general information
function print_info {

    outline

    printf "%-60s %-5s\n" "HOST " "$(hostname -f)"
    printf "%-60s %-5s\n" "UP SINCE" "$(uptime -s)"
    printf "%-60s %-5s\n" "USERS LOGGED IN" "$(who | wc -l)"

}

# -- RedHat
function redhat_packages {

    local REALMD_CHECK
    local KRB5_CHECK
    local REALMD_CHECK
    local PAM_KRB5_CHECK

    printf "\n-- Check dependency packages and install missing ones\n\n"

    # -- Check if 'realmd' package is installed
    REALMD_CHECK=$(rpm -qa | grep realmd)
    if [ $? != 0 ]; then
        printf "%-60s %-5s\n" "- realmd" [INSTALLING]
        yum install -y realmd 1> /dev/null
    else
        printf "%-60s %-5s\n" "+ realmd" [FOUND]
    fi

    # -- Check if 'krb5-workstation' package is installed
    KRB5_CHECK=$(rpm -qa | grep krb5-workstation)
    if [ $? != 0 ]; then
        printf "%-60s %-5s\n" "- krb5-workstation" [INSTALLING]
        yum install -y krb5-workstation 1> /dev/null
    else
        printf "%-60s %-5s\n" "+ krb5-workstation" [FOUND]
    fi

    # -- Check if 'pam_krb5' package is installed
    PAM_KRB5_CHECK=$(rpm -qa | grep pam_krb5)
    if [ $? != 0 ]; then
        printf "%-60s %-5s\n" "- pam_krb5" [INSTALLING]
        yum install -y pam_krb5 1> /dev/null
    else
        printf "%-60s %-5s\n" "+ pam_krb5" [FOUND]
    fi

    # -- Check if 'sssd' package is installed
    # -- Adjust version number if any major updates occur
    realmd_CHECK=$(rpm -qa | grep sssd-1.14)
    if [ $? != 0 ];then
        printf "%-60s %-5s\n" "- sssd" [INSTALLING]
        yum install -y sssd 1> /dev/null
    else
        printf "%-60s %-5s\n" "+ sssd " [FOUND]
    fi

}

# -- Backup original configuration files
function backup_orig_confs {

    local RETURN_CODE

    printf "\n-- Backup original configuration files to FILE.${DATE}\n\n"

    # -- Backup kerberos configuration file
    if [ ! -e ${KRB5_LOCATION} ];then
        printf "%-60s %-5s\n" "${KRB5_LOCATION}" [MISSING]
    else
        printf "%-60s %-5s\n" "${KRB5_LOCATION} --> ${KRB5_LOCATION}.${DATE}" [MOVED]
        mv ${KRB5_LOCATION}{,.${DATE}}
    fi

    # -- Check if sssd service is running and stop it before moving the config file
    RETURN_CODE=$(systemctl status sssd)
    if [ $? != 0 ];then
        systemctl stop sssd 1> /dev/null
    fi

    # -- Backup sssd configuration file
    if [ ! -e ${SSSD_LOCATION} ];then
        printf "%-60s %-5s\n" "${SSSD_LOCATION}" [MISSING]
    else
        printf "%-60s %-5s\n" "${SSSD_LOCATION} --> ${SSSD_LOCATION}.${DATE}" [MOVED]
        mv ${SSSD_LOCATION}{,.${DATE}}
    fi

}

# -- Copy new configuation files
function copy_new_confs {

    printf "\n-- Copy new configuration to files\n\n"

    # -- Copy kerberos configuration
    printf "%-60s %-5s\n" "+ ${KRB5_LOCATION}" [DONE]

    cat <<EOT > ${KRB5_LOCATION}
[libdefaults]
    default_realm = EXAMPLE.COM

[domain_realms]
    .example.com = EXAMPLE.COM
    example.com = EXAMPLE.COM

[logging]
    kdc = FILE:/var/log/krb5/krb5kdc.log
    admin_server = FILE:/var/log/krb5/kadmind.log
    default = SYSLOG:NOTICE:DAEMON

[realms]
    EXAMPLE.COM = {
        kdc = ad.example.com
        admin_server = ad.example.com
    }
EOT

    # -- Copy sssd configuration
    printf "%-60s %-5s\n" "+ ${SSSD_LOCATION}" [DONE]

    cat <<EOT > ${SSSD_LOCATION}
[sssd]
config_file_version = 2
services = pam,nss
domains = example.com

[pam]

[nss]
fallback_homedir = /home/%u
override_homedir = /home/%u
override_shell = /bin/bash

[domain/example.com]
id_provider = ad
auth_provider = ad
enumerate = false
cache_credentials = true
case_sensitive = true
ad_server = ad.server.1,ad.server.2
EOT

    # -- Start and enable sssd service once the new file is in place
    systemctl start sssd    1> /dev/null
    systemctl enable sssd   1> /dev/null

}

# -- Run through a predefined users list and grant them login access
function white_list {

    printf "\n -- Grant users on white_list access\n\n"

    # -- Overwrite default behaviour
    # -- Deny all user access after initial realm join
    realm deny --all


    for (( i = 0; i < ${#WHITE_LIST[@]}; i++ )); do
        echo "realm permit ${WHITE_LIST[${i}]}@DOMAIN.COM"
        realm permit ${WHITE_LIST[${i}]}@DOMAIN.COM
    done
}

#--------------------------------------------------------------------------------
# -- Check for default OS version file | Skip server if it's not found
if [ ! -f /etc/os-release  ]; then
    print_info
    printf "%-60s %-5s\n" "/etc/os-release" [MISSING]
    outline
else
    case ${OS_VERSION} in
        rhel|centos)    print_info
                        redhat_packages
                        backup_orig_confs
                        copy_new_confs
                        white_list
                        outline
                        ;;
        sles*)          print_info
                        ;;
        debian)         print_info
                        ;;
        *)              printf "Undefined OS version for this script\n";;
    esac
fi
