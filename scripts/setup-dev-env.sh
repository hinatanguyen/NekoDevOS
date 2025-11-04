#!/bin/bash
#
# Development Environment Setup for NekoDevOS
# Sets up common development tools and configurations
#

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}🛠️  NekoDevOS Development Environment Setup${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Node.js LTS via NVM
setup_nodejs() {
    echo -e "${CYAN}[1/8]${NC} Setting up Node.js..."
    
    if ! command_exists nvm; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        nvm install --lts
        nvm use --lts
        
        # Install common global packages
        npm install -g yarn pnpm typescript ts-node nodemon eslint prettier
        
        echo -e "${GREEN}✓${NC} Node.js installed!"
    else
        echo -e "${YELLOW}⊘${NC} Node.js already installed"
    fi
}

# Setup Python virtual environment tools
setup_python() {
    echo -e "${CYAN}[2/8]${NC} Setting up Python environment..."
    
    sudo apt install -y python3-pip python3-venv python3-dev
    
    # Install common Python packages
    pip3 install --user --upgrade pip
    pip3 install --user virtualenv pipenv poetry
    pip3 install --user black flake8 pylint mypy autopep8
    pip3 install --user jupyter ipython notebook
    
    echo -e "${GREEN}✓${NC} Python environment configured!"
}

# Setup Rust
setup_rust() {
    echo -e "${CYAN}[3/8]${NC} Setting up Rust..."
    
    if ! command_exists rustc; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        
        # Install common tools
        cargo install cargo-edit cargo-watch
        
        echo -e "${GREEN}✓${NC} Rust installed!"
    else
        echo -e "${YELLOW}⊘${NC} Rust already installed"
    fi
}

# Setup Go
setup_golang() {
    echo -e "${CYAN}[4/8]${NC} Setting up Go..."
    
    if command_exists go; then
        # Setup Go workspace
        mkdir -p ~/go/{bin,src,pkg}
        
        if ! grep -q "GOPATH" ~/.zshrc; then
            cat >> ~/.zshrc << 'EOF'

# Go environment
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
EOF
        fi
        
        echo -e "${GREEN}✓${NC} Go environment configured!"
    else
        echo -e "${YELLOW}⊘${NC} Go not installed, skipping configuration"
    fi
}

# Setup Docker
setup_docker() {
    echo -e "${CYAN}[5/8]${NC} Setting up Docker..."
    
    if command_exists docker; then
        # Add user to docker group
        sudo usermod -aG docker $USER
        
        # Install Docker Compose if not present
        if ! command_exists docker-compose; then
            sudo apt install -y docker-compose
        fi
        
        # Enable Docker service
        sudo systemctl enable docker
        sudo systemctl start docker
        
        echo -e "${GREEN}✓${NC} Docker configured!"
        echo -e "${YELLOW}Note:${NC} Log out and back in for Docker group changes to take effect"
    else
        echo -e "${YELLOW}⊘${NC} Docker not installed"
    fi
}

# Setup Git aliases and config
setup_git() {
    echo -e "${CYAN}[6/8]${NC} Setting up Git..."
    
    # Set useful Git aliases
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.unstage 'reset HEAD --'
    git config --global alias.last 'log -1 HEAD'
    git config --global alias.visual 'log --oneline --graph --all --decorate'
    
    # Set default branch to main
    git config --global init.defaultBranch main
    
    # Set pull strategy
    git config --global pull.rebase false
    
    # Enable colored output
    git config --global color.ui auto
    
    echo -e "${GREEN}✓${NC} Git configured!"
}

# Setup VS Code settings
setup_vscode() {
    echo -e "${CYAN}[7/8]${NC} Setting up VS Code..."
    
    if command_exists code; then
        # Install essential extensions
        extensions=(
            "ms-python.python"
            "ms-vscode.cpptools"
            "golang.go"
            "rust-lang.rust-analyzer"
            "dbaeumer.vscode-eslint"
            "esbenp.prettier-vscode"
            "eamodio.gitlens"
            "ms-azuretools.vscode-docker"
            "pkief.material-icon-theme"
            "zhuangtongfa.material-theme"
            "wayou.vscode-todo-highlight"
            "streetsidesoftware.code-spell-checker"
        )
        
        for ext in "${extensions[@]}"; do
            code --install-extension "$ext" --force 2>/dev/null || true
        done
        
        # Create VS Code settings
        mkdir -p ~/.config/Code/User
        cat > ~/.config/Code/User/settings.json << 'EOF'
{
    "workbench.colorTheme": "Material Theme Darker High Contrast",
    "workbench.iconTheme": "material-icon-theme",
    "editor.fontFamily": "'JetBrains Mono', 'Fira Code', monospace",
    "editor.fontLigatures": true,
    "editor.fontSize": 14,
    "editor.formatOnSave": true,
    "editor.minimap.enabled": true,
    "editor.lineNumbers": "on",
    "editor.rulers": [80, 120],
    "files.autoSave": "afterDelay",
    "terminal.integrated.fontFamily": "'JetBrains Mono', monospace",
    "git.enableSmartCommit": true,
    "git.confirmSync": false
}
EOF
        
        echo -e "${GREEN}✓${NC} VS Code configured!"
    else
        echo -e "${YELLOW}⊘${NC} VS Code not installed"
    fi
}

# Setup SSH
setup_ssh() {
    echo -e "${CYAN}[8/8]${NC} Setting up SSH..."
    
    if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then
        echo -e "${YELLOW}No SSH key found.${NC} Generate one? (y/n)"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -n "Enter your email: "
            read -r email
            ssh-keygen -t ed25519 -C "$email"
            
            echo -e "${GREEN}✓${NC} SSH key generated!"
            echo -e "${CYAN}Your public key:${NC}"
            cat ~/.ssh/id_ed25519.pub
        fi
    else
        echo -e "${YELLOW}⊘${NC} SSH key already exists"
    fi
}

# Main execution
main() {
    setup_nodejs
    setup_python
    setup_rust
    setup_golang
    setup_docker
    setup_git
    setup_vscode
    setup_ssh
    
    echo ""
    echo -e "${GREEN}🎉 Development environment setup complete!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Restart your terminal for all changes to take effect"
    echo "  2. For Docker: log out and back in"
    echo "  3. Configure your Git user.name and user.email if not done"
    echo ""
    echo -e "${YELLOW}Happy coding! (◕‿◕)${NC}"
}

main "$@"
