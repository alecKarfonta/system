#!/bin/bash
# vLLM Setup and Diagnostic Script for Ubuntu
# This script will:
# 1. Check Ubuntu version and system info
# 2. Check for available GPUs and details
# 3. Check NVIDIA driver version
# 4. Check CUDA version and compatibility
# 5. Setup Python environment and install vLLM based on user preference
# 6. Run a basic inference test with vLLM

# Set up error handling
set -e
trap 'echo "An error occurred. Exiting..."; exit 1' ERR

# Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== vLLM Setup and Diagnostic Script for Ubuntu ===${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a package is installed
package_installed() {
    dpkg -l "$1" >/dev/null 2>&1
}

# Function to install vLLM
install_vllm() {
    local install_method=$1
    local version=$2
    local branch=$3

    case $install_method in
        "pip")
            echo -e "\n${YELLOW}Installing vLLM from pip (version: $version)...${NC}"
            pip install "vllm==$version"
            ;;
        "source")
            echo -e "\n${YELLOW}Installing vLLM from source...${NC}"
            git clone https://github.com/vllm-project/vllm.git
            cd vllm
            if [ ! -z "$branch" ]; then
                git checkout $branch
            fi
            pip install -e .
            cd ..
            ;;
        "branch")
            echo -e "\n${YELLOW}Installing vLLM from specific branch: $branch...${NC}"
            git clone -b $branch https://github.com/vllm-project/vllm.git
            cd vllm
            pip install -e .
            cd ..
            ;;
        *)
            echo -e "${RED}Invalid installation method${NC}"
            exit 1
            ;;
    esac
}

# 1. Check Ubuntu version and system info
echo -e "\n${GREEN}=== System Information ===${NC}"
echo -e "${YELLOW}Ubuntu Version:${NC}"
lsb_release -a

echo -e "\n${YELLOW}Kernel Version:${NC}"
uname -a

echo -e "\n${YELLOW}CPU Information:${NC}"
lscpu | grep -E "Model name|CPU\(s\)|Thread|Core|Socket"

echo -e "\n${YELLOW}Memory Information:${NC}"
free -h

echo -e "\n${YELLOW}Disk Space:${NC}"
df -h | grep -E "Filesystem|/$"

# 2. Check for available GPUs
echo -e "\n${GREEN}=== GPU Information ===${NC}"
if command_exists nvidia-smi; then
    echo -e "${YELLOW}NVIDIA GPUs Detected:${NC}"
    nvidia-smi
    
    echo -e "\n${YELLOW}GPU Memory Usage:${NC}"
    nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv
    
    echo -e "\n${YELLOW}Detailed GPU Information:${NC}"
    nvidia-smi -a | grep -E "Product Name|CUDA Version|Driver Version|GPU UUID|Bus-Id|Memory Usage"
else
    echo -e "${RED}NVIDIA-SMI not found. NVIDIA GPUs may not be available or drivers not installed.${NC}"
fi

# 3. Check NVIDIA driver version
echo -e "\n${GREEN}=== NVIDIA Driver Information ===${NC}"
if command_exists nvidia-smi; then
    DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader -i 0)
    echo -e "${YELLOW}NVIDIA Driver Version:${NC} $DRIVER_VERSION"
else
    echo -e "${RED}NVIDIA driver not detected.${NC}"
fi

# 4. Check CUDA version
echo -e "\n${GREEN}=== CUDA Information ===${NC}"
if [ -x "$(command -v nvcc)" ]; then
    echo -e "${YELLOW}NVCC Version:${NC}"
    nvcc --version
    
    echo -e "\n${YELLOW}CUDA Libraries:${NC}"
    ldconfig -p | grep cuda
else
    echo -e "${RED}NVCC not found. CUDA toolkit may not be installed.${NC}"
    if [ -d /usr/local/cuda ]; then
        echo -e "${YELLOW}CUDA directory exists:${NC}"
        ls -la /usr/local/cuda
        echo -e "\n${YELLOW}CUDA Version (from directory):${NC}"
        cat /usr/local/cuda/version.txt 2>/dev/null || echo "No version.txt found"
    fi
fi

# Check if CUDA is in PATH
echo -e "\n${YELLOW}CUDA in PATH:${NC}"
echo $PATH | grep -q "cuda" && echo "CUDA is in PATH" || echo "CUDA is NOT in PATH"

# 5. Setup Python environment and install vLLM
echo -e "\n${GREEN}=== Python Environment Setup ===${NC}"

# Check Python version
echo -e "${YELLOW}Python Version:${NC}"
python3 --version || echo "Python3 not found"

# Install required packages if not already installed
echo -e "\n${YELLOW}Installing required packages...${NC}"
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv git

# Create a virtual environment
echo -e "\n${YELLOW}Creating Python virtual environment...${NC}"
python3 -m venv vllm_env
source vllm_env/bin/activate

echo -e "\n${YELLOW}Python Virtual Environment:${NC}"
which python
python --version

# Install PyTorch with CUDA support
echo -e "\n${YELLOW}Installing PyTorch with CUDA support...${NC}"
echo -e "Choose PyTorch installation method:"
echo -e "1) Install stable PyTorch (recommended)"
echo -e "2) Install nightly PyTorch (latest features, may be unstable)"
read -p "Enter your choice (1-2): " torch_choice

case $torch_choice in
    1)
        echo -e "${YELLOW}Installing stable PyTorch...${NC}"
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
        ;;
    2)
        echo -e "${YELLOW}Installing nightly PyTorch...${NC}"
        pip install --upgrade --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
        ;;
    *)
        echo -e "${RED}Invalid choice, defaulting to stable PyTorch${NC}"
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
        ;;
esac

# Check PyTorch CUDA availability
echo -e "\n${YELLOW}Checking PyTorch CUDA availability:${NC}"
python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda}'); print(f'CUDA device count: {torch.cuda.device_count()}'); [print(f'CUDA device {i}: {torch.cuda.get_device_name(i)}') for i in range(torch.cuda.device_count())]"

# Prompt user for installation method
echo -e "\n${GREEN}=== vLLM Installation Options ===${NC}"
echo -e "Choose installation method:"
echo -e "1) Install from pip (with version)"
echo -e "2) Install from source"
echo -e "3) Install from specific branch"
read -p "Enter your choice (1-3): " install_choice

case $install_choice in
    1)
        read -p "Enter vLLM version (e.g., 0.2.0): " vllm_version
        install_vllm "pip" "$vllm_version" ""
        ;;
    2)
        install_vllm "source" "" ""
        ;;
    3)
        read -p "Enter branch name (e.g., main, blackwell): " branch_name
        install_vllm "branch" "" "$branch_name"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Check vLLM installation
echo -e "\n${YELLOW}Checking vLLM installation:${NC}"
python -c "import vllm; print(f'vLLM version: {vllm.__version__}')"

# Return to original directory
cd ..

# 6. Run a basic inference test
echo -e "\n${GREEN}=== Basic vLLM Inference Test ===${NC}"
echo -e "${YELLOW}Running vLLM with a sample model...${NC}"

# Create a test script
cat > vllm_test.py << 'EOF'
from vllm import LLM, SamplingParams
import time

def run_test():
    try:
        # Initialize the LLM with a small model
        print("Loading model...")
        model_name = "facebook/opt-125m"  # Small model for testing
        llm = LLM(model=model_name)
        
        # Create sampling parameters
        sampling_params = SamplingParams(
            temperature=0.7,
            top_p=0.95,
            max_tokens=100
        )
        
        # Run inference
        print("Running inference...")
        start_time = time.time()
        prompts = ["Write a short poem about artificial intelligence:"]
        outputs = llm.generate(prompts, sampling_params)
        end_time = time.time()
        
        # Print results
        print(f"Inference time: {end_time - start_time:.2f} seconds")
        print("\nOutput:")
        for output in outputs:
            print(f"Prompt: {output.prompt}")
            print(f"Generated text: {output.outputs[0].text}")
            
        return True
    except Exception as e:
        print(f"Error during inference test: {e}")
        return False

if __name__ == "__main__":
    success = run_test()
    print(f"\nTest {'passed' if success else 'failed'}")
EOF

# Run the test script
python vllm_test.py

# Show how to run vLLM with a larger model
echo -e "\n${GREEN}=== Running vLLM with Custom Models ===${NC}"
echo -e "To run vLLM with a larger model, use the following command:"
echo -e "${BLUE}python -m vllm.entrypoints.openai.api_server --model meta-llama/Llama-2-7b-chat-hf --tensor-parallel-size 1${NC}"
echo -e "Adjust tensor-parallel-size based on your GPU count and model size"

echo -e "\n${GREEN}=== Troubleshooting Tips ===${NC}"
echo -e "1. If you encounter CUDA errors, check driver-CUDA compatibility: https://docs.nvidia.com/deploy/cuda-compatibility/"
echo -e "2. For out-of-memory issues, reduce the model size or batch size"
echo -e "3. For maximum performance, ensure you're using NVIDIA drivers ≥ 525 and CUDA ≥ 11.8"
echo -e "4. Run this script with 'bash -x' for verbose debugging output"

echo -e "\n${GREEN}=== Environment Variables for vLLM ===${NC}"
echo -e "You may need to set these environment variables for better performance:"
echo -e "export CUDA_VISIBLE_DEVICES=0,1,2,3  # Specify which GPUs to use"
echo -e "export VLLM_USE_ASYNC_COMPUTE=1      # Enable async compute"
echo -e "export VLLM_WORKER_USE_RAY=1         # Use Ray for worker management"

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo -e "Your vLLM environment is ready. Use the virtual environment with 'source vllm_env/bin/activate'"