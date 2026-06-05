#!/bin/bash

# GPU-Chassis Fan Controller
# Automatically adjusts chassis fan speed based on GPU power consumption and CPU/GPU temperatures

# Configuration
GPU_TEMP_THRESHOLD=70          # Emergency temperature threshold in Celsius
CPU_TEMP_THRESHOLD=75          # Emergency CPU temperature threshold in Celsius
CPU_TEMP_HIGH=65               # High CPU temperature threshold in Celsius
CPU_TEMP_MEDIUM=55             # Medium CPU temperature threshold in Celsius
CPU_TEMP_LOW=45                # Low CPU temperature threshold in Celsius
GPU_POWER_IDLE=30              # Idle power consumption in Watts
GPU_POWER_LOW=150              # Low load threshold in Watts
GPU_POWER_MEDIUM=300           # Medium load threshold in Watts  
GPU_POWER_HIGH=450             # High load threshold in Watts
GPU_POWER_MAX=550              # Maximum expected power in Watts
MAX_CHASSIS_FAN_SPEED=255      # Maximum PWM value (100%)
MIN_CHASSIS_FAN_SPEED=77       # Minimum PWM value (~30%)
HWMON_PATH="/sys/class/hwmon/hwmon3"
CPU_THERMAL_ZONE="/sys/class/thermal/thermal_zone1/temp"  # x86_pkg_temp
CHECK_INTERVAL=5               # Check every 5 seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to set chassis fan speed
set_chassis_fans() {
    local speed=$1
    local mode=$2  # 1 for manual, 5 for auto
    
    for i in {1..7}; do
        echo $mode > "${HWMON_PATH}/pwm${i}_enable" 2>/dev/null
        echo $speed > "${HWMON_PATH}/pwm${i}" 2>/dev/null
    done
}

# Function to get current chassis fan speeds
get_chassis_fan_speeds() {
    local speeds=()
    for i in {1..7}; do
        local fan_speed=$(cat "${HWMON_PATH}/fan${i}_input" 2>/dev/null)
        if [[ "$fan_speed" != "0" && -n "$fan_speed" ]]; then
            speeds+=("Fan${i}: ${fan_speed}rpm")
        fi
    done
    echo "${speeds[@]}"
}

# Function to get CPU temperature
get_cpu_temperature() {
    if [[ -f "$CPU_THERMAL_ZONE" ]]; then
        local temp_millicelsius=$(cat "$CPU_THERMAL_ZONE" 2>/dev/null)
        if [[ -n "$temp_millicelsius" && "$temp_millicelsius" -gt 0 ]]; then
            echo $((temp_millicelsius / 1000))
            return 0
        fi
    fi
    echo "0"
    return 1
}

# Function to calculate scaled fan speed based on GPU power consumption and both GPU/CPU temperatures
calculate_fan_speed() {
    local gpu_temp=$1
    local gpu_fan=$2
    local gpu_power=$3
    local cpu_temp=$4
    
    # Convert power to integer (remove decimal part)
    gpu_power=${gpu_power%.*}
    
    # Emergency temperature override - always max fans if either GPU or CPU too hot
    if [[ $gpu_temp -ge $GPU_TEMP_THRESHOLD ]] || [[ $cpu_temp -ge $CPU_TEMP_THRESHOLD ]]; then
        echo $MAX_CHASSIS_FAN_SPEED  # Max speed when over temperature threshold
        return
    fi
    
    # Calculate CPU-based minimum fan speed
    local cpu_min_speed=$MIN_CHASSIS_FAN_SPEED
    if [[ $cpu_temp -ge $CPU_TEMP_HIGH ]]; then
        # CPU hot (65°C+): Force at least 60% fan speed
        cpu_min_speed=$(( 60 * 255 / 100 ))
    elif [[ $cpu_temp -ge $CPU_TEMP_MEDIUM ]]; then
        # CPU warm (55°C+): Force at least 45% fan speed
        cpu_min_speed=$(( 45 * 255 / 100 ))
    elif [[ $cpu_temp -ge $CPU_TEMP_LOW ]]; then
        # CPU slightly warm (45°C+): Force at least 35% fan speed
        cpu_min_speed=$(( 35 * 255 / 100 ))
    fi
    
    # Power-based fan scaling with CPU minimum override
    local gpu_based_speed
    if [[ $gpu_power -ge $GPU_POWER_MAX ]]; then
        # 550W+: Maximum cooling (100%)
        gpu_based_speed=$MAX_CHASSIS_FAN_SPEED
    elif [[ $gpu_power -ge $GPU_POWER_HIGH ]]; then
        # 450-549W: Scale 80-100% based on power
        local scale_factor=$(( (gpu_power - GPU_POWER_HIGH) * 20 / (GPU_POWER_MAX - GPU_POWER_HIGH) + 80 ))
        gpu_based_speed=$(( scale_factor * 255 / 100 ))
    elif [[ $gpu_power -ge $GPU_POWER_MEDIUM ]]; then
        # 300-449W: Scale 60-80% based on power  
        local scale_factor=$(( (gpu_power - GPU_POWER_MEDIUM) * 20 / (GPU_POWER_HIGH - GPU_POWER_MEDIUM) + 60 ))
        gpu_based_speed=$(( scale_factor * 255 / 100 ))
    elif [[ $gpu_power -ge $GPU_POWER_LOW ]]; then
        # 150-299W: Scale 40-60% based on power
        local scale_factor=$(( (gpu_power - GPU_POWER_LOW) * 20 / (GPU_POWER_MEDIUM - GPU_POWER_LOW) + 40 ))
        gpu_based_speed=$(( scale_factor * 255 / 100 ))
    elif [[ $gpu_power -ge $GPU_POWER_IDLE ]]; then
        # 30-149W: Scale 30-40% based on power
        local scale_factor=$(( (gpu_power - GPU_POWER_IDLE) * 10 / (GPU_POWER_LOW - GPU_POWER_IDLE) + 30 ))
        gpu_based_speed=$(( scale_factor * 255 / 100 ))
    else
        # Under 30W: Minimum fans (30%)
        gpu_based_speed=$MIN_CHASSIS_FAN_SPEED
    fi
    
    # Use the higher of GPU-based speed or CPU-based minimum speed
    if [[ $cpu_min_speed -gt $gpu_based_speed ]]; then
        echo $cpu_min_speed
    else
        echo $gpu_based_speed
    fi
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Restoring automatic fan control...${NC}"
    set_chassis_fans 0 5  # Return to auto mode
    echo -e "${GREEN}Fan control restored to automatic mode${NC}"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Function to load NCT6775 driver if not already loaded
load_nct6775_driver() {
    if ! lsmod | grep -q nct6775; then
        echo -e "${YELLOW}NCT6775 driver not loaded. Loading driver...${NC}"
        if modprobe nct6775 2>/dev/null; then
            echo -e "${GREEN}✅ NCT6775 driver loaded successfully${NC}"
            sleep 2  # Give driver time to initialize
        else
            echo -e "${RED}❌ Failed to load NCT6775 driver${NC}"
            echo "You may need to install the driver or check hardware compatibility"
            return 1
        fi
    else
        echo -e "${GREEN}✅ NCT6775 driver already loaded${NC}"
    fi
    return 0
}

# Function to detect the correct NCT hardware monitor path
detect_nct6775_hwmon_path() {
    local hwmon_path=""
    
    # Look for NCT hardware monitor paths (supports nct6775, nct6798, etc.)
    for hwmon in /sys/class/hwmon/hwmon*; do
        if [[ -e "$hwmon/name" ]]; then
            local name=$(cat "$hwmon/name" 2>/dev/null)
            if [[ "$name" =~ ^nct67[0-9][0-9]$ ]]; then
                # Verify it has the required PWM controls
                if [[ -e "$hwmon/pwm1" && -e "$hwmon/pwm1_enable" ]]; then
                    hwmon_path="$hwmon"
                    echo -e "${GREEN}✅ Found NCT hardware monitor ($name): $hwmon_path${NC}" >&2
                    break
                fi
            fi
        fi
    done
    
    if [[ -z "$hwmon_path" ]]; then
        echo -e "${RED}❌ No NCT hardware monitor found${NC}"
        echo "Available hardware monitors:"
        for hwmon in /sys/class/hwmon/hwmon*; do
            if [[ -e "$hwmon/name" ]]; then
                local name=$(cat "$hwmon/name" 2>/dev/null)
                echo "  $hwmon: $name"
            fi
        done
        return 1
    fi
    
    echo "$hwmon_path"
    return 0
}

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script needs to run with sudo to control fans${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Load NCT6775 driver if needed
if ! load_nct6775_driver; then
    exit 1
fi

# Auto-detect the correct hardware monitor path
echo -e "${BLUE}🔍 Auto-detecting NCT6775 hardware monitor path...${NC}"
DETECTED_HWMON_PATH=$(detect_nct6775_hwmon_path)
if [[ $? -eq 0 ]]; then
    HWMON_PATH="$DETECTED_HWMON_PATH"
    echo -e "${GREEN}Using detected path: $HWMON_PATH${NC}"
else
    echo -e "${YELLOW}Auto-detection failed. Trying configured path: $HWMON_PATH${NC}"
    # Check if the originally configured hwmon path exists
    if [[ ! -d "$HWMON_PATH" ]]; then
        echo -e "${RED}Hardware monitor path not found: $HWMON_PATH${NC}"
        echo "Available hardware monitors:"
        ls -la /sys/class/hwmon/ 2>/dev/null || echo "None found"
        exit 1
    fi
fi

echo -e "${GREEN}🌪️  GPU-Chassis Fan Controller Started (Power + Temperature Based)${NC}"
echo -e "${BLUE}GPU Emergency Temp: ${GPU_TEMP_THRESHOLD}°C | CPU Emergency Temp: ${CPU_TEMP_THRESHOLD}°C${NC}"
echo -e "${BLUE}CPU Temp Zones: ${CPU_TEMP_LOW}°C-${CPU_TEMP_MEDIUM}°C-${CPU_TEMP_HIGH}°C (35%-45%-60% min fan)${NC}"
echo -e "${BLUE}GPU Power Zones: ${GPU_POWER_IDLE}W-${GPU_POWER_LOW}W-${GPU_POWER_MEDIUM}W-${GPU_POWER_HIGH}W-${GPU_POWER_MAX}W${NC}"
echo -e "${BLUE}GPU Fan Scaling: 30%-40%-60%-80%-100%${NC}"
echo -e "${BLUE}Check Interval: ${CHECK_INTERVAL} seconds${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop and restore automatic fan control${NC}"
echo ""

# Main monitoring loop
while true; do
    # Get GPU metrics (temp, fan_speed, power, mem_used, mem_total)
    GPU_DATA=$(nvidia-smi --query-gpu=temperature.gpu,fan.speed,power.draw,memory.used,memory.total --format=csv,noheader,nounits)
    
    if [[ -z "$GPU_DATA" ]]; then
        echo -e "${RED}Failed to get GPU data from nvidia-smi${NC}"
        sleep $CHECK_INTERVAL
        continue
    fi
    
    # Parse GPU data
    IFS=',' read -r GPU_TEMP GPU_FAN_SPEED POWER_DRAW MEM_USED MEM_TOTAL <<< "$GPU_DATA"
    
    # Remove spaces
    GPU_TEMP=$(echo $GPU_TEMP | tr -d ' ')
    GPU_FAN_SPEED=$(echo $GPU_FAN_SPEED | tr -d ' ')
    POWER_DRAW=$(echo $POWER_DRAW | tr -d ' ')
    MEM_USED=$(echo $MEM_USED | tr -d ' ')
    
    # Get CPU temperature
    CPU_TEMP=$(get_cpu_temperature)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Warning: Failed to read CPU temperature${NC}"
        CPU_TEMP=0
    fi
    
    # Calculate appropriate chassis fan speed based on power consumption and temperatures
    CHASSIS_PWM=$(calculate_fan_speed $GPU_TEMP $GPU_FAN_SPEED $POWER_DRAW $CPU_TEMP)
    CHASSIS_PERCENT=$(( CHASSIS_PWM * 100 / 255 ))
    
    # Set chassis fan speed
    set_chassis_fans $CHASSIS_PWM 1
    
    # Get current chassis fan speeds for display
    CHASSIS_SPEEDS=$(get_chassis_fan_speeds)
    
    # Determine power zone and status
    POWER_INT=${POWER_DRAW%.*}  # Remove decimal part
    
    # Determine CPU temperature color
    if [[ $CPU_TEMP -ge $CPU_TEMP_THRESHOLD ]]; then
        CPU_COLOR=$RED
    elif [[ $CPU_TEMP -ge $CPU_TEMP_HIGH ]]; then
        CPU_COLOR=$YELLOW
    elif [[ $CPU_TEMP -ge $CPU_TEMP_MEDIUM ]]; then
        CPU_COLOR=$YELLOW
    else
        CPU_COLOR=$GREEN
    fi
    
    # Determine overall status (prioritize emergency temps, then GPU power, then CPU temp influence)
    if [[ $GPU_TEMP -ge $GPU_TEMP_THRESHOLD ]] || [[ $CPU_TEMP -ge $CPU_TEMP_THRESHOLD ]]; then
        TEMP_COLOR=$RED
        if [[ $GPU_TEMP -ge $GPU_TEMP_THRESHOLD ]] && [[ $CPU_TEMP -ge $CPU_TEMP_THRESHOLD ]]; then
            STATUS="🔥 EMERGENCY - GPU+CPU HOT"
        elif [[ $GPU_TEMP -ge $GPU_TEMP_THRESHOLD ]]; then
            STATUS="🔥 EMERGENCY - GPU HOT"
        else
            STATUS="🔥 EMERGENCY - CPU HOT"
        fi
    elif [[ $POWER_INT -ge $GPU_POWER_MAX ]]; then
        TEMP_COLOR=$RED
        STATUS="⚡ MAXIMUM POWER"
    elif [[ $POWER_INT -ge $GPU_POWER_HIGH ]]; then
        TEMP_COLOR=$YELLOW
        STATUS="🚀 HIGH POWER"
    elif [[ $POWER_INT -ge $GPU_POWER_MEDIUM ]]; then
        TEMP_COLOR=$YELLOW
        STATUS="⚠️  MEDIUM POWER"
    elif [[ $CPU_TEMP -ge $CPU_TEMP_HIGH ]]; then
        TEMP_COLOR=$YELLOW
        STATUS="🌡️  CPU HOT - MIN FAN"
    elif [[ $POWER_INT -ge $GPU_POWER_LOW ]]; then
        TEMP_COLOR=$GREEN
        STATUS="📈 LOW POWER"
    elif [[ $CPU_TEMP -ge $CPU_TEMP_MEDIUM ]]; then
        TEMP_COLOR=$GREEN
        STATUS="🌡️  CPU WARM - MIN FAN"
    else
        TEMP_COLOR=$GREEN
        STATUS="💤 IDLE/MINIMAL"
    fi
    
    # Display current status
    echo -e "${BLUE}$(date '+%H:%M:%S')${NC} | GPU: ${TEMP_COLOR}${GPU_TEMP}°C${NC} ${GPU_FAN_SPEED}% | CPU: ${CPU_COLOR}${CPU_TEMP}°C${NC} | Power: ${POWER_DRAW}W | Chassis: ${CHASSIS_PERCENT}% | $STATUS"
    echo -e "  └─ $CHASSIS_SPEEDS"
    
    sleep $CHECK_INTERVAL
done