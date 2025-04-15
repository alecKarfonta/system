#!/usr/bin/env python3
import os
import sys
import json
import platform
import subprocess
import requests
from datetime import datetime

def run_command(command):
    """Run a shell command and return its output."""
    try:
        result = subprocess.run(command, shell=True, check=True, 
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               text=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error executing {command}: {e.stderr}"

def get_nvidia_info():
    """Get NVIDIA GPU information if available."""
    info = {}
    
    # Check if nvidia-smi is available
    nvidia_smi = run_command("which nvidia-smi")
    if "Error" in nvidia_smi:
        return {"error": "nvidia-smi not found. NVIDIA GPU may not be present or drivers not installed."}
    
    # Get NVIDIA driver version
    driver_version = run_command("nvidia-smi --query-gpu=driver_version --format=csv,noheader")
    if not "Error" in driver_version:
        info["driver_version"] = driver_version
    
    # Get CUDA version
    cuda_version = run_command("nvidia-smi --query-gpu=cuda_version --format=csv,noheader")
    if not "Error" in cuda_version:
        info["cuda_version"] = cuda_version
    
    # Get GPU model
    gpu_model = run_command("nvidia-smi --query-gpu=name --format=csv,noheader")
    if not "Error" in gpu_model:
        info["gpu_model"] = gpu_model
    
    # Get GPU memory
    gpu_memory = run_command("nvidia-smi --query-gpu=memory.total --format=csv,noheader")
    if not "Error" in gpu_memory:
        info["gpu_memory"] = gpu_memory
    
    return info

def get_system_info():
    """Get basic system information."""
    info = {
        "platform": platform.platform(),
        "python_version": platform.python_version(),
        "processor": platform.processor(),
        "cpu_count": os.cpu_count(),
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    
    # Try to get memory info
    try:
        if platform.system() == "Linux":
            mem_info = run_command("free -h | grep Mem")
            if not "Error" in mem_info:
                info["memory"] = mem_info.split()[1]
        elif platform.system() == "Darwin":  # macOS
            mem_info = run_command("sysctl -n hw.memsize")
            if not "Error" in mem_info:
                info["memory"] = f"{int(mem_info) / (1024**3):.2f} GB"
        elif platform.system() == "Windows":
            mem_info = run_command("wmic computersystem get totalphysicalmemory")
            if not "Error" in mem_info:
                lines = mem_info.strip().split('\n')
                if len(lines) > 1:
                    info["memory"] = f"{int(lines[1]) / (1024**3):.2f} GB"
    except Exception as e:
        info["memory_error"] = str(e)
    
    return info

def check_ollama():
    """Check if Ollama is installed and running."""
    info = {}
    
    # Check if Ollama is installed
    ollama_path = run_command("which ollama")
    if "Error" in ollama_path:
        return {"error": "Ollama not found in PATH. Please ensure it's installed."}
    
    info["path"] = ollama_path
    
    # Check Ollama version
    version = run_command("ollama --version")
    if not "Error" in version:
        info["version"] = version
    
    # Check if Ollama service is running
    try:
        response = requests.get("http://localhost:11434/api/tags")
        if response.status_code == 200:
            info["status"] = "running"
            info["models"] = response.json()
        else:
            info["status"] = f"API responded with status code {response.status_code}"
    except requests.exceptions.ConnectionError:
        info["status"] = "not running or not accepting connections"
    except Exception as e:
        info["status_error"] = str(e)
    
    return info

def run_inference_test(model="llama3"):
    """Run a simple inference test with Ollama."""
    try:
        print(f"\nTesting inference with model '{model}'...")
        
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": model,
                "prompt": "Respond with a short sentence about AI.",
                "stream": False
            },
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            return {
                "success": True,
                "response": result.get("response", "No response text"),
                "eval_count": result.get("eval_count", "unknown"),
                "eval_duration": result.get("eval_duration", "unknown")
            }
        else:
            return {
                "success": False,
                "error": f"API returned status code {response.status_code}",
                "details": response.text
            }
    except requests.exceptions.ConnectionError:
        return {
            "success": False, 
            "error": "Failed to connect to Ollama API. Is the service running?"
        }
    except requests.exceptions.Timeout:
        return {
            "success": False,
            "error": "Request timed out. Model may be loading or too large for your system."
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

def main():
    print("\n===== OLLAMA SYSTEM TEST =====")
    print("\n1. System Information:")
    system_info = get_system_info()
    for key, value in system_info.items():
        print(f"  {key}: {value}")
    
    print("\n2. NVIDIA GPU Information:")
    nvidia_info = get_nvidia_info()
    if "error" in nvidia_info:
        print(f"  {nvidia_info['error']}")
    else:
        for key, value in nvidia_info.items():
            print(f"  {key}: {value}")
    
    print("\n3. Ollama Installation:")
    ollama_info = check_ollama()
    if "error" in ollama_info:
        print(f"  {ollama_info['error']}")
        print("\nOllama doesn't appear to be installed or in your PATH.")
        print("Please install Ollama from https://ollama.com")
        return
    
    for key, value in ollama_info.items():
        if key == "models":
            print("  Available models:")
            if "models" in value:
                for model in value["models"]:
                    print(f"    - {model.get('name', 'unknown')}")
            else:
                print("    No models found or unable to parse model list")
        else:
            print(f"  {key}: {value}")
    
    # Try to run inference if Ollama is running
    if ollama_info.get("status") == "running":
        # Get available models
        available_models = []
        if "models" in ollama_info and "models" in ollama_info["models"]:
            available_models = [model.get("name") for model in ollama_info["models"]["models"] if "name" in model]
        
        # Choose a model to test
        test_model = "llama3"  # Default
        if available_models:
            test_model = available_models[0]  # Use the first available model
            
        inference_result = run_inference_test(test_model)
        
        print(f"\n4. Inference Test (using {test_model}):")
        if inference_result["success"]:
            print(f"  Success!")
            print(f"  Model response: \"{inference_result['response']}\"")
            print(f"  Tokens evaluated: {inference_result['eval_count']}")
            print(f"  Evaluation time: {inference_result['eval_duration']}")
        else:
            print(f"  Failed: {inference_result['error']}")
            if "details" in inference_result:
                print(f"  Details: {inference_result['details']}")
    else:
        print("\n4. Inference Test: Skipped (Ollama service not running)")
    
    print("\n===== TEST COMPLETE =====")

if __name__ == "__main__":
    main()