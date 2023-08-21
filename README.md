![alt text](ecs.logo.JPG)
* This repository contains instructions on using STIG-Partitioned Enterprise Linux (spel) AMIs and Compliance As Code's ansible playbooks to perform a base STIG hardening in an effort to create a hardened Red Hat Enterprise Linux 8 hardened AMI/Gold Image. For any additional details or inquiries, please contact us at c.sargent-ctr@ecstech.com.
# Project Links
# [STIG Partitioned Enterprise Linux](https://github.com/plus3it/spel/tree/master)
# [Compliance As Code](https://github.com/ComplianceAsCode/content)
* Deployed Red Hat 8 on t2.large with public IP and using alpha_key_pair
* Note terraform and aws cli should be installed before proceeding

# Deploy EC2 and SG from spel ami
1. ssh -i alpha_key_pair.pem ec2-user@PG-TerraformPublicIP
2. cd /home/christopher.sargent/ && git clone https://github.com/ChristopherSargent/ecs_rhel8_lvm_stig_spel_ami.git
3. cd ecs_rhel8_lvm_stig_spel_ami/terraform && vim providers.tf
```
# Playground
provider "aws" {
  region = var.selected_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
```
4. vim alpha_key_pair.pem
```
# alpha_key_pair.pem.pem key is in AWS secrets manager in playground. Cut and paste key into this file and save
```
5. chmod 400 alpha_key_pair.pem
6. vim variables.tf
```
variable "aws_access_key" {
  type    = string
  default = "" # specify the access key
}
variable "aws_secret_key" {
  type    = string
  default = "" # specify the secret key
}
variable "selected_region" {
  type    = string
  default = "" # specify the aws region
}
# aws ssh key
variable "ssh_private_key" {
  default         = "alpha_key_pair.pem" # specify ssh key
  description     = "alpha_key_pair"
}
variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
  default     = "" # specfigy vpc id
}

variable "ami_id" {
  description = "The ID of the Amazon Machine Image (AMI) to use."
  type        = string
  default     = "ami-0b1aef95503ad8e3a"  # Provide a default AMI ID here spel-minimal-rhel-8-hvm-2023.07.1.x86_64-gp2
}

variable "availability_zone" {
  description = "The Availability Zone in which to launch the EC2 instance."
  type        = string
  default     = "us-gov-west-1a"  # Provide a default Availability Zone here
}

variable "subnet_id" {
  description = "The ID of the subnet."
  type        = string
  default     = "" #specfify subnet id
}

variable "ssh_cidr_blocks" {
  description = "List of allowed CIDR blocks for SSH."
  type        = list(string)
  default     = [""] #specify allowed public IP/32
}

variable "https_cidr_blocks" {
  description = "List of allowed CIDR blocks for HTTPS."
  type        = list(string)
  default     = [""] #specify allowed public IP/32
}

variable "instance_type" {
  description = "The type of EC2 instance to launch."
  type        = string
  default     = "t2.large" # specify instance type
}

variable "tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
  default = {
    Environment = ""                                   # specify Environment Dev, Prod ect.
    Name        = "pg-rhel8-lvm-stig-spel-terraform-ec2" # specify tag name
  }
}
```
7. vim main.tf
```
# Security Group
resource "aws_security_group" "default" {
  name        = "pg-rhel8-lvm-stig-spel-terraform-sg"
  description = "Used in the terraform"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.https_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance
resource "aws_instance" "pg-rhel8-lvm-stig-spel-terraform-ec2" {
  ami                         = var.ami_id
  associate_public_ip_address = true # Enable/disable pibluc IP
  availability_zone           = var.availability_zone
  enclave_options {
    enabled = false
  }

  get_password_data                    = false
  hibernation                          = false
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = var.instance_type
  ipv6_address_count                   = 0
  key_name                             = "alpha_key_pair"

  maintenance_options {
    auto_recovery = "default"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = "1"
    http_tokens                 = "optional"
    instance_metadata_tags      = "disabled"
  }

  monitoring = true

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = "arn:aws-us-gov:kms:us-gov-west-1:036436800059:key/23051040-d05e-4080-99f6-bbd740bb1b14"
    volume_size           = 128
    volume_type           = "gp2"
  }

  source_dest_check = true
  subnet_id         = var.subnet_id
  tenancy                = "default"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  tags = var.tags
}
```
8. terraform init && terraform plan --out pg-rhel8-lvm-stig-spel.out
9. terraform apply pg-rhel8-lvm-stig-spel.out
10. https://console.amazonaws-us-gov.com > EC2 > pg-rhel8-lvm-stig-spel-terraform-ec2 and verify instance is up

![Screenshot](resources/ec2-verify1.JPG)

11. https://console.amazonaws-us-gov.com > EC2 > pg-rhel8-lvm-stig-spel-terraform-ec2 > Actions > Security > Modify IAM role > cdm3-ec2RoleForSSM > Update role

# Update local user password via SSM
1. https://console.amazonaws-us-gov.com > EC2 > pg-rhel8-lvm-stig-spel-terraform-ec2 > Connect to Session Manager
2. sudo -i
3. passwd maintuser
4. dnf update -y && reboot

# Hardening compliance as code
1. ssh -i maintuser@PublicIP
2. sudo -i
3. dnf install scap-security-guide ansible git vim -y
4. mkdir -p /home/ec2-user/oscap && cd /home/ec2-user/oscap

# Add time stamp to terminal and history
1. echo "export PROMPT_COMMAND='echo -n \[\$(date +%F-%T)\]\ '" >> /etc/bashrc && echo "export HISTTIMEFORMAT='%F-%T '" >> /etc/bashrc && source /etc/bashrc

# Add ansible logging
1. ansible-config init --disabled -t all > /etc/ansible/ansible.cfg && cp /etc/ansible/ansible.cfg /etc/ansible/ansible.cfg.ORIG
2. sed -i -e 's|;log_path=|log_path= /var/log/ansible.log|g' /etc/ansible/ansible.cfg

# Fix ec2-user
1. adduser ec2-user
2. cd /home/ec2-user/ && mkdir .ssh && chmod 700 .ssh
3. cd .ssh && vi authorized_keys
ssh-rsa AddPublicKeyHere alpha_key_pair

4. chmod 600 authorized_keys
5. usermod -aG wheel ec2-user
6. chown -R ec2-user:ec2-user /home/ec2-user/
7. visudo 
* Uncomment # %wheel ALL=(ALL) NOPASSWD: ALL or you wont be able to sudo after hardening
```
## Same thing without a password
%wheel  ALL=(ALL)       NOPASSWD: ALL
```
# Pre hardening [OSCAP Report](https://github.com/ChristopherSargent/ecs_rhel8_lvm_stig_spel_ami/tree/main/reports)
* Note the pre hardening oscap score is 49%
1. cd /home/ec2-user/oscap/
* Run oscap
```
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig --results-arf /home/ec2-user/oscap/pg-rhel8-ami-spel-oscap-pre.xml --report /home/ec2-user/oscap/pg-rhel8-ami-spel-oscap-pre.report.html --fetch-remote-resources --oval-results /usr/share/xml/scap/ssg/content/ssg-rhel8-ds-1.2.xml
```
2. chown -R ec2-user:ec2-user /home/ec2-user/
3. exit && exit
4. mkdir RHEL8-LVM-STIG-SPEL-08172023-CAS/pg/reports && cd RHEL8-LVM-STIG-SPEL-08172023-CAS/pg/reports
5. scp -i /root/ecs/alpha_key_pair.pem ec2-user@PublicIP:oscap/pg-rhel8-ami-spel-oscap-pre.report.html .

# Hardening
1. cd /home/ec2-user/
2. git clone https://github.com/ChristopherSargent/ecs_compliance_as_code.git
3. cd ecs_compliance_as_code/playbooks
4. cp /home/ec2-user/ecs_compliance_as_code/playbooks/rhel8-playbook-stig2-fixed.yml /usr/share/scap-security-guide/ansible/ && chmod 644 /usr/share/scap-security-guide/ansible/rhel8-playbook-stig2-fixed.yml
5. cp /etc/ssh/sshd_config /etc/ssh/sshd_config.08192023
6. ansible-playbook -i "localhost," -c local /usr/share/scap-security-guide/ansible/rhel8-playbook-stig2-fixed.yml
```
localhost                  : ok=2626 changed=437  unreachable=0    failed=0    skipped=1027 rescued=0    ignored=3
```

![Screenshot](resources/ansible1.JPG)

# Fix visudo 
* #Uncomment # %wheel ALL=(ALL) NOPASSWD: ALL or you wont be able to sudo after hardening
1. visudo
```
## Same thing without a password
%wheel  ALL=(ALL)       NOPASSWD: ALL
```
# Post additional hardening [OSCAP Report](https://github.com/ChristopherSargent/ecs_rhel8_lvm_stig_spel_ami/tree/main/reports)
* Note the ost hardening oscap score is 91%
1. cd /home/ec2-user/oscap
* Run oscap
```
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig --results-arf /home/ec2-user/oscap/pg-rhel8-ami-spel-oscap-post.xml --report /home/ec2-user/oscap/pg-rhel8-ami-spel-oscap-post.report.html --fetch-remote-resources --oval-results /usr/share/xml/scap/ssg/content/ssg-rhel8-ds-1.2.xml
```
3. chown -R ec2-user:ec2-user /home/ec2-user 
4. exit && exit 
4. mkdir RHEL8-LVM-STIG-SPEL-08172023-CAS/pg/reports && cd RHEL8-LVM-STIG-SPEL-08172023-CAS/pg/reports
5. scp -i /root/ecs/alpha_key_pair.pem ec2-user@PublicIP:oscap/pg-rhel8-ami-spel-oscap-post.report.html .

# Expand and Resize disk and logical volumes
1. parted /dev/xvda u s p
* Select Fix and Note you need the start sector on partition 2 32768s
```
Warning: Not all of the space available to /dev/xvda appears to be used, you can fix the GPT to use all of the space (an extra 226492416 blocks) or continue with the current setting?
Fix/Ignore? Fix
Model: Xen Virtual Block Device (xvd)
Disk /dev/xvda: 268435456s
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End        Size       File system  Name     Flags
 1      2048s   32767s     30720s                  primary  bios_grub
 2      32768s  41940991s  41908224s               primary  lvm
```
2. parted /dev/xvda
* Select p for print, rm2 to remove the second partition, 
```
GNU Parted 3.2
Using /dev/xvda
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) p
Model: Xen Virtual Block Device (xvd)
Disk /dev/xvda: 137GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End     Size    File system  Name     Flags
 1      1049kB  16.8MB  15.7MB               primary  bios_grub
 2      16.8MB  21.5GB  21.5GB               primary  lvm

(parted) rm 2
Error: Partition(s) 2 on /dev/xvda have been written, but we have been unable to inform the kernel of the change, probably because it/they are in use.  As a result, the old partition(s) will remain in use.  You should reboot now before making further changes.
Ignore/Cancel? i
(parted) ^Z
[1]+  Stopped                 parted /dev/xvda
```
3. parted -s /dev/xvda mkpart primary 32768s 100%
* Note start sector from step 1 
4. vgdisplay
* Note that no space is added 
```
  --- Volume group ---
  VG Name               RootVG
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  8
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                7
  Open LV               6
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               19.98 GiB
  PE Size               4.00 MiB
  Total PE              5115
  Alloc PE / Size       5115 / 19.98 GiB
  Free  PE / Size       0 / 0
  VG UUID               A5X2j3-f1Ix-Hm43-f1O1-dRea-KLhh-aEcpJp
```
5. pvresize /dev/xvda2
6. vgdisplay
* Note there is now 108.00GiB of Free space
```
  --- Volume group ---
  VG Name               RootVG
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  9
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                7
  Open LV               6
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               127.98 GiB
  PE Size               4.00 MiB
  Total PE              32763
  Alloc PE / Size       5115 / 19.98 GiB
  Free  PE / Size       27648 / 108.00 GiB
  VG UUID               A5X2j3-f1Ix-Hm43-f1O1-dRea-KLhh-aEcpJp
```
7. lvscan
```
  ACTIVE            '/dev/RootVG/rootVol' [5.00 GiB] inherit
  ACTIVE            '/dev/RootVG/swapVol' [2.00 GiB] inherit
  ACTIVE            '/dev/RootVG/homeVol' [1.00 GiB] inherit
  ACTIVE            '/dev/RootVG/varVol' [2.00 GiB] inherit
  ACTIVE            '/dev/RootVG/varTmpVol' [2.00 GiB] inherit
  ACTIVE            '/dev/RootVG/logVol' [2.00 GiB] inherit
  ACTIVE            '/dev/RootVG/auditVol' [5.98 GiB] inherit
  ```
8. lvextend -r -L +15G /dev/RootVG/rootVol
* Note only putting the output of the first command for reference
```
  Size of logical volume RootVG/rootVol changed from 5.00 GiB (1280 extents) to 20.00 GiB (5120 extents).
  Logical volume RootVG/rootVol successfully resized.
meta-data=/dev/mapper/RootVG-rootVol isize=512    agcount=8, agsize=163840 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=0 inobtcount=0
data     =                       bsize=4096   blocks=1310720, imaxpct=25
         =                       sunit=1      swidth=1 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=1 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 1310720 to 5242880
```
9. lvextend -r -L +20G /dev/RootVG/homeVol
10. lvextend -r -L +20G /dev/RootVG/varVol
11. lvextend -r -L +5G /dev/RootVG/logVol
12. lvextend -r -L +5G /dev/RootVG/varTmpVol
13. lvscan
* Note the sizes are more appropriate now
```
  ACTIVE            '/dev/RootVG/rootVol' [20.00 GiB] inherit
  ACTIVE            '/dev/RootVG/swapVol' [2.00 GiB] inherit
  ACTIVE            '/dev/RootVG/homeVol' [21.00 GiB] inherit
  ACTIVE            '/dev/RootVG/varVol' [22.00 GiB] inherit
  ACTIVE            '/dev/RootVG/varTmpVol' [7.00 GiB] inherit
  ACTIVE            '/dev/RootVG/logVol' [7.00 GiB] inherit
  ACTIVE            '/dev/RootVG/auditVol' [5.98 GiB] inherit
```
# Manual STIG fixes
* Manual remediation 
# Configure second DNS 
1. nmtui > Edit a connection > System eth0 > IPv4 Configuration > DNS servers > Add 8.8.8.8 > OK 
2. systemctl restart NetworkManager
3. cat /etc/resolv.conf 
```
# Generated by NetworkManager
search us-gov-west-1.compute.internal
nameserver 8.8.8.8
nameserver 10.200.0.2
```
4. cat /etc/sysconfig/network-scripts/ifcfg-eth0
```
# Created by cloud-init on instance boot automatically, do not edit.
#
BOOTPROTO=dhcp
DEVICE=eth0
HWADDR=06:9F:16:EC:55:12
ONBOOT=yes
TYPE=Ethernet
USERCTL=no
PROXY_METHOD=none
BROWSER_ONLY=no
DNS1=8.8.8.8
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
NAME="System eth0"
UUID=5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03
```
# Set grub password 
* Password in secrets manager under pg_rhel8_stif_spel_grub
1. grub2-setpassword 
2. grub2-mkconfig
3. cat /boot/grub2/user.cfg
```
GRUB2_PASSWORD=grub.pbkdf2.sha512.10000.709C56C288AB880B5A54A7EC846969BD25A288AFD7379A5C58D8F7E421BB4345E02E6F04CF31AEAA142EDA34566BB5BD7F2955A9CF8611B4BAC58BF9E017C609.509FF4918192B73CD81C58218A530E6824DC8016EE0AE4A36338B8FCC3D34F4868593431331B8C7FBF913DC0BF5CD9081996E613A5EE8738631DE482624E45E0```
# Set Existing Passwords Minimum Age
1. chage -m 1 maintuser

# Fix Prevent user from disabling the screen lock
1. cd /root && vim scrnlock.sh 
```
# Remediation is applicable only in certain platforms
if [ ! -f /.dockerenv ] && [ ! -f /run/.containerenv ]; then

if grep -q 'tmux\s*$' /etc/shells ; then
	sed -i '/tmux\s*$/d' /etc/shells
fi

else
    >&2 echo 'Remediation is not applicable, nothing was done'
fi
```
2. chmod +x scrnlock.sh && ./scrnlock.sh 

# Log USBGuard daemon audit events using Linux Audit
1. cd /root && vim usbguard.sh
```
# Remediation is applicable only in certain platforms
if ! grep -q s390x /proc/sys/kernel/osrelease && { rpm --quiet -q usbguard; }; then

if [ -e "/etc/usbguard/usbguard-daemon.conf" ] ; then
    
    LC_ALL=C sed -i "/^\s*AuditBackend=/d" "/etc/usbguard/usbguard-daemon.conf"
else
    touch "/etc/usbguard/usbguard-daemon.conf"
fi
# make sure file has newline at the end
sed -i -e '$a\' "/etc/usbguard/usbguard-daemon.conf"

cp "/etc/usbguard/usbguard-daemon.conf" "/etc/usbguard/usbguard-daemon.conf.bak"
# Insert at the end of the file
printf '%s\n' "AuditBackend=LinuxAudit" >> "/etc/usbguard/usbguard-daemon.conf"
# Clean up after ourselves.
rm "/etc/usbguard/usbguard-daemon.conf.bak"

else
    >&2 echo 'Remediation is not applicable, nothing was done'
fi
```
2. chmod +x usbguard.sh && ./usbguard.sh

# Fix owners 
1. cd /home
2. chown -R ec2-user:ec2-user /home/ec2-user/
3. chown -R maintuser:maintuser /home/maintuser/
4. chown -R ssm-user:ssm-user /home/ssm-user/

# Fix bash history 
1. cp /etc/profile /etc/profile.08212023
2. vim /etc/profile
* Note add HISTFILESIZE=20000 and increase HISTSIZE=1000 to HISTSIZE=10000
```
HISTSIZE=10000
HISTFILESIZE=20000
```
3. source /etc/profile

# Fix chrony.conf 
1. cp /etc/chrony.conf /etc/chrony.conf.08212023
2. vim 
*
```
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
#pool 2.rhel.pool.ntp.org iburst maxpoll 16
server 10.197.132.68 iburst maxpoll 16
server 10.197.132.69 iburst maxpoll 16
server 10.197.132.74 iburst maxpoll 16
server 10.197.132.75 iburst maxpoll 16
server 10.78.208.52 iburst maxpoll 16
server 10.78.208.53 iburst maxpoll 16
server 10.78.208.56 iburst maxpoll 16
server 10.78.208.57 iburst maxpoll 16
server dsa.dhs iburst maxpoll 16


# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Enable hardware timestamping on all interfaces that support it.
#hwtimestamp *

# Increase the minimum number of selectable sources required to adjust
# the system clock.
#minsources 2

# Allow NTP client access from local network.
#allow 192.168.0.0/16

# Serve time even if not synchronized to a time source.
#local stratum 10

# Specify file containing keys for NTP authentication.
keyfile /etc/chrony.keys

# Get TAI-UTC offset and leap seconds from the system tz database.
leapsectz right/UTC

# Specify directory for log files.
logdir /var/log/chrony

# Select which information is logged.
#log measurements statistics tracking
port 0
cmdport 0
```
3. systemctl restart chronyd

# Fix ssm-user sudo 
1. cp /etc/sudoers.d/ssm-agent-users /etc/sudoers.d/ssm-agent-users.ORIG
2. vim /etc/sudoers.d/ssm-agent-users
```
# User rules for ssm-user
ssm-user ALL=(ALL) NOPASSWD:ALL
```

# Restrict Partition Mount Options
1. cp /etc/fstab /etc/fstab.08212023
2. vim /etc/fstab 
* Add ,noexec,nosuid to RootVG-homeVol  and RootVG-varVol
```
/dev/mapper/RootVG-rootVol /    xfs     defaults,rw     0 0
/dev/mapper/RootVG-homeVol /home xfs rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,sunit=8,swidth=8,noquota,nodev,noexec,nosuid 0 0
/dev/mapper/RootVG-varVol /var xfs rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,sunit=8,swidth=8,noquota,nodev,,noexec,nosuid 0 0
/dev/mapper/RootVG-logVol /var/log xfs rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,sunit=8,swidth=8,noquota,nodev,noexec,nosuid 0 0
/dev/mapper/RootVG-auditVol /var/log/audit xfs rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,sunit=8,swidth=8,noquota,nodev,noexec,nosuid 0 0
/dev/mapper/RootVG-varTmpVol /var/tmp xfs rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,sunit=8,swidth=8,noquota,nodev,noexec,nosuid 0 0
tmpfs /dev/shm tmpfs rw,nosuid,nodev,noexec,seclabel 0 0
```
3. fips-mode-setup --enable && reboot -f
* Enable FIPS mode and reboot 

# Post manual hardening [OSCAP Report](https://github.com/ChristopherSargent/ecs_rhel8_lvm_stig_spel_ami/tree/main/reports)
* Note the post manual hardening oscap score is 95%
1. cd /home/ec2-user/oscap
* Run oscap
```
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig --results-arf /home/ec2-user/oscap/pg-rhel8-ami-spel-oscap-post-manual.xml --report /home/ec2-user/oscap/pg-rhel8-ami-spel-oscap-post-manual.report.html --fetch-remote-resources --oval-results /usr/share/xml/scap/ssg/content/ssg-rhel8-ds-1.2.xml
```
3. chown -R ec2-user:ec2-user /home/ec2-user
4. exit && exit
4. mkdir RHEL8-LVM-STIG-SPEL-08172023-CAS/pg/reports && cd RHEL8-LVM-STIG-SPEL-08172023-CAS/pg/reports
5. scp -i /root/ecs/alpha_key_pair.pem ec2-user@PublicIP:oscap/pg-rhel8-ami-spel-oscap-post-manual.report.html .
