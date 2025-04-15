# macOS ZSH Setup Guide

## 1. Install Homebrew
If you don't have Homebrew installed:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## 2. Set Up Homebrew Path
Add Homebrew to your PATH (Apple Silicon Macs only):
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

## 3. Install Core Requirements
Install the essential packages:
```bash
brew install zsh git curl wget fzf
```

## 4. ZSH Configuration
macOS comes with ZSH preinstalled. Set it as your default shell if not already:
```bash
chsh -s $(which zsh)
```
> Note: You'll need to log out and back in for this change to take effect.

## 5. Install Zinit
Set up Zinit for plugin management:
```bash
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
mkdir -p "$(dirname $ZINIT_HOME)"
git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
```

## 6. Install Zoxide
Install the smart directory jumper:
```bash
brew install zoxide
```

## 7. Install GitHub CLI
```bash
brew install gh
```

## 8. Install Kubectl (Optional)
If you need Kubernetes support:
```bash
brew install kubectl
```

## 9. Install AWS CLI (Optional)
If you need AWS support:
```bash
brew install awscli
```

## 10. Install Nerd Fonts
```bash
brew tap homebrew/cask-fonts
brew install --cask font-meslo-lg-nerd-font
```

## 11. Install Additional Tools
```bash
# Install fzf shell extensions
$(brew --prefix)/opt/fzf/install

# Install syntax highlighting and autosuggestions
brew install zsh-syntax-highlighting
brew install zsh-autosuggestions
```

## 12. Verify Installations
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

## Terminal Configuration

1. Open Terminal Preferences
2. Go to Profiles
3. Select your profile
4. Change the font to MesloLGS NF (the Nerd Font you installed)

## iTerm2 (Recommended Alternative Terminal)
If you prefer iTerm2 over the default Terminal:
```bash
brew install --cask iterm2
```

Then configure iTerm2:
1. Open iTerm2 Preferences (⌘,)
2. Go to Profiles > Text
3. Change the font to MesloLGS NF

## Troubleshooting

If you encounter any "command not found" errors after installation:
1. Source your zsh configuration:
```bash
source ~/.zshrc
```

2. Verify Homebrew is in your PATH:
```bash
echo $PATH | grep homebrew
```

3. For Apple Silicon Macs, ensure Homebrew's path is correctly set:
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
```

4. Check if all brew packages are linked:
```bash
brew doctor
```

> Note: If you're using VSCode's integrated terminal, you'll need to configure it to use the Nerd Font in VSCode settings.