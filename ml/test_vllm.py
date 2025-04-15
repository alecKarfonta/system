#!/usr/bin/env python3
"""
vLLM Inference Test Script
This script tests vLLM inference capabilities with a small model.
"""

import time
import argparse
from vllm import LLM, SamplingParams

def parse_args():
    parser = argparse.ArgumentParser(description="Test vLLM inference")
    parser.add_argument("--model", type=str, default="facebook/opt-125m", 
                        help="Model to use for inference (default: facebook/opt-125m)")
    parser.add_argument("--prompt", type=str, default="Write a short poem about artificial intelligence:", 
                        help="Prompt to use for inference")
    parser.add_argument("--max-tokens", type=int, default=100, 
                        help="Maximum number of tokens to generate")
    parser.add_argument("--temperature", type=float, default=0.7, 
                        help="Sampling temperature")
    parser.add_argument("--top-p", type=float, default=0.95, 
                        help="Top-p sampling parameter")
    return parser.parse_args()

def run_inference_test(model_name, prompt, max_tokens, temperature, top_p):
    """Run a vLLM inference test with the specified parameters."""
    try:
        print(f"Loading model: {model_name}")
        llm = LLM(model=model_name)
        
        # Create sampling parameters
        sampling_params = SamplingParams(
            temperature=temperature,
            top_p=top_p,
            max_tokens=max_tokens
        )
        
        # Run inference
        print("Running inference...")
        start_time = time.time()
        prompts = [prompt]
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

def main():
    args = parse_args()
    
    print("=== vLLM Inference Test ===")
    print(f"Model: {args.model}")
    print(f"Prompt: {args.prompt}")
    print(f"Parameters: max_tokens={args.max_tokens}, temperature={args.temperature}, top_p={args.top_p}")
    
    success = run_inference_test(
        model_name=args.model,
        prompt=args.prompt,
        max_tokens=args.max_tokens,
        temperature=args.temperature,
        top_p=args.top_p
    )
    
    print(f"\nTest {'passed' if success else 'failed'}")

if __name__ == "__main__":
    main() 