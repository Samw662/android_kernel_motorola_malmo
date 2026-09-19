#!/bin/bash
#
# RAMDisk-accelerated build script for malmo (SM6375/blair)
# Uses tmpfs for compilation, persists ccache on SSD
# Clang 22 - kernel 6.1

set -e -o pipefail

SECONDS=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAMDISK="/mnt/ramdisk"
RAM_DIR="$RAMDISK/malmo_build"
SSD_SRC="$SCRIPT_DIR"
LOG_FILE="$SSD_SRC/malmo_build.log"
: > "$LOG_FILE"

# ============================================================
#  FUNCTION: Enable performance
# ============================================================
activate_bomba() {
    sudo -n sh -c '
      for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$g" 2>/dev/null || true; done
      echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
      echo performance > /sys/firmware/acpi/platform_profile 2>/dev/null || true
      for q in /sys/block/nvme*/queue/scheduler; do echo none > "$q" 2>/dev/null || true; done
      echo 0 > /proc/sys/kernel/sched_autogroup_enabled
      echo 0 > /proc/sys/kernel/numa_balancing
      echo 128 > /proc/sys/kernel/sched_nr_migrate
      echo 0 > /proc/sys/kernel/sched_migration_cost_ns
      echo 10 > /proc/sys/vm/swappiness
      echo 10 > /proc/sys/vm/dirty_ratio
      echo 5 > /proc/sys/vm/dirty_background_ratio
    ' 2>/dev/null && echo "CPU BOMBA activated" || echo "WARN: BOMBA failed (run sudo -v)"
}

# ============================================================
#  FUNCTION: SLEEP (quiet/cool)
# ============================================================
activate_sleep() {
    sudo -n sh -c '
      for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo powersave > "$g" 2>/dev/null || true; done
      echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
      echo balanced > /sys/firmware/acpi/platform_profile 2>/dev/null || true
      for q in /sys/block/nvme*/queue/scheduler; do echo kyber > "$q" 2>/dev/null || true; done
      echo 1 > /proc/sys/kernel/sched_autogroup_enabled
      echo 1 > /proc/sys/kernel/numa_balancing
      echo 60 > /proc/sys/vm/swappiness
      echo 20 > /proc/sys/vm/dirty_ratio
      echo 10 > /proc/sys/vm/dirty_background_ratio
    ' 2>/dev/null && echo "CPU SLEEP activated" || true
}

# ============================================================
#  TRAP: ensure SLEEP on exit
# ============================================================
cleanup() {
    echo ""
    echo "--- Restoring SLEEP mode ---"
    activate_sleep
    echo "--- Build completed in $((SECONDS / 60))m $((SECONDS % 60))s ---"
}
trap cleanup EXIT

# ============================================================
#  1. ACTIVATE PERFORMANCE
# ============================================================
echo "=========================================="
echo "  MALMO KERNEL BUILD"
echo "  Clang 22 - kernel 6.1 - SM6375/blair"
echo "=========================================="
activate_bomba

# ============================================================
#  2. MOUNT TMPFS IF NEEDED
# ============================================================
if ! mountpoint -q "$RAMDISK" 2>/dev/null; then
    echo "Mounting 30GB tmpfs at $RAMDISK ..."
    sudo mkdir -p "$RAMDISK"
    sudo mount -t tmpfs -o size=30G tmpfs "$RAMDISK"
fi

# ============================================================
#  3. SYNC SOURCE TREE TO RAMDISK
# ============================================================
echo "Syncing source tree to RAMDisk..."
mkdir -p "$RAM_DIR"
rsync -a --delete \
    --exclude='.git/' \
    --exclude='out/' \
    --exclude='AnyKernel3/' \
    --exclude='*.zip' \
    --exclude='.ccache/' \
    "$SSD_SRC/" "$RAM_DIR/"

# ============================================================
#  4. RESOLVE TOOLCHAIN (Clang 22)
# ============================================================
CLANG_VERSION="${CLANG_VERSION:-clang-r596125}"
REAL_HOME="/home/samw662"
if [[ -d "$RAM_DIR/TC/$CLANG_VERSION" ]]; then
    TC_DIR="$RAM_DIR/TC/$CLANG_VERSION"
elif [[ -d "$REAL_HOME/Documents/bangkk/kernel/TC/$CLANG_VERSION" ]]; then
    TC_DIR="$REAL_HOME/Documents/bangkk/kernel/TC/$CLANG_VERSION"
elif [[ -d "$HOME/Documents/bangkk/kernel/TC/$CLANG_VERSION" ]]; then
    TC_DIR="$HOME/Documents/bangkk/kernel/TC/$CLANG_VERSION"
elif [[ -d "/usr/lib/llvm-22" ]]; then
    TC_DIR="/usr/lib/llvm-22"
else
    echo "ERROR: toolchain $CLANG_VERSION not found" >&2
    exit 1
fi

export PATH="$TC_DIR/bin:$PATH"
export ARCH=arm64
export KBUILD_BUILD_USER=Samw662
export KBUILD_BUILD_HOST=MDPV
export LLVM=1
export LLVM_IAS=1

# ============================================================
#  5. CCACHE (10GB, compression on)
# ============================================================
export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache_malmo"
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=10G
export CCACHE_SLOPPINESS=pch_defines,time_macros,include_file_mtime
export CCACHE_BASEDIR="$RAM_DIR"
mkdir -p "$CCACHE_DIR"

# ============================================================
#  6. AGGRESSIVE -j
# ============================================================
CORES=$(nproc)
JOBS=$(($CORES * 3))
[ "$JOBS" -gt 48 ] && JOBS=48

echo ""
echo "Build config:"
echo "  Cores:    $CORES"
echo "  Jobs:     $JOBS"
echo "  Toolchain: $TC_DIR"
echo "  RAMDisk:  $RAM_DIR"
echo "  ccache:   $CCACHE_DIR"
echo ""

# ============================================================
#  7. DEFCONFIG (3-layer merge)
# ============================================================
DEFCONFIG="vendor/malmo_defconfig"
VARIANT="malmo"
OUT_DIR="$RAM_DIR/out"
mkdir -p "$OUT_DIR"

echo "=== Configuring ===" | tee -a "$LOG_FILE"
make O="$OUT_DIR" ARCH=arm64 "$DEFCONFIG" 2>&1 | tee -a "$LOG_FILE"

# Disable LTO, CFI, and TRIM_UNUSED_KSYMS (needs abi_symbollist.raw)
sed -i \
    -e 's/^CONFIG_LTO=y/# CONFIG_LTO is not set/' \
    -e 's/^CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/' \
    -e 's/^CONFIG_THINLTO=y/# CONFIG_THINLTO is not set/' \
    -e 's/^CONFIG_CFI_CLANG=y/# CONFIG_CFI_CLANG is not set/' \
    -e 's/^CONFIG_CFI_CLANG_SHADOW=y/# CONFIG_CFI_CLANG_SHADOW is not set/' \
    -e 's/^CONFIG_CFI_CLANG_DEFCONFIG=y/# CONFIG_CFI_CLANG_DEFCONFIG is not set/' \
    -e '/^# CONFIG_LTO_NONE is not set/d' \
    -e 's/^CONFIG_TRIM_UNUSED_KSYMS=y/# CONFIG_TRIM_UNUSED_KSYMS is not set/' \
    -e 's/^CONFIG_DEBUG_INFO_BTF=y/# CONFIG_DEBUG_INFO_BTF is not set/' \
    -e 's/^CONFIG_DEBUG_INFO_BTF_MODULES=y/# CONFIG_DEBUG_INFO_BTF_MODULES is not set/' \
    -e 's/^CONFIG_EXFAT_FS=y/# CONFIG_EXFAT_FS is not set/' \
    "$OUT_DIR/.config"
echo "CONFIG_LTO_NONE=y" >> "$OUT_DIR/.config"
make O="$OUT_DIR" ARCH=arm64 olddefconfig 2>&1 | tee -a "$LOG_FILE"
echo "=== LTO/CFI disabled ===" | tee -a "$LOG_FILE"

# ============================================================
#  8. MAKE ARGS
# ============================================================
MAKE_ARGS="LD=${TC_DIR}/bin/ld.lld
AR=${TC_DIR}/bin/llvm-ar
NM=${TC_DIR}/bin/llvm-nm
OBJCOPY=${TC_DIR}/bin/llvm-objcopy
OBJDUMP=${TC_DIR}/bin/llvm-objdump
STRIP=${TC_DIR}/bin/llvm-strip
LLVM=1
LLVM_IAS=1
KBUILD_EXTRA_SYMBOLS=${OUT_DIR}/Module.symvers
KBUILD_MODPOST_WARN=1"
# Clang 22 strictness: suppress warnings promoted to errors in 6.1 kernel
export KCFLAGS="-Wno-default-const-init-var-unsafe -Wno-default-const-init-field-unsafe -Wno-uninitialized-const-pointer -Wno-error=#warnings -Wno-error=format -Wno-error=unused-but-set-variable"

# ============================================================
#  9. BUILD KERNEL
# ============================================================
echo "=== Building kernel with -j${JOBS} ===" | tee -a "$LOG_FILE"
echo "Started: $(date)" | tee -a "$LOG_FILE"

make O="$OUT_DIR" ARCH=arm64 CC=clang ${MAKE_ARGS} -j${JOBS} 2>&1 | tee -a "$LOG_FILE"

echo "Finished: $(date)" | tee -a "$LOG_FILE"

if [ ! -e "$OUT_DIR/arch/arm64/boot/Image" ]; then
    echo "ERROR: Image binary not found. Compilation failed!" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Kernel compiled successfully." | tee -a "$LOG_FILE"

# ============================================================
# 10. BUILD DTB/DTBO
# ============================================================
echo "=== Building DTBs ===" | tee -a "$LOG_FILE"
make O="$OUT_DIR" ARCH=arm64 CC=clang ${MAKE_ARGS} dtbs 2>&1 | tee -a "$LOG_FILE"

# ============================================================
# 11. MODULES INSTALL
# ============================================================
echo "=== Installing modules ===" | tee -a "$LOG_FILE"
rm -rf "$OUT_DIR/modules"
make O="$OUT_DIR" CC=clang ${MAKE_ARGS} -j${JOBS} INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install 2>&1 | tee -a "$LOG_FILE"

# ============================================================
# 12. COLLECT ARTIFACTS
# ============================================================
echo "=== Collecting artifacts ===" | tee -a "$LOG_FILE"
mkdir -p "$SSD_SRC/out"

# Kernel Image + config
cp -f "$OUT_DIR/arch/arm64/boot/Image" "$SSD_SRC/out/"
cp -f "$OUT_DIR/.config" "$SSD_SRC/out/"

# Module.symvers (critical for out-of-tree module rebuilds)
cp -f "$OUT_DIR/Module.symvers" "$SSD_SRC/out/" 2>/dev/null || true

# DTBs and DTBOs
mkdir -p "$SSD_SRC/out/dtb"
find "$OUT_DIR/arch/arm64/boot/dts/vendor/" -name '*.dtb' -exec cp -f {} "$SSD_SRC/out/dtb/" \; 2>/dev/null || true
find "$OUT_DIR/arch/arm64/boot/dts/vendor/" -name '*.dtbo' -exec cp -f {} "$SSD_SRC/out/dtb/" \; 2>/dev/null || true

# dtbo.img (if built via mkdtimg or similar)
if [ -f "$OUT_DIR/dtbo.img" ]; then
    cp -f "$OUT_DIR/dtbo.img" "$SSD_SRC/out/"
elif [ -f "$OUT_DIR/arch/arm64/boot/dtbo.img" ]; then
    cp -f "$OUT_DIR/arch/arm64/boot/dtbo.img" "$SSD_SRC/out/"
fi

# Collect .ko modules
MODDIR="$SSD_SRC/out/vendor/lib/modules"
mkdir -p "$MODDIR"
if [ -d "$OUT_DIR/modules/lib/modules" ]; then
    find "$OUT_DIR/modules/lib/modules/" -name '*.ko' -exec cp -f {} "$MODDIR/" \; 2>/dev/null || true
    find "$OUT_DIR/modules/lib/modules/" -name 'modules.*' -exec cp -f {} "$MODDIR/" \; 2>/dev/null || true
fi

echo "Artifacts collected: Image, Module.symvers, dtb/, modules/" | tee -a "$LOG_FILE"

# ============================================================
# 13. ANYKERNEL3 PACKAGING
# ============================================================
echo "=== Packaging AnyKernel3 ===" | tee -a "$LOG_FILE"
AK3_DIR="$(dirname "$SSD_SRC")/AnyKernel3"
AK3_MODULES="$AK3_DIR/vendor/lib/modules"

if [ -d "$AK3_DIR" ]; then
    # Clean previous build artifacts from AnyKernel3
    rm -f "$AK3_DIR"/*.zip
    rm -f "$AK3_DIR/Image"
    rm -f "$AK3_DIR/dtbo.img"
    rm -rf "$AK3_DIR/vendor"

    # Copy Image
    cp -f "$SSD_SRC/out/Image" "$AK3_DIR/Image"

    # Copy dtbo.img (for dtbo flash)
    if [ -f "$SSD_SRC/out/dtbo.img" ]; then
        cp -f "$SSD_SRC/out/dtbo.img" "$AK3_DIR/dtbo.img"
    fi

    # Copy modules (.ko only, curated list)
    mkdir -p "$AK3_MODULES"
    for ko in "$MODDIR"/*.ko; do
        [ -f "$ko" ] && cp -f "$ko" "$AK3_MODULES/"
    done
    # Copy Module.symvers and modules.dep for modprobe
    for f in modules.alias modules.dep modules.dep.bin modules.softdep; do
        [ -f "$MODDIR/$f" ] && cp -f "$MODDIR/$f" "$AK3_MODULES/"
    done

    # Generate flashable ZIP
    ZIP_NAME="Stars-malmo-stock-$(date +%m%Y)-$(date +%H%M).zip"
    cd "$AK3_DIR"
    zip -r9 "$ZIP_NAME" . -x '*.git*' -x '*.zip' 2>&1 | tee -a "$LOG_FILE"
    cd "$SSD_SRC"

    # Move ZIP to out/
    if [ -f "$AK3_DIR/$ZIP_NAME" ]; then
        mv "$AK3_DIR/$ZIP_NAME" "$SSD_SRC/out/$ZIP_NAME"
        echo "AnyKernel3 ZIP: out/$ZIP_NAME" | tee -a "$LOG_FILE"
    fi
else
    echo "WARN: AnyKernel3 directory not found, skipping packaging" | tee -a "$LOG_FILE"
fi

# ============================================================
# 14. CCACHE STATS
# ============================================================
echo ""
echo "=== CCACHE STATS ==="
ccache -s 2>&1 | grep -E "cache hit|cache miss|cache size|files in cache"
echo ""

echo "=== TOTAL TIME: $((SECONDS / 60))m $((SECONDS % 60))s ===" | tee -a "$LOG_FILE"
echo "Artifacts: $SSD_SRC/out/"
