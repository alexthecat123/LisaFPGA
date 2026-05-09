#!/usr/bin/env bash
# program_board.sh - Fully programs the LisaFPGA board:
#   1. FT232H JTAG interface EEPROM (USB strings)
#   2. CP2102N serial EEPROM (USB strings)
#   3. ESProFile ESP32-S3 firmware
#   4. ESFloppy  ESP32-S3 firmware
#   5. FPGA bitstream (top.mcs via openFPGALoader)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[ OK ]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
die()   { printf "${RED}[FAIL]${NC}  %s\n" "$*" >&2; exit 1; }
step()  { printf "\n${BOLD}══ %s ══${NC}\n" "$*"; }

# ── OS detection ─────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
    Linux)  PLATFORM=linux  ;;
    Darwin) PLATFORM=macos  ;;
    *) die "Unsupported OS: $OS" ;;
esac
info "Platform: $PLATFORM"

# ── Root / sudo helper ───────────────────────────────────────────────────────
need_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This step requires root. Re-run the script with sudo, or run: sudo $0"
    fi
}

# On Linux, driver unbinding requires root.  Warn now so the user can restart.
if [[ "$PLATFORM" == "linux" && $EUID -ne 0 ]]; then
    warn "Some steps require root (driver unbinding). If you hit permission errors,"
    warn "re-run with: sudo $0"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 0 - Dependency installation
# ═══════════════════════════════════════════════════════════════════════════════
step "Checking / Installing Dependencies"

install_pkg_linux() {
    local pkg="$1"
    if ! dpkg -s "$pkg" &>/dev/null; then
        info "Installing $pkg..."
        if [[ $EUID -eq 0 ]]; then
            apt-get install -y "$pkg"
        else
            sudo apt-get install -y "$pkg"
        fi
    fi
}

install_pkg_macos() {
    local formula="$1"
    if ! brew list "$formula" &>/dev/null; then
        info "Installing $formula via Homebrew..."
        brew install "$formula"
    fi
}

ensure_brew() {
    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
}

# git
if ! command -v git &>/dev/null; then
    case "$PLATFORM" in
        linux) install_pkg_linux git ;;
        macos) ensure_brew; install_pkg_macos git ;;
    esac
fi
ok "git: $(git --version)"

# python3 + pip3
if ! command -v python3 &>/dev/null; then
    case "$PLATFORM" in
        linux) install_pkg_linux python3 python3-pip ;;
        macos) ensure_brew; install_pkg_macos python3 ;;
    esac
fi

# pyusb  (used for CP2102N and FT232H string checks)
if ! python3 -c "import usb.core" &>/dev/null; then
    info "Installing pyusb..."
    case "$PLATFORM" in
        linux)
            # Prefer the distro package; avoids the "externally managed" error
            if ! install_pkg_linux python3-usb 2>/dev/null; then
                pip3 install --quiet --break-system-packages pyusb
            fi
            ;;
        macos)
            pip3 install --quiet pyusb
            ;;
    esac
fi
ok "pyusb: $(python3 -c 'import usb; print(usb.__version__)')"

# libusb (backend for pyusb and libftdi)
case "$PLATFORM" in
    linux)
        install_pkg_linux libusb-1.0-0
        install_pkg_linux libusb-1.0-0-dev 2>/dev/null || true
        ;;
    macos)
        ensure_brew
        install_pkg_macos libusb
        ;;
esac

# libftdi1 runtime library (for Python ctypes FT232H EEPROM programming)
case "$PLATFORM" in
    linux) install_pkg_linux libftdi1-2 ;;
    macos) : ;;  # provided by the libftdi Homebrew formula
esac

# ftdi_eeprom
if ! command -v ftdi_eeprom &>/dev/null; then
    case "$PLATFORM" in
        linux) install_pkg_linux ftdi-eeprom ;;
        macos)
            ensure_brew
            # libftdi provides ftdi_eeprom on macOS
            install_pkg_macos libftdi
            # Symlink if needed
            BREW_PREFIX="$(brew --prefix)"
            if [[ -f "$BREW_PREFIX/opt/libftdi/bin/ftdi_eeprom" ]]; then
                ln -sf "$BREW_PREFIX/opt/libftdi/bin/ftdi_eeprom" /usr/local/bin/ftdi_eeprom 2>/dev/null || true
            fi
            ;;
    esac
fi
command -v ftdi_eeprom &>/dev/null || die "ftdi_eeprom not found after install attempt"
ok "ftdi_eeprom: $(ftdi_eeprom 2>&1 | grep -o 'v[0-9][0-9.]*' | head -1)"

# arduino-cli
if ! command -v arduino-cli &>/dev/null; then
    case "$PLATFORM" in
        linux)
            info "Installing arduino-cli..."
            curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | \
                BINDIR=/usr/local/bin sh
            ;;
        macos)
            ensure_brew
            install_pkg_macos arduino-cli
            ;;
    esac
fi
ok "arduino-cli: $(arduino-cli version 2>/dev/null | head -1)"

# ESP32 arduino core
if ! arduino-cli core list 2>/dev/null | grep -q "esp32:esp32"; then
    info "Installing ESP32 Arduino core..."
    arduino-cli config init --overwrite 2>/dev/null || true
    arduino-cli config add board_manager.additional_urls \
        https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json \
        2>/dev/null || true
    arduino-cli core update-index
    arduino-cli core install esp32:esp32
fi
ok "ESP32 Arduino core: $(arduino-cli core list 2>/dev/null | grep esp32:esp32)"

# SDFat library (required by ESProFile)
if ! arduino-cli lib list 2>/dev/null | grep -q "^SDFat"; then
    info "Installing SDFat Arduino library..."
    arduino-cli lib install "SDFat"
fi
ok "SDFat: $(arduino-cli lib list 2>/dev/null | grep '^SDFat' | awk '{print $1, $2}')"

# openFPGALoader
if ! command -v openFPGALoader &>/dev/null; then
    case "$PLATFORM" in
        linux)
            # Try apt first; if unavailable, compile from source
            if ! install_pkg_linux openfpgaloader 2>/dev/null; then
                info "Building openFPGALoader from source..."
                install_pkg_linux cmake libftdi1-dev libusb-1.0-0-dev libudev-dev \
                    pkg-config zlib1g-dev
                TMP_OFL="$(mktemp -d)"
                git clone --depth 1 https://github.com/trabucayre/openFPGALoader.git "$TMP_OFL"
                cmake -S "$TMP_OFL" -B "$TMP_OFL/build" -DCMAKE_BUILD_TYPE=Release
                make -C "$TMP_OFL/build" -j"$(nproc)"
                if [[ $EUID -eq 0 ]]; then
                    make -C "$TMP_OFL/build" install
                else
                    sudo make -C "$TMP_OFL/build" install
                fi
            fi
            ;;
        macos)
            ensure_brew
            install_pkg_macos openfpgaloader
            ;;
    esac
fi
command -v openFPGALoader &>/dev/null || die "openFPGALoader not found after install attempt"
ok "openFPGALoader: $(openFPGALoader --Version 2>&1 | head -1)"

# cp210x-cfg (irrwisch1 fork) - supports CP2102N via 0x370F blob write + Fletcher16
CP210X_CFG_DIR="/tmp/cp210x-cfg-n"
CP210X_CFG_BIN="$CP210X_CFG_DIR/cp210x-cfg"
if [[ ! -x "$CP210X_CFG_BIN" ]]; then
    info "Building cp210x-cfg..."
    case "$PLATFORM" in
        linux) install_pkg_linux libusb-1.0-0-dev ;;
        macos) ensure_brew; install_pkg_macos libusb ;;
    esac
    if [[ ! -d "$CP210X_CFG_DIR" ]]; then
        git clone --depth=1 https://github.com/irrwisch1/cp210x-cfg.git "$CP210X_CFG_DIR"
    fi
    mkdir -p "$CP210X_CFG_DIR/build"
    if [[ "$PLATFORM" == "macos" ]]; then
        LIBUSB_PFX="$(brew --prefix libusb 2>/dev/null)"
        make -C "$CP210X_CFG_DIR" \
            CFLAGS="-std=c11 -O2 -pipe -Wall -Wextra -D_POSIX_C_SOURCE=2 -c -I${LIBUSB_PFX}/include" \
            LDFLAGS="-L${LIBUSB_PFX}/lib -lusb-1.0"
    else
        make -C "$CP210X_CFG_DIR"
    fi
    [[ -x "$CP210X_CFG_BIN" ]] || die "cp210x-cfg build failed"
fi
ok "cp210x-cfg: $CP210X_CFG_BIN"

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1 - USB topology helpers
# ═══════════════════════════════════════════════════════════════════════════════

# CH334 hub identifiers
HUB_VID="1a86"
HUB_PID="8091"

# ── Linux: find hub sysfs base name (e.g. "1-2") ─────────────────────────────
linux_find_hub() {
    for d in /sys/bus/usb/devices/*/; do
        [[ -f "${d}idVendor" ]] || continue
        local v p
        v=$(< "${d}idVendor")
        p=$(< "${d}idProduct")
        if [[ "$v" == "$HUB_VID" && "$p" == "$HUB_PID" ]]; then
            basename "$d"
            return 0
        fi
    done
    return 1
}

# ── Linux: find /dev/ttyACMx for device at hub port N ────────────────────────
linux_tty_for_hub_port() {
    local hub_name="$1" port="$2"
    local child="/sys/bus/usb/devices/${hub_name}.${port}"
    local tty
    tty=$(find "$child/" -name "ttyACM*" 2>/dev/null | head -1)
    [[ -z "$tty" ]] && tty=$(find "$child/" -name "ttyUSB*" 2>/dev/null | head -1)
    if [[ -n "$tty" ]]; then
        echo "/dev/$(basename "$tty")"
        return 0
    fi
    return 1
}

# ── macOS: find /dev/cu.* for device with given USB serial number ─────────────
macos_port_for_serial() {
    local usb_serial="$1"
    python3 - "$usb_serial" <<'PYEOF'
import subprocess, sys, re

serial = sys.argv[1]
try:
    out = subprocess.check_output(
        ['ioreg', '-r', '-c', 'IOUSBHostDevice', '-l'],
        text=True, stderr=subprocess.DEVNULL
    )
except Exception:
    sys.exit(1)

# Split into per-device blocks at each +-o header
blocks = re.split(r'(?=\s*\+-o )', out)
for block in blocks:
    if serial not in block:
        continue
    # Walk the ioreg tree for this device branch looking for IOCalloutDevice
    # (it lives under IOUSBHostInterface -> IOSerialStreamSync)
    # ioreg with -r shows properties of child objects too
    m = re.search(r'"IOCalloutDevice"\s*=\s*"(/dev/[^"]+)"', block)
    if m:
        print(m.group(1))
        sys.exit(0)
sys.exit(1)
PYEOF
}

# ── macOS: find /dev/cu.* for ESP32 at hub port N ────────────────────────────
# We use locationID: each nibble encodes a hub port level.
macos_tty_for_hub_port() {
    local port="$1"   # 2 or 3
    python3 - "$HUB_VID" "$HUB_PID" "$port" <<'PYEOF'
import subprocess, sys, re, json

hub_vid_str = "0x" + sys.argv[1].upper()
hub_pid_str = "0x" + sys.argv[2].upper()
target_port = int(sys.argv[3])

try:
    raw = subprocess.check_output(
        ['system_profiler', 'SPUSBDataType', '-json'],
        text=True, stderr=subprocess.DEVNULL
    )
    data = json.loads(raw)
except Exception:
    sys.exit(1)

def scan(items):
    for item in items:
        vid = item.get('vendor_id', '').upper().replace('0X', '0x')
        pid = item.get('product_id', '').upper().replace('0X', '0x')
        if hub_vid_str.upper() in vid and hub_pid_str.upper() in pid:
            children = item.get('_items', [])
            # system_profiler lists hub children in port order
            # port numbers are 1-based; index = port-1
            idx = target_port - 1
            if idx < len(children):
                child = children[idx]
                # serial number of this ESP32
                child_serial = child.get('serial_num', '')
                if child_serial:
                    # Now find the /dev/cu.* via ioreg
                    try:
                        out = subprocess.check_output(
                            ['ioreg', '-r', '-c', 'IOUSBHostDevice', '-l'],
                            text=True, stderr=subprocess.DEVNULL
                        )
                        m = re.search(
                            r'"IOCalloutDevice"\s*=\s*"(/dev/[^"]+)"',
                            out[out.find(child_serial):]
                        )
                        if m:
                            print(m.group(1))
                            sys.exit(0)
                    except Exception:
                        pass
        sub = item.get('_items', [])
        if sub:
            scan(sub)

scan(data.get('SPUSBDataType', []))
sys.exit(1)
PYEOF
}

# ── Generic: get tty for ESProFile (hub port 2) and ESFloppy (hub port 3) ────
find_esp_ports() {
    if [[ "$PLATFORM" == "linux" ]]; then
        HUB_NAME=$(linux_find_hub) || die "CH334 hub (${HUB_VID}:${HUB_PID}) not found - is the board plugged in?"
        info "Found CH334 hub at USB path: $HUB_NAME"
        ESPROFILE_PORT=$(linux_tty_for_hub_port "$HUB_NAME" 2) \
            || die "Failed to find serial port for ESProFile (hub port 2)!"
        ESFLOPPY_PORT=$(linux_tty_for_hub_port "$HUB_NAME" 3) \
            || die "Failed to find serial port for ESFloppy (hub port 3)!"
    else
        ESPROFILE_PORT=$(macos_tty_for_hub_port 2) \
            || die "Failed to find serial port for ESProFile (hub port 2)!"
        ESFLOPPY_PORT=$(macos_tty_for_hub_port 3) \
            || die "Failed to find serial port for ESFloppy (hub port 3)!"
    fi
    info "ESProFile Serial Port: $ESPROFILE_PORT"
    info "ESFloppy Serial Port: $ESFLOPPY_PORT"
}

# ── Linux: unbind a USB interface from its kernel driver ─────────────────────
linux_unbind_driver() {
    local driver="$1"   # e.g. ftdi_sio, cp210x
    local vid="$2"      # e.g. 0403
    local pid="$3"      # e.g. 6014
    local unbind_path="/sys/bus/usb/drivers/${driver}/unbind"
    [[ -d "/sys/bus/usb/drivers/${driver}" ]] || return 0

    for d in /sys/bus/usb/devices/*/; do
        [[ -f "${d}idVendor" ]] || continue
        v=$(< "${d}idVendor")
        p=$(< "${d}idProduct")
        if [[ "$v" == "$vid" && "$p" == "$pid" ]]; then
            dev_name=$(basename "$d")
            # Unbind all interfaces of this device
            for iface in /sys/bus/usb/devices/"${dev_name}":*/; do
                iface_name=$(basename "$iface")
                drv_link="${iface}driver"
                if [[ -L "$drv_link" ]]; then
                    drv_target=$(readlink "$drv_link" | awk -F/ '{print $NF}')
                    if [[ "$drv_target" == "$driver" ]]; then
                        info "Unbinding $iface_name from $driver..."
                        if [[ $EUID -eq 0 ]]; then
                            echo "$iface_name" > "/sys/bus/usb/drivers/${driver}/unbind" 2>/dev/null || true
                        else
                            echo "$iface_name" | sudo tee "/sys/bus/usb/drivers/${driver}/unbind" >/dev/null 2>&1 || true
                        fi
                    fi
                fi
            done
        fi
    done
}

# ── macOS: detach Apple FTDI or SiLabs kernel extensions ─────────────────────
macos_unload_kext() {
    local bundle_id="$1"
    if kextstat 2>/dev/null | grep -q "$bundle_id"; then
        info "Unloading kext $bundle_id..."
        sudo kextunload -b "$bundle_id" 2>/dev/null || true
        sleep 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2 - FT232H JTAG interface programming
# ═══════════════════════════════════════════════════════════════════════════════
step "Program FT323H USB-to-JTAG Interface EEPROM"

FT232_VID="0403"; FT232_PID="6014"
# These are the standard USB string descriptors that pyusb reads from the device.
# The Digilent user-area strings ("AlexTheCat123", "LisaFPGA JTAG Interface") live
# in a non-standard EEPROM section that the Digilent runtime reads directly; they
# are NOT the USB iManufacturer/iProduct/iSerialNumber descriptors.
FT232_MANUFACTURER="Xilinx"              # iManufacturer
FT232_PRODUCT="LisaFPGA JTAG Interface"    # iProduct
FT232_SERIAL="000000"                   # iSerialNumber

# Check all three standard USB string descriptors (non-destructive)
ft232_already_programmed() {
    python3 - "$FT232_MANUFACTURER" "$FT232_PRODUCT" "$FT232_SERIAL" <<'PYEOF'
import sys
try:
    import usb.core, usb.util
except ImportError:
    sys.exit(2)
want_mftr, want_prod, want_serial = sys.argv[1], sys.argv[2], sys.argv[3]
dev = usb.core.find(idVendor=0x0403, idProduct=0x6014)
if dev is None:
    print("FT232H not found", file=sys.stderr); sys.exit(1)
try:
    mftr   = usb.util.get_string(dev, dev.iManufacturer)  or ""
    prod   = usb.util.get_string(dev, dev.iProduct)       or ""
    serial = usb.util.get_string(dev, dev.iSerialNumber)  or ""
except Exception:
    mftr = prod = serial = ""
print(f"Current FT232H: manufacturer='{mftr}'  board_description='{prod}'  serial='{serial}'")
sys.exit(0 if (mftr == want_mftr and prod == want_prod and serial == want_serial) else 1)
PYEOF
}

if ft232_already_programmed; then
    ok "FT232H already programmed correctly, skipping!"
else
    info "EEPROM contents invalid; FT232H needs programming!"

    # Kill Vivado hw_server if it has the device open
    if pgrep -x hw_server &>/dev/null; then
        warn "Killing Vivado hw_server if running..."
        pkill -x hw_server 2>/dev/null || true
        sleep 2
        #info "hw_server stopped"
    fi

    # Linux: if ftdi_sio has claimed the device, unbind it.
    # The more common case is hw_server (already killed above) held it via
    # usbfs; a short sleep lets the kernel release the interface claim.
    if [[ "$PLATFORM" == "linux" ]]; then
        linux_unbind_driver "ftdi_sio" "$FT232_VID" "$FT232_PID"
        sleep 1
    fi

    # macOS: unload Apple's FTDI kext if present
    if [[ "$PLATFORM" == "macos" ]]; then
        macos_unload_kext "com.apple.driver.AppleUSBFTDI"
    fi

    # Write the pre-built EEPROM image verbatim.  ft232h_eeprom.bin was extracted
    # from a program_ftdi-configured chip and has all Digilent/Xilinx JTAG settings
    # intact (channel mode, drive strength, CBUSH pins, Digilent user-area data)
    # plus the target USB strings already baked in.  Run dump_ft232h_eeprom.py once
    # to regenerate it if the strings ever need to change.
    EEPROM_BIN="$SCRIPT_DIR/ft232h_eeprom.bin"
    [[ -f "$EEPROM_BIN" ]] \
        || die "ft232h_eeprom.bin not found in $SCRIPT_DIR!!!"

    info "Flashing FT232H EEPROM from ft232h_eeprom.bin..."
    # Use raw USB control transfers (SIO_WRITE_EEPROM_REQUEST = 0x91) via pyusb.
    # This is exactly what libftdi does internally, but avoids libftdi's EEPROM
    # struct management which fails on Digilent-format EEPROMs.
    if ! python3 - "$EEPROM_BIN" <<'PYEOF'
import sys

try:
    import usb.core, usb.util
except ImportError:
    print("ERROR: pyusb not available", file=sys.stderr); sys.exit(1)

eeprom_file = sys.argv[1]
with open(eeprom_file, 'rb') as f:
    eeprom_data = f.read()
if len(eeprom_data) != 256:
    print(f"ERROR: {eeprom_file} is {len(eeprom_data)} bytes, expected 256",
          file=sys.stderr)
    sys.exit(1)

dev = usb.core.find(idVendor=0x0403, idProduct=0x6014)
if dev is None:
    print("ERROR: FT232H (0403:6014) not found", file=sys.stderr); sys.exit(1)

# Detach kernel drivers so we can use the control endpoint
for cfg in dev:
    for intf in cfg:
        try:
            if dev.is_kernel_driver_active(intf.bInterfaceNumber):
                dev.detach_kernel_driver(intf.bInterfaceNumber)
        except Exception:
            pass

# Erase EEPROM first (SIO_ERASE_EEPROM_REQUEST = 0x92)
try:
    dev.ctrl_transfer(0x40, 0x92, 0, 0, b'')
    print("  EEPROM erased")
except usb.core.USBError as e:
    print(f"  WARNING: erase step: {e}")

# Write 256 bytes as 128 16-bit words (SIO_WRITE_EEPROM_REQUEST = 0x91)
# Protocol: bmRequestType=0x40, bRequest=0x91, wValue=word, wIndex=word_address
for i in range(128):
    word = eeprom_data[2*i] | (eeprom_data[2*i + 1] << 8)
    try:
        dev.ctrl_transfer(0x40, 0x91, word, i, b'')
    except usb.core.USBError as e:
        print(f"ERROR: write failed at word {i} (byte 0x{i*2:02x}): {e}",
              file=sys.stderr)
        sys.exit(1)

print("  FT232H EEPROM written - replug board to activate")
sys.exit(0)
PYEOF
    then
        die "FT232H EEPROM programming failed, see errors above!"
    fi
    ok "FT232H EEPROM written, unplug and replug the board to see the new USB strings!"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3 - CP2102N serial interface programming
# ═══════════════════════════════════════════════════════════════════════════════
step "Program CP2102N Serial Interface Name Descriptor"

CP210X_VID="10c4"; CP210X_PID="ea60"   # may also appear as ea62 if config was corrupted
CP210X_PRODUCT="LisaFPGA Serial B"

# macOS: unload SiLabs kext before pyusb can claim the device
if [[ "$PLATFORM" == "macos" ]]; then
    macos_unload_kext "com.silabs.driver.CP210xVCPDriver"
    macos_unload_kext "com.silabs.driver.CP210xVCPDriver64"
fi

# Linux: unbind cp210x before programming
if [[ "$PLATFORM" == "linux" ]]; then
    linux_unbind_driver "cp210x" "$CP210X_VID" "$CP210X_PID"
    linux_unbind_driver "cp210x" "$CP210X_VID" "ea62"
    sleep 1
fi

# Check current product name (wValue=0x0E read path for CP2102N)
CURR_CP210X_PROD=$("$CP210X_CFG_BIN" -m "${CP210X_VID}:${CP210X_PID}" 2>/dev/null \
    | grep "^Name:" | sed 's/^Name: //' | tr -d '\n') || true
info "CP2102N current product: '${CURR_CP210X_PROD}'"

if [[ "$CURR_CP210X_PROD" == "$CP210X_PRODUCT" ]]; then
    ok "CP2102N already programmed correctly, skipping!"
else
    cp210x_exit=0
    "$CP210X_CFG_BIN" -m "${CP210X_VID}:${CP210X_PID}" -N "$CP210X_PRODUCT" \
        || cp210x_exit=$?
    if   [[ $cp210x_exit -eq 0 ]]; then
        ok "CP2102N programmed with name '$CP210X_PRODUCT', replug the board to see the change!"
    else
        warn "CP2102N name could not be changed (exit code $cp210x_exit). This is just a cosmetic change, so it should still work fine!"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4 - Discover ESP32 serial ports
# ═══════════════════════════════════════════════════════════════════════════════
step "Discover ESP32 Serial Ports"
find_esp_ports
# From here: $ESPROFILE_PORT and $ESFLOPPY_PORT are set.

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5 - ESProFile firmware
# ═══════════════════════════════════════════════════════════════════════════════
step "Get ESProFile Firmware"

ESPROFILE_DIR="$SCRIPT_DIR/ESProFile"
if [[ -d "$ESPROFILE_DIR/.git" ]]; then
    info "ESProFile repo already exists locally, pulling latest..."
    git -C "$ESPROFILE_DIR" pull
else
    info "Cloning ESProFile repo..."
    git clone https://github.com/alexthecat123/ESProFile.git "$ESPROFILE_DIR"
fi

# Edit ESProFile.ino: ensure LisaFPGA pin defs are active, not standalone ones.
ESPROFILE_INO="$ESPROFILE_DIR/sw/ESProFile/ESProFile.ino"
[[ -f "$ESPROFILE_INO" ]] || die "ESProFile.ino not found at $ESPROFILE_INO"

patch_includes() {
    local ino="$1"
    local content
    content=$(< "$ino")

    # Comment out standalone #include "PinDefs_ESProFile.h"
    content=$(echo "$content" | sed \
        's|^\(#include "PinDefs_ESProFile\.h"\)|//\1|')
    # Uncomment #include "PinDefs_LisaFPGA.h" (handles both // and /* forms)
    content=$(echo "$content" | sed \
        's|^//\s*\(#include "PinDefs_LisaFPGA\.h"\)|\1|')
    # Handle block-comment form: /* #include... */
    content=$(echo "$content" | sed \
        's|/\*\s*\(#include "PinDefs_LisaFPGA\.h"\)\s*\*/|\1|')

    echo "$content" > "$ino"
}

info "Patching ESProFile.ino for LisaFPGA pindefs..."
patch_includes "$ESPROFILE_INO"

# Verify
if grep -q '^#include "PinDefs_LisaFPGA.h"' "$ESPROFILE_INO" && \
   ! grep -q '^#include "PinDefs_ESProFile.h"' "$ESPROFILE_INO"; then
    ok "Patch succeeded!"
else
    warn "Could not auto-patch ESProFile.ino! Edit $ESPROFILE_INO and do the following:"
    warn "  Uncomment: #include \"PinDefs_LisaFPGA.h\""
    warn "  Comment out: #include \"PinDefs_ESProFile.h\""
    grep -n "PinDefs" "$ESPROFILE_INO" | head -10 || true
fi

step "Compile/Upload ESProFile Firmware"
info "Compiling ESProFile for ESP32-S3..."
arduino-cli compile \
    --fqbn "esp32:esp32:esp32s3:CDCOnBoot=cdc" \
    "$ESPROFILE_DIR/sw/ESProFile"

info "Uploading ESProFile to $ESPROFILE_PORT..."
arduino-cli upload \
    --fqbn "esp32:esp32:esp32s3:CDCOnBoot=cdc" \
    -p "$ESPROFILE_PORT" \
    "$ESPROFILE_DIR/sw/ESProFile"

ok "ESProFile uploaded to $ESPROFILE_PORT!"

# Give the device time to re-enumerate after the new firmware boots
sleep 3

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6 - ESFloppy firmware
# ═══════════════════════════════════════════════════════════════════════════════
step "Get ESFloppy Firmware"

ESFLOPPY_DIR="$SCRIPT_DIR/ESFloppy"
if [[ -d "$ESFLOPPY_DIR/.git" ]]; then
    info "ESFloppy repo already exists locally, pulling latest..."
    git -C "$ESFLOPPY_DIR" pull
else
    info "Cloning ESFloppy repo..."
    git clone https://github.com/alexthecat123/ESFloppy.git "$ESFLOPPY_DIR"
fi

ESFLOPPY_INO_DIR="$ESFLOPPY_DIR/ESFloppy"
ESFLOPPY_INO="$ESFLOPPY_INO_DIR/ESFloppy.ino"

# ESFloppy uses the same LisaFPGA/standalone pattern if applicable
if [[ -f "$ESFLOPPY_INO" ]]; then
    if grep -q "PinDefs_ESFloppy\|PinDefs_LisaFPGA\|PinDefs_Standalone" "$ESFLOPPY_INO" 2>/dev/null; then
        info "Patching ESFloppy.ino for LisaFPGA pin defs..."
        sed -i.bak \
            -e 's|^\(#include "PinDefs_ESFloppy\.h"\)|//\1|' \
            -e 's|^\(#include "PinDefs_Standalone\.h"\)|//\1|' \
            -e 's|^//\s*\(#include "PinDefs_LisaFPGA\.h"\)|\1|' \
            "$ESFLOPPY_INO"
        ok "ESFloppy.ino patched"
    fi
fi

step "Compile/Upload ESFloppy Firmware"
info "Compiling ESFloppy for ESP32-S3..."
arduino-cli compile \
    --fqbn "esp32:esp32:esp32s3:CDCOnBoot=cdc" \
    "$ESFLOPPY_INO_DIR"

info "Uploading ESFloppy to $ESFLOPPY_PORT..."
arduino-cli upload \
    --fqbn "esp32:esp32:esp32s3:CDCOnBoot=cdc" \
    -p "$ESFLOPPY_PORT" \
    "$ESFLOPPY_INO_DIR"

ok "ESFloppy uploaded to $ESFLOPPY_PORT!"
sleep 3

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7 - FPGA bitstream
# ═══════════════════════════════════════════════════════════════════════════════
step "Program FPGA Bitstream to SPI Flash via JTAG"

MCS_FILE="$SCRIPT_DIR/LisaFPGA.runs/impl_1/top.mcs"
[[ -f "$MCS_FILE" ]] || die "Bitstream not found: $MCS_FILE"
info "Bitstream: $MCS_FILE"

# openFPGALoader uses the FT232H via libftdi.  The cable is auto-detected as
# ft232 when connected; --fpga-part tells it about the Artix-7 device.
# If hw_server was restarted since we killed it, kill it again.
if pgrep -x hw_server &>/dev/null; then
    warn "hw_server running, stopping it so openFPGALoader can claim FT232H..."
    pkill -x hw_server 2>/dev/null || true
    sleep 2
fi

info "Programming FPGA with openFPGALoader..."
# --cable ft232 targets 0x0403:0x6014 (FT232H).
# --fpga-part is required for indirect SPI flash programming - openFPGALoader
# needs the package info to select the correct BSCAN primitive.
openFPGALoader --cable ft232 --fpga-part xc7a100tcsg324 --write-flash "$MCS_FILE"

ok "FPGA Programmed!"

# ═══════════════════════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════════════════════
printf "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}\n"
printf   "${GREEN}${BOLD}║   LisaFPGA board fully programmed!               ║${NC}\n"
printf   "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}\n\n"

ok "Power-cycle the LisaFPGA board for the new FT232H and CP2102N USB descriptors to take effect."
ok "Afterwards, the board will appear as:"
ok "  FT232H: manufacturer = '${FT232_MANUFACTURER}'  product = '${FT232_PRODUCT}'  serial = '${FT232_SERIAL}'"
ok "  CP2102N: product = '${CP210X_PRODUCT}'"
