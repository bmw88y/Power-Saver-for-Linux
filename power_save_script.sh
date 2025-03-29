#!/bin/bash

echo "Activating extreme power-saving mode (1000x)..."

# --- Advanced CPU control ---
echo "[CPU] Maximizing power saving..."
max_core=$(($(nproc)/2))  # Keep only half of the cores
for core in $(seq $max_core $(($(nproc)-1))); do
    echo 0 > /sys/devices/system/cpu/cpu$core/online
done

cpupower frequency-set -d 800MHz -u 800MHz --governor powersave
echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo

# --- Memory and swap management ---
echo "[RAM] Optimizing memory management..."
echo "force" > /sys/kernel/mm/transparent_hugepage/enabled
echo 10 > /proc/sys/vm/swappiness
echo 50 > /proc/sys/vm/vfs_cache_pressure

# --- Storage power control ---
echo "[Storage] Fully shutting down disks..."
for disk in /dev/sd*; do
    hdparm -B 1 -S 1 $disk 2>/dev/null
    hdparm -Y $disk 2>/dev/null
done

# --- Network power control ---
echo "[Network] Fully disabling interfaces..."
interfaces=($(ip -o link show | awk -F': ' '{print $2}'))
for iface in "${interfaces[@]}"; do
    case $iface in
        lo) continue;;
        *)  ip link set $iface down
            rfkill block ${iface}
            ;;
    esac
done

# --- Display power management ---
echo "[Display] Turning off display completely..."
vga_off() {
    for console in /sys/class/vtconsole/*; do
        echo 0 > $console/bind
    done
    echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind
}
vga_off 2>/dev/null

# --- USB and Bluetooth power management ---
echo "[USB] Fully removing all devices..."
for host in /sys/bus/usb/devices/usb*; do
    echo "0" > $host/authorized
    echo "suspend" > $host/power/level
done

# --- System service management ---
echo "[Services] Stopping all non-essential services..."
essential_services=(
    "systemd-journald"
    "dbus"
    "systemd-logind"
    "systemd-udevd"
)
for service in $(systemctl list-units --type=service --no-legend | awk '{print $1}'); do
    [[ " ${essential_services[@]} " =~ " $service " ]] || systemctl stop $service
done

# --- Kernel-level power control ---
echo "[Kernel] Applying kernel power settings..."
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

# --- Extreme environmental control ---
echo "[Env] External power optimizations..."
for fan in /sys/class/hwmon/hwmon*/fan*_enable; do
    echo 0 > $fan 2>/dev/null
done

for temp in /sys/class/thermal/thermal_zone*/trip_point_*_temp; do
    echo 1 > ${temp/_temp/_hyst}
    echo 5000 > $temp
done

# --- Advanced power management tools ---
echo "[Tools] Running advanced power tools..."
powertop --auto-tune &>/dev/null
tlp bat &>/dev/null
cpupower idle-set -E &>/dev/null

echo "Extreme power-saving mode activated!"
echo "Warning: This may affect system stability and performance!"
