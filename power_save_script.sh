#!/bin/bash
echo "Activating extreme power-saving mode..."

# --- Limit CPU usage to 25% ---
echo "[CPU] Limiting CPU usage to 25%..."
total_cores=$(nproc)
active_cores=$(($total_cores / 4))
for core in /sys/devices/system/cpu/cpu*/online; do
    echo 0 > $core 2>/dev/null
done
for core in $(seq 0 $(($active_cores - 1))); do
    echo 1 > /sys/devices/system/cpu/cpu$core/online 2>/dev/null
done

# Reduce CPU frequency and disable turbo
cpupower frequency-set -d 800MHz -u 800MHz --governor powersave
echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo

# --- Disable KDE Power Manager ---
echo "[Power Manager] Disabling KDE Power Management..."
systemctl stop powerdevil.service

# --- Optimize RAM settings ---
echo "[RAM] Optimizing memory management..."
echo "force" > /sys/kernel/mm/transparent_hugepage/enabled
echo 10 > /proc/sys/vm/swappiness
echo 50 > /proc/sys/vm/vfs_cache_pressure

# --- Reduce power usage of storage devices ---
echo "[Storage] Powering down disks..."
for disk in /dev/sd*; do
    hdparm -B 1 -S 1 $disk 2>/dev/null
    hdparm -Y $disk 2>/dev/null
done

# --- Disable network interfaces ---
echo "[Network] Disabling network interfaces..."
interfaces=($(ip -o link show | awk -F': ' '{print $2}'))
for iface in "${interfaces[@]}"; do
    [[ "$iface" == "lo" ]] && continue
    ip link set $iface down
    rfkill block ${iface}
done

# --- Turn off display ---
echo "[Display] Turning off display..."
vga_off() {
    for console in /sys/class/vtconsole/*; do
        echo 0 > $console/bind
    done
    echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind
}
vga_off 2>/dev/null

# --- Disable USB ports ---
echo "[USB] Disabling all USB devices..."
for host in /sys/bus/usb/devices/usb*; do
    echo "0" > $host/authorized
    echo "suspend" > $host/power/level
done

# --- Stop unnecessary services ---
echo "[Services] Stopping non-essential services..."
systemctl stop bluetooth.service
systemctl stop cups.service
systemctl stop avahi-daemon.service

# --- Apply kernel power-saving settings ---
echo "[Kernel] Enabling extreme kernel power-saving settings..."
kernel_params=(
    "consoleblank=5"
    "processor.max_cstate=5"
    "intel_idle.max_cstate=5"
    "nvme.noacpi=1"
    "pcie_aspm=force"
)
for param in "${kernel_params[@]}"; do
    grubby --update-kernel=ALL --args="$param"
done

# --- Stop fans and limit thermal settings ---
echo "[Thermal] Reducing thermal limits..."
for fan in /sys/class/hwmon/hwmon*/fan*_enable; do
    echo 0 > $fan 2>/dev/null
done
for temp in /sys/class/thermal/thermal_zone*/trip_point_*_temp; do
    echo 5000 > $temp
done

# --- Enable additional power-saving tools ---
echo "[Tools] Enabling additional power-saving tools..."
powertop --auto-tune &>/dev/null
tlp bat &>/dev/null
cpupower idle-set -E &>/dev/null

echo "Extreme power-saving mode activated!"
echo "Warning: This may affect system stability and performance."
