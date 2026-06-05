# Machine Learning Tools

Comprehensive setup for ML development including CUDA, PyTorch, vLLM, and related tools.

## 📋 Overview

This component provides automated setup for machine learning development tools:
- **vLLM**: High-performance LLM inference engine
- **PyTorch**: Deep learning framework with CUDA support
- **CUDA**: GPU computing platform
- **Model Testing**: Validation scripts for ML stack

## 🚀 Quick Start

```bash
# Install vLLM with full diagnostic
./install_vllm.sh

# Test PyTorch installation
python test_torch.py

# Test vLLM inference
python test_vllm_inference.py
```

## 📂 Files

- `install_vllm.sh` - Comprehensive vLLM installation with diagnostics
- `test_torch.py` - PyTorch CUDA testing script
- `test_vllm_inference.py` - vLLM inference testing
- `vllm_test.py` - Additional vLLM testing utilities

## 🛠️ Installation

### Automatic Installation (Recommended)
```bash
./install_vllm.sh
```

This script will:
1. ✅ Check system information and GPU availability
2. ✅ Verify NVIDIA drivers and CUDA installation
3. ✅ Setup Python virtual environment
4. ✅ Install PyTorch with CUDA support
5. ✅ Install vLLM (pip, source, or branch)
6. ✅ Run comprehensive tests

### Manual Installation Steps

#### 1. Setup Python Environment
```bash
python3 -m venv vllm_env
source vllm_env/bin/activate
```

#### 2. Install PyTorch
```bash
# Stable version
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Or nightly version
pip install --upgrade --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
```

#### 3. Install vLLM
```bash
# From PyPI
pip install vllm

# From source
git clone https://github.com/vllm-project/vllm.git
cd vllm
pip install -e .
```

## 🔧 Configuration

### Environment Variables
```bash
# CUDA configuration
export CUDA_VISIBLE_DEVICES=0,1,2,3  # Use specific GPUs
export CUDA_CACHE_DISABLE=1          # Disable CUDA cache

# vLLM configuration
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_LOGGING_LEVEL=INFO
```

### GPU Memory Management
```bash
# Set GPU memory fraction
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

# Enable memory pool
export VLLM_USE_TRITON_FLASH_ATTN=1
```

## 🧪 Testing Your Setup

### Test PyTorch CUDA
```bash
python test_torch.py
```

Expected output:
```
PyTorch version: 2.1.0+cu118
CUDA available: True
CUDA version: 11.8
CUDA device count: 4
GPU 0: NVIDIA GeForce RTX 4090
GPU 1: NVIDIA GeForce RTX 4090
...
```

### Test vLLM Inference
```bash
python test_vllm_inference.py
```

Expected output:
```
vLLM version: 0.2.0
Loading model: microsoft/DialoGPT-medium
Generated text: Hello, how can I help you today?
```

## 🚀 Usage Examples

### Basic vLLM Server
```python
from vllm import LLM, SamplingParams

# Create LLM instance
llm = LLM(model="microsoft/DialoGPT-medium")

# Define sampling parameters
sampling_params = SamplingParams(temperature=0.8, top_p=0.95)

# Generate text
prompts = ["Hello, my name is", "The future of AI is"]
outputs = llm.generate(prompts, sampling_params)

for output in outputs:
    print(f"Prompt: {output.prompt!r}")
    print(f"Generated text: {output.outputs[0].text!r}")
```

### vLLM API Server
```bash
# Start API server
python -m vllm.entrypoints.api_server \
    --model microsoft/DialoGPT-medium \
    --port 8000 \
    --host 0.0.0.0
```

### Distributed Inference
```bash
# Multi-GPU inference
python -m vllm.entrypoints.api_server \
    --model microsoft/DialoGPT-medium \
    --tensor-parallel-size 4 \
    --port 8000
```

## 🔍 Troubleshooting

### Issue: CUDA out of memory
```bash
# Reduce model size or batch size
export CUDA_VISIBLE_DEVICES=0  # Use single GPU
# Or use model quantization
```

### Issue: vLLM installation fails
```bash
# Install with verbose output
pip install vllm -v

# Install from source with clean build
pip install -e . --no-build-isolation
```

### Issue: Model loading fails
```bash
# Check model compatibility
python -c "from transformers import AutoTokenizer; AutoTokenizer.from_pretrained('model-name')"

# Use alternative model
python test_vllm_inference.py --model microsoft/DialoGPT-small
```

## 📈 Performance Tips

### Optimize GPU Memory
```python
# Use quantization
llm = LLM(model="model-name", quantization="awq")

# Adjust block size
llm = LLM(model="model-name", block_size=16)
```

### Optimize Inference Speed
```python
# Use tensor parallelism
llm = LLM(model="model-name", tensor_parallel_size=2)

# Optimize batch size
sampling_params = SamplingParams(
    temperature=0.8,
    top_p=0.95,
    max_tokens=100
)
```

## 📚 Additional Resources

- [vLLM Documentation](https://vllm.readthedocs.io/)
- [PyTorch Documentation](https://pytorch.org/docs/)
- [CUDA Toolkit Documentation](https://docs.nvidia.com/cuda/)
- [Model Compatibility List](https://vllm.readthedocs.io/en/latest/models/supported_models.html)

---

**Next Steps**: After ML setup, consider configuring [Jupyter](../jupyter/) for interactive development or [Docker](../docker/) for containerized deployment. 