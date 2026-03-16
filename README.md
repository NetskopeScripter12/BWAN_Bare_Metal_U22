# BWAN_Bare_Metal_U22
This is an automated script to set up BWAN Baremetal on Ubuntu 22. 
**THIS SCRIPT IS IN ALPHA TESTING. YOU ASSUME ALL RISK WITHOUT WARRANTY FOR USE. Changing, altering, or deleting the author's name is prohibited. Script has no official affiliation with Netskope; all rights reserved.**


# Prerequisites
 - Machine ***MUST*** support Virtulization
 - Must be using Ubuntu 22.4 or 18
 - Must have KVM installed, see (https://linuxgenie.net/how-to-install-kvm-on-ubuntu-22-04/) for Ubuntu 22.04 and (https://linuxize.com/post/how-to-install-kvm-on-ubuntu-18-04/) for Ubuntu 18.04
 - 4 vCPUs
 - 8MB RAM
 - <60GB Storage
 - Internet connectivity
 - ***OPTIONAL*** Install OpenSSH & PuTTY if you are in an environment without copy and paste

# Instructions:
1) Clone the repository via git clone
```bash
git clone https://github.com/NetskopeScripter12/BWAN_Bare_Metal_U22.git
```
2) Once installed, cd into the BWAN_BARE_METAL_U22 directory
```bash
cd BWAN_Bare_Metal_U22
```
3) Make the script executable
```bash
sudo chmod 755 BWAN_Setup.sh
```
4) Run the following commands and take note of the following:
   - IP Address (CIDR)
   - Default Gateway
   - Physical Network Interface Name
   - Name of Netplan Config File (.yaml)
```bash
ip a
ls -l /etc/netplan/
```

5) Execute the script in sudouser
```bash
sudo ./BWAN_Setup.sh
```
***NOTE***: If you receive an interpreter error, run the following command to normalize translation
```bash
sed -i 's/\r//' BWAN_Setup.sh
```
6) Follow on-screen prompts and wait for completion
7) Install TightVNC (https://www.tightvnc.com/download.php)
8) Open TightVNC and enter in [IP_Address]::9010
9) Gateway is fully operational and ready for configuration!
