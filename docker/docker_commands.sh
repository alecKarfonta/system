# Build api image
sudo docker build --tag py:1.0 . -f /home/alec/git/talker/Dockerfile_pytorch_2.sh

sudo nvidia-docker run -ti --rm --publish 8888:8888 -p 5900:5900 -v /home/alec/git:/py/ -w /py py:1.2


sudo docker build --tag dev:1.0 . -f /home/alec/git/system/system/docker/Dockerfile_pytorch_2



sudo docker run --gpus all \
        --ipc=host \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        --runtime=nvidia -it \ 
        --rm --publish 8888:8888 -p 5900:5900 -v /home/alec/git:/py/ -w /py py:1.0

# Start dev container
docker run --rm \
        --name dev \
        --gpus all \
        --ipc=host \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        --publish 8888:8888 \
        -v /home/alec/git:/py/ \
        -w /py \
        -it \
        dev:1.0


sudo docker build --tag reader:1.0 . 

# Start TTS container
docker run --rm \
    --name reader \
    --gpus all \
    --ipc=host \
    --ulimit memlock=-1 \
    --ulimit stack=67108864 \
    --publish 8100:8100 \
    -w /app \
    --entrypoint /bin/bash \
    -e BM_TO_TTS_REDIS_HOST="192.168.1.75" \
    -it \
    reader

sudo docker cp main.py 3c78a400afc1:/app/main.py
sudo docker cp voicebox.py 3c78a400afc1:/app/voicebox.py
sudo docker cp voicebox_config.json 3c78a400afc1:/app/voicebox_config.json

# -ti - Interactive terminal with container


# Build api image
sudo docker build --tag api:1.0 . -f /home/alec/git/talker/Dockerfile_api.sh
# Run api
sudo nvidia-docker run -p 80:80 api:1.0


# Build db image
sudo docker build --tag db:1.0 . -f /home/alec/git/talker/Dockerfile_db.sh
# Run api
sudo docker run -p 80:80 db:1.0






sudo docker build --tag py:1.0 . -f /home/server/git/talker/Dockerfile_pytorch_2.sh
# Run dev
sudo docker run -ti --rm --publish 8888:8888 -p 5900:5900 -v /home/server/git:/py/ -w /py py:1.0


sudo docker exec -it d83f99005dfd bash

# Save container
sudo docker commit d83f99005dfd py:1.0