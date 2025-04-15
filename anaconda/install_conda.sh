wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

chmod +x Miniconda3-latest-Linux-x86_64.sh

./Miniconda3-latest-Linux-x86_64.sh

conda --version


# If conda did not automatically add conda to your PATH, add it manually

source ~/miniconda3/bin/activate


# Add conda to PATH
export PATH="/home/ubuntu/miniconda3/bin:$PATH"

# Verify conda installation
conda --version
