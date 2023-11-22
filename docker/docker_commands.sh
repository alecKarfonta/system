# Build api image
sudo docker build --tag py:1.0 . -f /home/alec/git/talker/Dockerfile_pytorch_2.sh

sudo nvidia-docker run -ti --rm --publish 8888:8888 -p 5900:5900 -v /home/alec/git:/py/ -w /py py:1.2

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