#!/bin/bash
echo "استعادة الإعدادات الأصلية للنظام..."

# ------ تفعيل جميع نوى المعالج ------
echo "[CPU] إعادة تفعيل جميع النوى..."
for core in /sys/devices/system/cpu/cpu*/online; do
    echo 1 > $core 2>/dev/null
done

# إعادة ضبط تردد المعالج
cpupower frequency-set -d 0 -u 0 --governor performance
echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo

# ------ إعدادات الذاكرة الأصلية ------
echo "[RAM] استعادة إعدادات الذاكرة..."
echo "madvise" > /sys/kernel/mm/transparent_hugepage/enabled
echo 60 > /proc/sys/vm/swappiness
echo 100 > /proc/sys/vm/vfs_cache_pressure

# ------ إعادة ضبط التخزين ------
echo "[Storage] تفعيل الأقراص الصلبة..."
for disk in /dev/sd*; do
    hdparm -B 254 -S 0 $disk 2>/dev/null
    hdparm -M 254 $disk 2>/dev/null
done

# ------ تفعيل واجهات الشبكة ------
echo "[Network] إعادة تشغيل الشبكات..."
interfaces=($(ip -o link show | awk -F': ' '{print $2}'))
for iface in "${interfaces[@]}"; do
    ip link set $iface up
    rfkill unblock ${iface}
done

# ------ إعادة ضبط الشاشة ------
echo "[Display] استعادة إعدادات العرض..."
for console in /sys/class/vtconsole/*; do
    echo 1 > $console/bind 2>/dev/null
done
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind 2>/dev/null

# ------ تفعيل منافذ USB ------
echo "[USB] إعادة تفعيل المنافذ..."
for host in /sys/bus/usb/devices/usb*/power/control; do
    echo "on" > $host
done
systemctl restart systemd-udevd.service

# ------ إعادة تشغيل الخدمات ------
echo "[Services] إعادة جميع الخدمات..."
systemctl daemon-reload
systemctl start $(systemctl list-units --type=service --all --no-legend | awk '{print $1}') 2>/dev/null

# ------ إزالة تعديلات النواة ------
echo "[Kernel] استعادة إعدادات النواة..."
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

# ------ التحكم الحراري ------
echo "[Thermal] استعادة إدارة الحرارة..."
for fan in /sys/class/hwmon/hwmon*/fan*_enable; do
    echo 4 > $fan 2>/dev/null  # وضع التلقائي
done

# ------ إيقاف أدوات الطاقة ------
echo "[Tools] إيقاف أدوات الطاقة..."
powertop --auto-tune &>/dev/null
tlp ac &>/dev/null
cpupower idle-set -D &>/dev/null

echo "تم استعادة الإعدادات بنجاح!"
echo "ملاحظة: قد تحتاج لإعادة التشغيل لتفعيل بعض الإعدادات."
