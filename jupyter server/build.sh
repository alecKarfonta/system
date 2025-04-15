#!/bin/bash

# Build the Docker image
docker build -t jupyter-pytorch \
    --build-arg PYTHON_VERSION=3.10 \
    -f Dockerfile_pytorch_2.sh .