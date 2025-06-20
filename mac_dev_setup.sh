
# Install zshrc
brew install zsh

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
# Change default terminal
chsh -s $(which zsh)
# Source changes
source ~/.zshrc

# Install zsh syntax highlighitng
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Install zsh Auto suggestions
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions

# Update zshs
source ~/.zshrc

# Install Powerlevel10k theme
# Source: https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#installation

# Clone the files
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
# Add to zshrc
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc
