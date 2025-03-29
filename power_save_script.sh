#!/bin/bash
echo "تفعيل الوضع الإنهائي لتوفير الطاقة (1000x)..."

# ------ التحكم المتقدم بالمعالج ------
echo "[CPU] تعظيم توفير الطاقة..."
# تعطيل النوى الإضافية (الفيزيائية والمنطقية)
max_core=$(($(nproc)/2))  # إبقاء نصف النوى فقط
for core in $(seq $max_core $(($(nproc)-1))); do
    echo 0 > /sys/devices/system/cpu/cpu$core/online
done

# إجبار أدنى تردد ممكن مع تعطيل التوربو
cpupower frequency-set -d 800MHz -u 800MHz --governor powersave
echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo

# ------ إدارة الذاكرة والتبديل ------
echo "[RAM] تحسين إدارة الذاكرة..."
echo "force" > /sys/kernel/mm/transparent_hugepage/enabled
echo 10 > /proc/sys/vm/swappiness
echo 50 > /proc/sys/vm/vfs_cache_pressure

# ------ التحكم بالطاقة للعتاد الصلب ------
echo "[Storage] الإغلاق التام للأقراص..."
for disk in /dev/sd*; do
    hdparm -B 1 -S 1 $disk 2>/dev/null
    hdparm -Y $disk 2>/dev/null
done

# ------ التحكم المتقدم بالشبكة ------
echo "[Network] الإغلاق الكامل للواجهات..."
interfaces=($(ip -o link show | awk -F': ' '{print $2}'))
for iface in "${interfaces[@]}"; do
    case $iface in
        lo) continue;;
        *)  ip link set $iface down
            rfkill block ${iface}
            ;;
    esac
done

# ------ إدارة الطاقة المتقدمة للشاشة ------
echo "[Display] إيقاف العرض تماماً..."
vga_off() {
    for console in /sys/class/vtconsole/*; do
        echo 0 > $console/bind
    done
    echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind
}
vga_off 2>/dev/null

# ------ إدارة الطاقة للـ USB والبلوتوث ------
echo "[USB] إزالة كاملة لجميع الأجهزة..."
for host in /sys/bus/usb/devices/usb*; do
    echo "0" > $host/authorized
    echo "suspend" > $host/power/level
done

# ------ إدارة الخدمات النظامية ------
echo "[Services] إيقاف جميع الخدمات غير الحاسوبية..."
essential_services=(
    "systemd-journald"
    "dbus"
    "systemd-logind"
    "systemd-udevd"
)
for service in $(systemctl list-units --type=service --no-legend | awk '{print $1}'); do
    [[ " ${essential_services[@]} " =~ " $service " ]] || systemctl stop $service
done

# ------ التحكم بالطاقة على مستوى النواة ------
echo "[Kernel] تفعيل الإعدادات النووية..."
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

# ------ التحكم البيئي المتطرف ------
echo "[Env] تحسينات الطاقة الخارجية..."
# إيقاف جميع المراوح
for fan in /sys/class/hwmon/hwmon*/fan*_enable; do
    echo 0 > $fan 2>/dev/null
done

# خفض حرارة المعالج القصوى
for temp in /sys/class/thermal/thermal_zone*/trip_point_*_temp; do
    echo 1 > ${temp/_temp/_hyst}
    echo 5000 > $temp
done

# ------ أدوات إدارة الطاقة المتقدمة ------
echo "[Tools] تشغيل أدوات الطاقة المتطورة..."
powertop --auto-tune &>/dev/null
tlp bat &>/dev/null
cpupower idle-set -E &>/dev/null

echo "تم تفعيل الوضع الإنهائي لتوفير الطاقة!"
echo "تحذير: قد يؤثر هذا على استقرار النظام وأدائه!"
