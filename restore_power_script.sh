#!/bin/bash
echo "Restoring system to normal settings..."

# --- Enable all CPU cores ---
echo "[CPU] Enabling all CPU cores..."
for core in /sys/devices/system/cpu/cpu*/online; do
    echo 1 > $core 2>/dev/null
done

# Restore CPU frequency and turbo mode
cpupower frequency-set -d 0 -u 0 --governor performance
echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo

# --- Re-enable KDE Power Manager ---
echo "[Power Manager] Enabling KDE Power Management..."
systemctl start powerdevil.service

# --- Restore memory settings ---
echo "[RAM] Restoring memory settings..."
echo "madvise" > /sys/kernel/mm/transparent_hugepage/enabled
echo 60 > /proc/sys/vm/swappiness
echo 100 > /proc/sys/vm/vfs_cache_pressure

# --- Restore storage settings ---
echo "[Storage] Re-enabling storage devices..."
for disk in /dev/sd*; do
    hdparm -B 254 -S 0 $disk 2>/dev/null
    hdparm -M 254 $disk 2>/dev/null
done

# --- Enable network interfaces ---
echo "[Network] Re-enabling network interfaces..."
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
echo "[USB] Re-enabling USB ports..."
for host in /sys/bus/usb/devices/usb*/power/control; do
    echo "on" > $host
done
systemctl restart systemd-udevd.service

# --- Restart stopped services ---
echo "[Services] Restarting system services..."
systemctl daemon-reload
systemctl restart bluetooth.service
systemctl restart cups.service
systemctl restart avahi-daemon.service

# --- Remove kernel power-saving settings ---
echo "[Kernel] Removing kernel power-saving settings..."
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

# --- Restore fan and thermal settings ---
echo "[Thermal] Restoring thermal settings..."
for fan in /sys/class/hwmon/hwmon*/fan*_enable; do
    echo 4 > $fan 2>/dev/null  # Auto mode
done

# --- Re-enable power management tools ---
echo "[Tools] Re-enabling power management tools..."
powertop --auto-tune &>/dev/null
tlp start &>/dev/null
cpupower idle-set -D &>/dev/null

echo "System restored to normal settings!"
echo "Note: Some changes may require a reboot to fully apply."
