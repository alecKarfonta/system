#!/usr/bin/env python3
"""Quick API test for Ollama RTX 5090 deployment"""

import requests
import json
import time

def test_health():
    """Test health endpoint"""
    try:
        response = requests.get("http://localhost:11434/api/health", timeout=5)
        if response.status_code == 200:
            print("✅ Health check passed")
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Health check error: {e}")
        return False

def test_models():
    """Test models endpoint"""
    try:
        response = requests.get("http://localhost:11434/api/tags", timeout=10)
        if response.status_code == 200:
            data = response.json()
            models = data.get('models', [])
            print(f"✅ Found {len(models)} models:")
            for model in models:
                print(f"  - {model['name']}")
            return len(models) > 0
        else:
            print(f"❌ Models endpoint failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Models endpoint error: {e}")
        return False

def test_openai_compatibility():
    """Test OpenAI compatible endpoint"""
    try:
        response = requests.get("http://localhost:11434/v1/models", timeout=10)
        if response.status_code == 200:
            data = response.json()
            models = data.get('data', [])
            print(f"✅ OpenAI API: Found {len(models)} models")
            for model in models:
                print(f"  - {model['id']}")
            return len(models) > 0
        else:
            print(f"❌ OpenAI API failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ OpenAI API error: {e}")
        return False

def test_simple_chat():
    """Test a simple chat completion"""
    try:
        # First check if we have any models
        models_response = requests.get("http://localhost:11434/api/tags", timeout=10)
        if models_response.status_code != 200:
            print("❌ Cannot test chat - no models endpoint")
            return False
        
        models = models_response.json().get('models', [])
        if not models:
            print("❌ Cannot test chat - no models available")
            return False
        
        # Use the first available model
        model_name = models[0]['name']
        print(f"🧪 Testing chat with model: {model_name}")
        
        payload = {
            "model": model_name,
            "messages": [
                {"role": "user", "content": "Say hello in one word."}
            ],
            "stream": False
        }
        
        response = requests.post(
            "http://localhost:11434/api/chat",
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            content = data.get('message', {}).get('content', '')
            print(f"✅ Chat response: {content[:100]}...")
            return True
        else:
            print(f"❌ Chat failed: {response.status_code}")
            print(response.text[:200])
            return False
            
    except Exception as e:
        print(f"❌ Chat error: {e}")
        return False

def main():
    """Run all tests"""
    print("🧪 Testing Ollama RTX 5090 Deployment")
    print("=" * 50)
    
    tests = [
        ("Health Check", test_health),
        ("Models List", test_models),
        ("OpenAI Compatibility", test_openai_compatibility),
        ("Simple Chat", test_simple_chat)
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n🔍 {test_name}...")
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ {test_name} crashed: {e}")
            results.append((test_name, False))
        
        time.sleep(1)  # Brief pause between tests
    
    print("\n" + "=" * 50)
    print("📊 Test Summary:")
    passed = 0
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {status}: {test_name}")
        if result:
            passed += 1
    
    print(f"\nResults: {passed}/{len(results)} tests passed")
    
    if passed == len(results):
        print("\n🎉 All tests passed! Ollama deployment is working correctly.")
    else:
        print("\n⚠️  Some tests failed. Check the logs above.")

if __name__ == "__main__":
    main()