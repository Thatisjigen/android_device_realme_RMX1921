#! /vendor/bin/sh

# Copyright (c) 2012-2013, 2016-2019, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

target=`getprop ro.board.platform`

function configure_zram_parameters() {
    MemTotalStr=`cat /proc/meminfo | grep MemTotal`
    MemTotal=${MemTotalStr:16:8}

    low_ram=`getprop ro.config.low_ram`

    # Zram disk - 75% for Go devices.
    # For 512MB Go device, size = 384MB, set same for Non-Go.
    # For 1GB Go device, size = 768MB, set same for Non-Go.
    # For >1GB and <=3GB Non-Go device, size = 1GB
    # For >3GB and <=4GB Non-Go device, size = 2GB
    # For >4GB Non-Go device, size = 4GB
    # And enable lz4 zram compression for Go targets.

    if [ "$low_ram" == "true" ]; then
        echo lz4 > /sys/block/zram0/comp_algorithm
    fi

#ifdef VENDOR_EDIT
#//Huacai.Zhou@PSW.Kernel.mm,2018-12-06, Modify for config zramsize according to ramsize
    if [ -f /sys/block/zram0/disksize ]; then
        if [ -f /sys/block/zram0/use_dedup ]; then
            echo 1 > /sys/block/zram0/use_dedup
        fi
        if [ $MemTotal -le 4194304 ]; then
            #config 2GB+512MB zram size with memory 4 GB
            echo lz4 > /sys/block/zram0/comp_algorithm
            echo 2684354560 > /sys/block/zram0/disksize
            echo 160 > /proc/sys/vm/swappiness
            echo 60 > /proc/sys/vm/direct_swappiness
        elif [ $MemTotal -le 6291456 ]; then
            #config 2GB+512M zram size with memory 6 GB
            echo lz4 > /sys/block/zram0/comp_algorithm
            echo 2684354560 > /sys/block/zram0/disksize
            echo 160 > /proc/sys/vm/swappiness
            echo 60 > /proc/sys/vm/direct_swappiness
        else
            #Kui.Zhang@PSW.Kernel.Performance, 2019/02/18
            #config 2GB+192M zram size with memory 8 GB
            echo lz4 > /sys/block/zram0/comp_algorithm
            echo 2348810240 > /sys/block/zram0/disksize
            echo 160 > /proc/sys/vm/swappiness
            echo 60 > /proc/sys/vm/direct_swappiness
        fi
#endif /*VENDOR_EDIT*/
        mkswap /dev/block/zram0
        swapon /dev/block/zram0 -p 32758
    fi
}

function configure_read_ahead_kb_values() {
    MemTotalStr=`cat /proc/meminfo | grep MemTotal`
    MemTotal=${MemTotalStr:16:8}

        echo 512 > /sys/block/mmcblk0/bdi/read_ahead_kb
        echo 512 > /sys/block/mmcblk0/queue/read_ahead_kb
        echo 512 > /sys/block/mmcblk0rpmb/bdi/read_ahead_kb
        echo 512 > /sys/block/mmcblk0rpmb/queue/read_ahead_kb
        echo 512 > /sys/block/dm-0/queue/read_ahead_kb
        echo 512 > /sys/block/dm-1/queue/read_ahead_kb
        echo 512 > /sys/block/dm-2/queue/read_ahead_kb
}

function disable_core_ctl() {
    if [ -f /sys/devices/system/cpu/cpu0/core_ctl/enable ]; then
        echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable
    else
        echo 1 > /sys/devices/system/cpu/cpu0/core_ctl/disable
    fi
}

function enable_swap() {
    MemTotalStr=`cat /proc/meminfo | grep MemTotal`
    MemTotal=${MemTotalStr:16:8}

    SWAP_ENABLE_THRESHOLD=1048576
    swap_enable=`getprop ro.vendor.qti.config.swap`

    # Enable swap initially only for 1 GB targets
    if [ "$MemTotal" -le "$SWAP_ENABLE_THRESHOLD" ] && [ "$swap_enable" == "true" ]; then
        # Static swiftness
        echo 1 > /proc/sys/vm/swap_ratio_enable
        echo 70 > /proc/sys/vm/swap_ratio

        # Swap disk - 200MB size
        if [ ! -f /data/vendor/swap/swapfile ]; then
            dd if=/dev/zero of=/data/vendor/swap/swapfile bs=1m count=200
        fi
        mkswap /data/vendor/swap/swapfile
        swapon /data/vendor/swap/swapfile -p 32758
    fi
}

function configure_memory_parameters() {
    # Set Memory parameters.
    #
    # Set per_process_reclaim tuning parameters
    # All targets will use vmpressure range 50-70,
    # All targets will use 512 pages swap size.
    #
    # Set Low memory killer minfree parameters
    # 32 bit Non-Go, all memory configurations will use 15K series
    # 32 bit Go, all memory configurations will use uLMK + Memcg
    # 64 bit will use Google default LMK series.
    #
    # Set ALMK parameters (usually above the highest minfree values)
    # vmpressure_file_min threshold is always set slightly higher
    # than LMK minfree's last bin value for all targets. It is calculated as
    # vmpressure_file_min = (last bin - second last bin ) + last bin
    #
    # Set allocstall_threshold to 0 for all targets.
    #

ProductName=`getprop ro.product.name`
low_ram=`getprop ro.config.low_ram`

        MemTotalStr=`cat /proc/meminfo | grep MemTotal`
        MemTotal=${MemTotalStr:16:8}

        # Set PPR parameters
        if [ -f /sys/devices/soc0/soc_id ]; then
            soc_id=`cat /sys/devices/soc0/soc_id`
        else
            soc_id=`cat /sys/devices/system/soc/soc0/id`
        fi

        case "$soc_id" in
          # Do not set PPR parameters for premium targets
          # sdm845 - 321, 341
          # msm8998 - 292, 319
          # msm8996 - 246, 291, 305, 312
          "321" | "341" | "292" | "319" | "246" | "291" | "305" | "312")
            ;;
          *)
            #Set PPR parameters for all other targets.
            echo $set_almk_ppr_adj > /sys/module/process_reclaim/parameters/min_score_adj
            echo 1 > /sys/module/process_reclaim/parameters/enable_process_reclaim
            echo 50 > /sys/module/process_reclaim/parameters/pressure_min
            echo 70 > /sys/module/process_reclaim/parameters/pressure_max
            echo 30 > /sys/module/process_reclaim/parameters/swap_opt_eff
            echo 512 > /sys/module/process_reclaim/parameters/per_swap_size
            ;;
        esac

    # Set allocstall_threshold to 0 for all targets.
    # Set swappiness to 100 for all targets
    echo 0 > /sys/module/vmpressure/parameters/allocstall_threshold
    echo 100 > /proc/sys/vm/swappiness

    # Disable wsf for all targets beacause we are using efk.
    # wsf Range : 1..1000 So set to bare minimum value 1.
    echo 1 > /proc/sys/vm/watermark_scale_factor

    configure_zram_parameters

    configure_read_ahead_kb_values

    enable_swap
}

#Apply settings for sdm710
# Set the default IRQ affinity to the silver cluster. When a
# CPU is isolated/hotplugged, the IRQ affinity is adjusted
# to one of the CPU from the default IRQ affinity mask.
echo 3f > /proc/irq/default_smp_affinity

# Core control parameters on silver
echo 0 0 0 0 1 1 > /sys/devices/system/cpu/cpu0/core_ctl/not_preferred
echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus
echo 60 > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
echo 40 > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
echo 100 > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/is_big_cluster
echo 8 > /sys/devices/system/cpu/cpu0/core_ctl/task_thres

# Setting b.L scheduler parameters
echo 96 > /proc/sys/kernel/sched_upmigrate
echo 90 > /proc/sys/kernel/sched_downmigrate
echo 140 > /proc/sys/kernel/sched_group_upmigrate
echo 120 > /proc/sys/kernel/sched_group_downmigrate
echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

# configure governor settings for little cluster
echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/rate_limit_us
echo 1209600 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
echo 576000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

# Setup schedutil ratelimits
echo 500 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
echo 20000 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us

# Enable schedutil predicted-load boosting
echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/pl

# configure governor settings for big cluster
echo "schedutil" > /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor
echo 0 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/rate_limit_us
echo 1344000 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/hispeed_freq
echo 652800 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_min_freq

# Setup schedutil ratelimits
echo 500 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/up_rate_limit_us
echo 20000 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/down_rate_limit_us

# Enable schedutil predicted-load boosting
echo 1 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/pl

# sched_load_boost as -6 is equivalent to target load as 85. It is per cpu tunable.
echo -6 >  /sys/devices/system/cpu/cpu6/sched_load_boost
echo -6 >  /sys/devices/system/cpu/cpu7/sched_load_boost
echo 85 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/hispeed_load

echo "0:1209600" > /sys/module/cpu_boost/parameters/input_boost_freq
echo 40 > /sys/module/cpu_boost/parameters/input_boost_ms

# Copy camera firmware files
mkdir -p /data/vendor/camera
cp /vendor/etc/data/camera/aecWarmStartCamera_0.txt /data/vendor/camera/aecWarmStartCamera_0.txt
cp /vendor/etc/data/camera/aecWarmStartCamera_1.txt /data/vendor/camera/aecWarmStartCamera_1.txt
cp /vendor/etc/data/camera/aecWarmStartCamera_2.txt /data/vendor/camera/aecWarmStartCamera_2.txt
cp /vendor/etc/data/camera/aecWarmStartCamera_3.txt /data/vendor/camera/aecWarmStartCamera_3.txt
cp /vendor/etc/data/camera/af_calibration_s5kgw1_p24c128e_sunny.bin /data/vendor/camera/af_calibration_s5kgw1_p24c128e_sunny.bin
cp /vendor/etc/data/camera/awbWarmStartCamera_0.txt /data/vendor/camera/awbWarmStartCamera_0.txt
cp /vendor/etc/data/camera/awbWarmStartCamera_1.txt /data/vendor/camera/awbWarmStartCamera_1.txt
cp /vendor/etc/data/camera/awbWarmStartCamera_2.txt /data/vendor/camera/awbWarmStartCamera_2.txt
cp /vendor/etc/data/camera/awbWarmStartCamera_3.txt /data/vendor/camera/awbWarmStartCamera_3.txt
cp /vendor/etc/data/camera/mapx.bin /data/vendor/camera/mapx.bin
cp /vendor/etc/data/camera/mapy.bin /data/vendor/camera/mapy.bin
cp /vendor/etc/data/camera/pdaf2D_calibration_s5kgw1_p24c128e_sunny.bin /data/vendor/camera/pdaf2D_calibration_s5kgw1_p24c128e_sunny.bin
cp /vendor/etc/data/camera/pdafdcc_calibration_s5kgw1_p24c128e_sunny.bin /data/vendor/camera/pdafdcc_calibration_s5kgw1_p24c128e_sunny.bin
cp /vendor/etc/data/camera/sony_imx471_cross_talk.bin /data/vendor/camera/sony_imx471_cross_talk.bin
cp /vendor/etc/data/camera/sony_imx471_dpc_tbl.bin /data/vendor/camera/sony_imx471_dpc_tbl.bin
cp /vendor/etc/data/camera/spc_calibration_s5kgw1_p24c128e_sunny.bin /data/vendor/camera/spc_calibration_s5kgw1_p24c128e_sunny.bin

# Set Memory parameters
configure_memory_parameters

# Enable bus-dcvs
for cpubw in /sys/class/devfreq/*qcom,cpubw*
    do
        echo "bw_hwmon" > $cpubw/governor
        echo 50 > $cpubw/polling_interval
        echo "1144 1720 2086 2929 3879 5931 6881" > $cpubw/bw_hwmon/mbps_zones
        echo 4 > $cpubw/bw_hwmon/sample_ms
        echo 68 > $cpubw/bw_hwmon/io_percent
        echo 20 > $cpubw/bw_hwmon/hist_memory
        echo 0 > $cpubw/bw_hwmon/hyst_length
        echo 80 > $cpubw/bw_hwmon/down_thres
        echo 0 > $cpubw/bw_hwmon/guard_band_mbps
        echo 250 > $cpubw/bw_hwmon/up_scale
        echo 1600 > $cpubw/bw_hwmon/idle_mbps
    done

    #Enable mem_latency governor for DDR scaling
    for memlat in /sys/class/devfreq/*qcom,memlat-cpu*
    do
        echo "mem_latency" > $memlat/governor
        echo 10 > $memlat/polling_interval
        echo 400 > $memlat/mem_latency/ratio_ceil
    done

    #Enable mem_latency governor for L3 scaling
    for memlat in /sys/class/devfreq/*qcom,l3-cpu*
    do
        echo "mem_latency" > $memlat/governor
        echo 10 > $memlat/polling_interval
        echo 400 > $memlat/mem_latency/ratio_ceil
    done

    #Enable userspace governor for L3 cdsp nodes
    for l3cdsp in /sys/class/devfreq/*qcom,l3-cdsp*
    do
        echo "userspace" > $l3cdsp/governor
        chown -h system $l3cdsp/userspace/set_freq
    done

    echo "cpufreq" > /sys/class/devfreq/soc:qcom,mincpubw/governor

    # Disable CPU Retention
    echo N > /sys/module/lpm_levels/L3/cpu0/ret/idle_enabled
    echo N > /sys/module/lpm_levels/L3/cpu1/ret/idle_enabled
    echo N > /sys/module/lpm_levels/L3/cpu2/ret/idle_enabled
    echo N > /sys/module/lpm_levels/L3/cpu3/ret/idle_enabled
    echo N > /sys/module/lpm_levels/L3/cpu4/ret/idle_enabled
    echo N > /sys/module/lpm_levels/L3/cpu5/ret/idle_enabled
    echo N > /sys/module/lpm_levels/L3/cpu6/ret/idle_enabled
    echo N > /sys/module/lpm_levels/L3/cpu7/ret/idle_enabled

    # cpuset parameters
    echo 0-5 > /dev/cpuset/background/cpus
    echo 0-5 > /dev/cpuset/system-background/cpus

    # Turn off scheduler boost at the end
    echo 0 > /proc/sys/kernel/sched_boost

    # Turn on sleep modes.
    echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

setprop vendor.post_boot.parsed 1

# Let kernel know our image version/variant/crm_version
if [ -f /sys/devices/soc0/select_image ]; then
    image_version="10:"
    image_version+=`getprop ro.build.id`
    image_version+=":"
    image_version+=`getprop ro.build.version.incremental`
    image_variant=`getprop ro.product.name`
    image_variant+="-"
    image_variant+=`getprop ro.build.type`
    oem_version=`getprop ro.build.version.codename`
    echo 10 > /sys/devices/soc0/select_image
    echo $image_version > /sys/devices/soc0/image_version
    echo $image_variant > /sys/devices/soc0/image_variant
    echo $oem_version > /sys/devices/soc0/image_crm_version
fi

# Change console log level as per console config property
console_config=`getprop persist.console.silent.config`
case "$console_config" in
    "1")
        echo "Enable console config to $console_config"
        echo 0 > /proc/sys/kernel/printk
        ;;
    *)
        echo "Enable console config to $console_config"
        ;;
esac

# Parse misc partition path and set property
misc_link=$(ls -l /dev/block/bootdevice/by-name/misc)
real_path=${misc_link##*>}
setprop persist.vendor.mmi.misc_dev_path $real_path
