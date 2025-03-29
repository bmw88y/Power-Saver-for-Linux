#!/bin/bash

echo "Restoring system default settings..."

# --- Enable all CPU cores ---
echo "[CPU] Reactivating all cores..."
for core in /sys/devices/system/cpu/cpu*/online; do
    echo 1 > $core 2>/dev/null
done

# Reset CPU frequency
cpupower frequency-set -d 0 -u 0 --governor performance
echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo

# --- Restore memory settings ---
echo "[RAM] Restoring memory settings..."
echo "madvise" > /sys/kernel/mm/transparent_hugepage/enabled
echo 60 > /proc/sys/vm/swappiness
echo 100 > /proc/sys/vm/vfs_cache_pressure

# --- Reset storage settings ---
echo "[Storage] Enabling hard drives..."
for disk in /dev/sd*; do
    hdparm -B 254 -S 0 $disk 2>/dev/null
    hdparm -M 254 $disk 2>/dev/null
done

# --- Enable network interfaces ---
echo "[Network] Restarting network interfaces..."
interfaces=($(ip -o link show | awk -F': ' '{print $2}'))
for iface in "${interfaces[@]}"; do
    ip link set $iface up
    rfkill unblock ${iface}
done

# --- Restore display settings ---
echo "[Display] Restoring display settings..."
for console in /sys/class/vtconsole/*; do
    echo 1 > $console/bind 2>/dev/null
done
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind 2>/dev/null

# --- Enable USB ports ---
echo "[USB] Reactivating USB ports..."
for host in /sys/bus/usb/devices/usb*/power/control; do
    echo "on" > $host
done
systemctl restart systemd-udevd.service

# --- Restart services ---
echo "[Services] Restarting all services..."
systemctl daemon-reload
systemctl start $(systemctl list-units --type=service --all --no-legend | awk '{print $1}') 2>/dev/null

# --- Remove kernel modifications ---
echo "[Kernel] Restoring kernel settings..."
kernel_params=(
    "consoleblank"
    "processor.max_cstate"
    "intel_idle.max_cstate"
    "nvme.noacpi"
    "pcie_aspm"
)
for param in "${kernel_params[@]}"; do
    grubby --update-kernel=ALL --remove-args="$param"
done

# --- Restore thermal management ---
echo "[Thermal] Restoring thermal management..."
for fan in /sys/class/hwmon/hwmon*/fan*_enable; do
    echo 4 > $fan 2>/dev/null  # Auto mode
done

# --- Disable power management tools ---
echo "[Tools] Disabling power management tools..."
powertop --auto-tune &>/dev/null
tlp ac &>/dev/null
cpupower idle-set -D &>/dev/null

echo "System settings successfully restored!"
echo "Note: A restart may be required for some settings to take effect."