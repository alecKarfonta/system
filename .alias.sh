
#### System ####
# Update and upgrade the system
alias update='sudo apt update && sudo apt upgrade -y'

# Clean up unused packages
alias cleanup='sudo apt autoremove -y && sudo apt autoclean -y'

# Alias to monitor system resources
alias sys='btop'

# Stop OS front end
#sudo service lightdm stop
alias killg='sudo service gdm stop'
#### \System ####


#### File Management ####
# List files in long format with human-readable sizes
alias ll='ls -alFh'

# Navigate up a directory
alias ..='cd ..'
alias ...='cd ../..'

# Create directories with intermediate directories
alias mkdirp='mkdir -p'
alias own='sudo chown $(whoami):$(id -gn)'
alias addw='sudo chmod +w'
alias addr='sudo chmod +r'
alias addx='sudo chmod +x'
alias subw='sudo chmod -w'
alias subr='sudo chmod -r'
alias subx='sudo chmod -x'
#### \File Management ####


#### Docker ####
alias ds='docker stop'
alias dlog='docker logs -f'
alias dps='docker ps'
alias dcb='docker compose up -d --build'
# List all Docker containers
alias dpsa='docker ps -a'
alias dpsc='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"'
alias dbash='docker exec -it $1 bash'

# Remove a Docker container
alias drm='docker rm'

# Remove a Docker image
alias drmi='docker rmi'

# List all Docker images
alias dim='docker images'

#### \Docker ####


#### SSH ####
# SSH into a common server
alias demo='ssh alec@demo'
alias trip='ssh alec@threadripper'
alias awsgpu='ssh -i /Users/alec/git/mlteam-1.pem ubuntu@raftawsgpu.duckdns.org'
alias awscpu='ssh -i /Users/alec/git/mlteam-1.pem ubuntu@raftawscpu.duckdns.org'

# SSH with a specific identity file
alias sshkey='ssh -i ~/.ssh/your_identity_file username@server_address'
#### \SSH ####


#### Python ####
# Activate a conda environment
alias activate='source activate'

# Deactivate the current conda environment
alias deactivate='source deactivate'

# List all conda environments
alias condaenvs='conda env list'

# Create a new conda environment
alias createenv='conda create --name'
#### \Python ####


#### Jupyter ####
# Jupyter Notebook
alias jn='jupyter notebook'

# Jupyter Lab
alias jl='jupyter lab'

# TensorBoard
alias tb='tensorboard --logdir=logs/'

# Launch VSCode
alias code='code .'

# Start a Python HTTP server (useful for serving files quickly)
alias serve='python3 -m http.server'
#### \Jupyter ####


#### Git ####
# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
#### \Git ####


#### Nvidia ####
# Show NVIDIA GPU status
alias gpustat='nvidia-smi'

# Watch NVIDIA GPU status with updates every 2 seconds
alias gpustatw='watch -n 2 nvidia-smi'

# Display GPU memory usage
alias gpumem='nvidia-smi --query-gpu=memory.used,memory.free --format=csv'

# Monitor GPU processes
alias gpuwatch='watch -n 2 nvidia-smi dmon -s u'
#### \Nvidia ####


#### Kubernetes ####
alias k9=k9s
alias k=kubectl
alias k-log=kubectl logs # [RESOUCE_NAME] Print logs for resource
alias k-tail=kubectl logs -f # [RESOUCE_NAME] Follow logs for a specific pod
alias k-secrets=kubectl get secrets
alias k-events=kubectl get events
alias k-warn=kubectl get events --field-selector type=Warning
alias k-error=kubectl get events --field-selector type=Error
alias kpods=kubectl get pods --all-namespaces
#### \Kubernetes ####


#### Data Fabric ####
alias df-nuke=$DF_HOME/hacks/df_nuke.sh
alias df-create=$DF_HOME/hacks/df_create_kind.sh
alias df-deploy=$DF_HOME/hacks/df_deploy.sh
alias df-creploy="df-create; df-deploy"
#### \Data Fabric ####


#### Dev ####
alias dev='docker run --rm --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 --publish 8888:8888 -v /home/alec/git:/py/ -w /py -d dev:1.0 jupyter notebook --ip=0.0.0.0 --allow-root --no-browser'
#### \Dev ####

