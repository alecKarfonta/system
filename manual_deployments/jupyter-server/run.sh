
# Stop and remove the existing container if it exists
if [ "$(docker ps -a -q -f name=jupyter-pytorch)" ]; then
    echo "Stopping and removing existing container..."
    docker stop jupyter-pytorch
    docker rm jupyter-pytorch
fi


#!/bin/bash
docker run -d \
  --name jupyter-pytorch \
  --gpus all \
  -p 8888:8888 \
  -p 3141:3141 \
  -p 6901:6901 \
  -p 5901:5901 \
  -p 5900:5900 \
  -p 2225:22 \
  -v "$(pwd)/notebooks:/workspace/notebooks" \
  jupyter-pytorch:latest