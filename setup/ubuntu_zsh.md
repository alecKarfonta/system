# Ubuntu ZSH Setup Guide

## 1. Update System
First, ensure your system is up to date:
```bash
sudo apt update && sudo apt upgrade -y
```

## 2. Install Core Requirements
Install the essential packages:
```bash
sudo apt install -y zsh git curl wget fzf unzip fonts-powerline
```

## 3. ZSH Configuration
Set ZSH as your default shell:
```bash
chsh -s $(which zsh)
```
> Note: You'll need to log out and back in for this change to take effect.

## 4. Install Zinit
Set up Zinit for plugin management:
```bash
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
mkdir -p "$(dirname $ZINIT_HOME)"
git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
```

## 5. Install Zoxide
Install the smart directory jumper:
```bash
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
```

## 6. Install GitHub CLI
Add GitHub's official repository and install the CLI:
```bash
type -p curl >/dev/null || sudo apt install curl -y
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh -y
```

## 7. Install Kubectl (Optional)
If you need Kubernetes support:
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```

## 8. Install AWS CLI (Optional)
If you need AWS support:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm awscliv2.zip
rm -rf aws/
```

## 9. Install Nerd Fonts
Install a Nerd Font for proper icon support:
```bash
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Meslo.zip
unzip Meslo.zip
rm Meslo.zip
fc-cache -fv
```

## 10. Verify Installations
Check if everything is installed correctly:
```bash
zsh --version
git --version
fzf --version
zoxide --version
gh --version
kubectl version  # if installed
aws --version   # if installed
```

## Post-Installation Steps

1. Log out and log back in for shell changes to take effect

2. When you first launch ZSH, you'll see the Powerlevel10k configuration wizard. Follow the prompts to customize your prompt.

3. Configure GitHub CLI (if installed):
```bash
gh auth login
```

4. Test your AWS configuration (if installed):
```bash
aws configure
```

## Troubleshooting

If you encounter any "command not found" errors after installation:
1. Source your zsh configuration:
```bash
source ~/.zshrc
```

2. Check if the paths are correctly set in ~/.zshrc
3. Verify that all installations completed without errors
4. Make sure you've logged out and back in after changing your shell to zsh

> Note: If you're using a virtual machine or WSL, you might need to configure your terminal emulator to use the Nerd Font you installed.