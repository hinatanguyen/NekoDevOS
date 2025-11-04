#!/bin/bash
#
# NekoDevOS Post-Installation Customization Script
# Run this after installing NekoDevOS to apply anime themes and customizations
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_neko() {
    echo -e "${MAGENTA}"
    cat << "EOF"
    /\_/\  
   ( ^.^ ) 
    > ^ <   NekoDevOS Customization
   /|   |\  
  (_|   |_)
EOF
    echo -e "${NC}"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Welcome message
welcome() {
    clear
    print_neko
    echo ""
    echo -e "${MAGENTA}Welcome to NekoDevOS Customization!${NC}"
    echo -e "This script will set up your weeb-dev paradise~ ✨"
    echo ""
    sleep 2
}

# Install Oh My Zsh
setup_zsh() {
    print_info "Setting up Zsh with Oh My Zsh..."
    
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        
        # Install popular plugins
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || true
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || true
        git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions || true
        
        # Set theme to a cute one
        sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="af-magic"/' ~/.zshrc
        
        # Enable plugins
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions colored-man-pages command-not-found)/' ~/.zshrc
        
        print_success "Zsh configured!"
    else
        print_warning "Oh My Zsh already installed, skipping..."
    fi
}

# Setup Starship prompt
setup_starship() {
    print_info "Setting up Starship prompt..."
    
    if ! command -v starship &> /dev/null; then
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi
    
    # Configure Starship
    mkdir -p ~/.config
    cat > ~/.config/starship.toml << 'EOF'
# NekoDevOS Starship Configuration

format = """
[╭─](bold purple)$username$hostname$directory$git_branch$git_status$python$nodejs$rust$golang$java
[╰─](bold purple)$character"""

[character]
success_symbol = "[➜](bold green) "
error_symbol = "[✗](bold red) "

[username]
style_user = "bold cyan"
style_root = "bold red"
format = "[$user]($style) "
show_always = true

[hostname]
ssh_only = false
format = "[@$hostname](bold yellow) "

[directory]
style = "bold blue"
format = "[$path]($style) "
truncation_length = 3
truncate_to_repo = true

[git_branch]
symbol = "🌸 "
style = "bold purple"
format = "[$symbol$branch]($style) "

[git_status]
style = "bold red"
format = "([$all_status$ahead_behind]($style) )"

[python]
symbol = "🐍 "
style = "bold yellow"
format = "[$symbol$version]($style) "

[nodejs]
symbol = "⬢ "
style = "bold green"
format = "[$symbol$version]($style) "

[rust]
symbol = "🦀 "
style = "bold red"
format = "[$symbol$version]($style) "

[golang]
symbol = "🐹 "
style = "bold cyan"
format = "[$symbol$version]($style) "

[java]
symbol = "☕ "
style = "bold red"
format = "[$symbol$version]($style) "
EOF
    
    # Add to .zshrc
    if ! grep -q "starship init" ~/.zshrc 2>/dev/null; then
        echo 'eval "$(starship init zsh)"' >> ~/.zshrc
    fi
    
    # Add to .bashrc
    if ! grep -q "starship init" ~/.bashrc 2>/dev/null; then
        echo 'eval "$(starship init bash)"' >> ~/.bashrc
    fi
    
    print_success "Starship configured!"
}

# Setup wallpaper rotation
setup_wallpapers() {
    print_info "Setting up wallpaper rotation..."
    
    mkdir -p ~/.local/share/wallpapers/neko
    
    # Create wallpaper rotation script
    cat > ~/scripts/rotate-wallpaper.sh << 'EOF'
#!/bin/bash
WALLPAPER_DIR="$HOME/.local/share/wallpapers/neko"
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" \) | shuf -n 1)

if [ -n "$WALLPAPER" ]; then
    # For KDE Plasma
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        var allDesktops = desktops();
        for (i=0;i<allDesktops.length;i++) {
            d = allDesktops[i];
            d.wallpaperPlugin = 'org.kde.image';
            d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
            d.writeConfig('Image', 'file://$WALLPAPER');
        }
    " 2>/dev/null
    
    # For XFCE
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$WALLPAPER" 2>/dev/null || true
fi
EOF
    
    chmod +x ~/scripts/rotate-wallpaper.sh
    
    # Add cron job for wallpaper rotation (every hour)
    (crontab -l 2>/dev/null; echo "0 * * * * $HOME/scripts/rotate-wallpaper.sh") | crontab - || true
    
    print_success "Wallpaper rotation configured!"
    print_info "Place your wallpapers in ~/.local/share/wallpapers/neko/"
}

# Setup KDE Plasma theme
setup_kde_theme() {
    print_info "Configuring KDE Plasma theme..."
    
    # Install additional themes
    sudo apt install -y \
        kde-config-gtk-style \
        breeze-gtk-theme \
        papirus-icon-theme \
        arc-theme || true
    
    # Set Papirus icon theme
    kwriteconfig5 --file ~/.config/kdeglobals --group Icons --key Theme Papirus-Dark 2>/dev/null || true
    
    # Set Arc-Dark theme
    kwriteconfig5 --file ~/.config/kdeglobals --group General --key Name Arc-Dark 2>/dev/null || true
    
    # Configure panel
    kwriteconfig5 --file ~/.config/plasmarc --group Theme --key name breeze-dark 2>/dev/null || true
    
    print_success "KDE theme configured!"
}

# Setup development environment
setup_dev_env() {
    print_info "Setting up development environment..."
    
    # Install VS Code extensions (if VS Code is installed)
    if command -v code &> /dev/null; then
        code --install-extension ms-python.python --force 2>/dev/null || true
        code --install-extension ms-vscode.cpptools --force 2>/dev/null || true
        code --install-extension golang.go --force 2>/dev/null || true
        code --install-extension esbenp.prettier-vscode --force 2>/dev/null || true
        code --install-extension pkief.material-icon-theme --force 2>/dev/null || true
        code --install-extension zhuangtongfa.material-theme --force 2>/dev/null || true
        print_success "VS Code extensions installed!"
    fi
    
    # Configure Git
    print_info "Configure Git? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -n "Enter your Git username: "
        read -r git_username
        echo -n "Enter your Git email: "
        read -r git_email
        
        git config --global user.name "$git_username"
        git config --global user.email "$git_email"
        git config --global init.defaultBranch main
        git config --global core.editor vim
        
        print_success "Git configured!"
    fi
}

# Setup Japanese input
setup_japanese_input() {
    print_info "Setting up Japanese input (Mozc)..."
    
    # Add ibus-daemon to autostart
    mkdir -p ~/.config/autostart
    cat > ~/.config/autostart/ibus.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=IBus Daemon
Exec=ibus-daemon -drx
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    
    # Configure IBus
    ibus-setup 2>/dev/null &
    
    print_success "Japanese input configured!"
    print_info "Use Super+Space to switch input methods"
}

# Setup custom aliases
setup_aliases() {
    print_info "Setting up custom aliases..."
    
    cat >> ~/.zshrc << 'EOF'

# ============================================================================
# NekoDevOS Custom Aliases
# ============================================================================

# Cute ls alternatives
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias nya='neofetch'  # Show system info the cute way

# Development shortcuts
alias py='python3'
alias pip='pip3'
alias v='vim'
alias nv='nvim'
alias c='code .'
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --all'

# Docker shortcuts
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'

# System shortcuts
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias search='apt search'
alias clean='sudo apt autoremove -y && sudo apt autoclean'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# Utilities
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ping='ping -c 5'
alias ports='netstat -tulanp'

# Fun stuff
alias starwars='telnet towel.blinkenlights.nl'
alias matrix='cmatrix'
alias train='sl'
alias weather='curl wttr.in'
EOF
    
    print_success "Aliases configured!"
}

# Setup neofetch with custom config
setup_neofetch() {
    print_info "Setting up Neofetch..."
    
    mkdir -p ~/.config/neofetch
    cat > ~/.config/neofetch/config.conf << 'EOF'
# NekoDevOS Neofetch Configuration

print_info() {
    info title
    info underline

    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "Resolution" resolution
    info "DE" de
    info "WM" wm
    info "Theme" theme
    info "Icons" icons
    info "Terminal" term
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory

    info cols
}

# Title
title_fqdn="off"

# Kernel
kernel_shorthand="on"

# Distro
distro_shorthand="off"

# OS Architecture
os_arch="on"

# Uptime
uptime_shorthand="on"

# Memory
memory_percent="on"

# Colors
colors=(distro)

# Text Options
bold="on"
underline_enabled="on"
underline_char="-"
separator=":"

# Color Blocks
block_range=(0 15)
color_blocks="on"
block_width=3
block_height=1

# Backend Settings
image_backend="ascii"
image_source="auto"

# Ascii Options
ascii_distro="auto"
ascii_colors=(distro)
ascii_bold="on"

# Image Options
image_loop="off"
thumbnail_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/thumbnails/neofetch"
crop_mode="normal"
crop_offset="center"
image_size="auto"
gap=3
EOF
    
    # Add neofetch to shell startup
    if ! grep -q "neofetch" ~/.zshrc 2>/dev/null; then
        echo "" >> ~/.zshrc
        echo "# Show system info on terminal start" >> ~/.zshrc
        echo "neofetch" >> ~/.zshrc
    fi
    
    print_success "Neofetch configured!"
}

# Final message
finish() {
    echo ""
    print_success "NekoDevOS customization complete! 🎉"
    echo ""
    echo -e "${MAGENTA}Next steps:${NC}"
    echo -e "  1. Add your wallpapers to ${CYAN}~/.local/share/wallpapers/neko/${NC}"
    echo -e "  2. Restart your terminal or run: ${CYAN}source ~/.zshrc${NC}"
    echo -e "  3. Explore the themes in system settings"
    echo -e "  4. Configure Japanese input with ${CYAN}ibus-setup${NC}"
    echo ""
    echo -e "${YELLOW}Optional customizations:${NC}"
    echo -e "  - Install Latte Dock: ${CYAN}sudo apt install latte-dock${NC}"
    echo -e "  - Install Conky widgets: ${CYAN}sudo apt install conky-all${NC}"
    echo -e "  - Browse more themes: ${CYAN}https://store.kde.org/${NC}"
    echo ""
    echo -e "${GREEN}Enjoy your weeb-dev paradise! (◕‿◕)♡${NC}"
    echo ""
}

# Main execution
main() {
    welcome
    setup_zsh
    setup_starship
    setup_wallpapers
    setup_kde_theme
    setup_dev_env
    setup_japanese_input
    setup_aliases
    setup_neofetch
    finish
}

# Run main function
main "$@"
