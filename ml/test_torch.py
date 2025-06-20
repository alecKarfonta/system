import torch

# Check if CUDA (NVIDIA GPU support) is available
print(f"CUDA available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    # Get the current device
    current_device = torch.cuda.current_device()
    print(f"Current CUDA device: {current_device}")
    
    # Get the name of the current device
    device_name = torch.cuda.get_device_name(current_device)
    print(f"Device name: {device_name}")
    
    # Create tensors on CPU and GPU to test basic operations
    cpu_tensor = torch.rand(3, 3)
    gpu_tensor = cpu_tensor.cuda()
    
    print("\nCPU tensor:")
    print(cpu_tensor)
    
    print("\nGPU tensor:")
    print(gpu_tensor)
    
    # Test a simple operation on GPU
    result = gpu_tensor * 2
    print("\nGPU computation result:")
    print(result)
    
    # Check if the computation was actually done on GPU
    print(f"\nResult is on GPU: {result.is_cuda}")
else:
    print("No CUDA-capable GPU detected. PyTorch will run on CPU only.")