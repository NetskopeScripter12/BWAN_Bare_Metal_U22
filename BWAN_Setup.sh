#!/bin/bash

# --- 0. Root Check ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please run: sudo ./BWAN_Setup.sh"
   exit 1
fi

echo "=========================================="
echo "    Netskope Automated BWAN Wizard        "
echo "  By: Jordan Warren - ES Cyber Solutions  "
echo "=========================================="

# User Variable Input
read -p "Enter the physical network interface to bridge (e.g., ens160, enp0s3): " PHY_IFACE
read -p "Enter the static IP for the bridge (e.g., 192.168.0.146/24): " BR_IP
read -p "Enter the default gateway (e.g., 192.168.0.1): " BR_GW
read -p "Enter the DNS servers (comma separated, e.g., 8.8.8.8, 1.1.1.1): " BR_DNS
read -p "Enter the Netplan filename to create (e.g., 01-netcfg.yaml): " NETPLAN_FILE

# Ensures that normal user is being used, despite being in Superuser
REAL_USER=${SUDO_USER:-$(whoami)}

echo ""
echo "Starting spinning..."

# System Update 
apt update -y

# KVM Check
VIRT_CHECK=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ "$VIRT_CHECK" -eq 0 ]; then
    echo "ERROR: Virtualization is not supported or enabled in the BIOS/Hypervisor."
    exit 1
fi
echo "Virtualization check passed."

# Install Dependencies
apt install -y qemu-kvm virt-manager libvirt-daemon-system libvirt-clients bridge-utils virtinst ovmf ifenslave nano

# Enable Libvirt
systemctl enable --now libvirtd
systemctl start libvirtd

# Add "real" User to Groups
usermod -aG kvm "$REAL_USER"
usermod -aG libvirt "$REAL_USER"

# Create Netplan YAML
cat <<EOF > /etc/netplan/$NETPLAN_FILE
network:
  version: 2
  ethernets:
    $PHY_IFACE:
      dhcp4: false
  # add configuration for bridge interface
  bridges:
    br0:
      interfaces: [$PHY_IFACE]
      dhcp4: false
      addresses: [$BR_IP]
      routes:
        - to: default
          via: $BR_GW
      nameservers:
        addresses: [$BR_DNS]
EOF

# Apply Netplan
netplan apply

echo "Waiting for network bridge to initialize..."
sleep 60

mkdir -p /home/infiot/kvm
cd /home/infiot/kvm/

# Download BWAN Image
IMAGE_URL="https://storage.googleapis.com/infiotimagesdev/user-pramode-elsa-kvm-performance/fc15e46/fc15e46-infiot-amd64-vmdk-diskimage.qcow2"
wget -O fc15e46-infiot-amd64-vmdk-diskimage.qcow2 "$IMAGE_URL"

# Set Ownership and eXecutable
chown libvirt-qemu:kvm /home/infiot/kvm/fc15e46-infiot-amd64-vmdk-diskimage.qcow2
chmod 664 /home/infiot/kvm/fc15e46-infiot-amd64-vmdk-diskimage.qcow2

# AppArmor Fix
# rule duplication checker
if ! grep -q "/home/infiot/kvm/\*\* rwk," /etc/apparmor.d/libvirt/TEMPLATE.qemu; then
    sed -i '/^}/i \  /home/infiot/kvm/** rwk,' /etc/apparmor.d/libvirt/TEMPLATE.qemu
    systemctl restart apparmor
fi

# Create edge.xml
cat <<EOF > /home/infiot/kvm/edge.xml
<domain type='kvm' id='50'>
   <name>edge2</name>
   <memory unit='MB'>8192</memory>
   <currentMemory unit='MB'>8192</currentMemory>
   <vcpu placement='static'>4</vcpu>
   <resource>
     <partition>/machine</partition>
   </resource>
   <os>
     <type arch='x86_64' machine='pc-i440fx-bionic'>hvm</type>
     <loader type='rom'>/usr/share/ovmf/OVMF.fd</loader>
     <boot dev='hd'/>
   </os>
   <features>
     <acpi/>
     <apic/>
   </features>
   <cpu mode='host-passthrough'>
   </cpu>
   <clock offset='utc'>
     <timer name='rtc' tickpolicy='catchup'/>
     <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
   </clock>
   <on_poweroff>destroy</on_poweroff>
   <on_reboot>restart</on_reboot>
   <on_crash>destroy</on_crash>
   <pm>
     <suspend-to-mem enabled='no'/>
     <suspend-to-disk enabled='no'/>
   </pm>
   <devices>
     <emulator>/usr/bin/qemu-system-x86_64</emulator>
     <disk type='file' device='disk'>
       <driver name='qemu' type='qcow2' discard='unmap'/>
       <source file='/home/infiot/kvm/fc15e46-infiot-amd64-vmdk-diskimage.qcow2'/>
       <target dev='vda' bus='virtio'/>
       <alias name='virtio-disk0'/>
     </disk>
     <interface type='bridge'>
       <source bridge='br0'/>
       <target dev='vnet0'/>
       <model type='virtio'/>
       <alias name='net0'/>
       <address type='pci' domain='0x0000' bus='0x02' slot='0x01' function='0x0'/>
     </interface>
     <serial type='pty'>
       <source path='/dev/pts/2'/>
       <target type='isa-serial' port='0'>
         <model name='isa-serial'/>
       </target>
       <alias name='serial0'/>
     </serial>
     <console type='pty' tty='/dev/pts/2'>
       <source path='/dev/pts/2'/>
       <target type='serial' port='0'/>
       <alias name='serial0'/>
     </console>
    <graphics type='vnc' port='9010' autoport='no' listen='0.0.0.0'>
       <listen type='address' address='0.0.0.0'/>
     </graphics>
     <memballoon model='virtio'>
       <alias name='balloon0'/>
       <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
     </memballoon>
   </devices>
</domain>
EOF

# Define and Start VM as the non-sudo user
su - "$REAL_USER" -c "virsh --connect qemu:///system define /home/infiot/kvm/edge.xml"
su - "$REAL_USER" -c "virsh --connect qemu:///system start edge2"

# Set default virsh URI for the user so they do not need to use sudo to see the VM
su - "$REAL_USER" -c "grep -q 'LIBVIRT_DEFAULT_URI' ~/.bashrc || echo \"export LIBVIRT_DEFAULT_URI='qemu:///system'\" >> ~/.bashrc"

PUBLIC_IP=$(curl -s -4 ifconfig.me)

echo ""
echo "=========================================="
echo "            SETUP COMPLETE!               "
echo "=========================================="
echo "Your Edge2 VM has been created and started."
echo "Bridge Internal IP : $BR_IP"
echo "Server Public IP   : $PUBLIC_IP"
echo ""
echo ">>> NEXT STEPS <<<"
echo "1. Download a VNC Viewer (like RealVNC or TightVNC) on your local machine."
echo "2. Connect to the VM using the server's IP address and Port 9010."
echo "   Format: $PUBLIC_IP:9010"
echo "=========================================="
echo "Switching to your fully configured environment now..."

# The magic handoff: Instantly drops the user into a fresh shell with all new permissions loaded
exec su - "$REAL_USER"
