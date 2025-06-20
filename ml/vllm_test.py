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
