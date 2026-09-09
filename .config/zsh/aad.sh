#!/bin/sh
set -e

# تنظیمات اولیه
ZSH="${ZSH:-$HOME/.oh-my-zsh}"
REPO="ohmyzsh/ohmyzsh"
REMOTE="https://github.com/${REPO}.git"
BRANCH="master"

# چک کردن git
command -v git >/dev/null 2>&1 || {
    echo "Error: git is not installed"
    exit 1
}

# کلون کردن مخزن
echo "Cloning Oh My Zsh..."
git clone --depth=1 "$REMOTE" "$ZSH" || {
    echo "Error: git clone failed"
    exit 1
}

# پشتیبان‌گیری از .zshrc قدیمی
if [ -f "$HOME/.zshrc" ]; then
    echo "Backing up existing .zshrc to .zshrc.pre-oh-my-zsh"
    mv "$HOME/.zshrc" "$HOME/.zshrc.pre-oh-my-zsh"
fi

# کپی قالب .zshrc
cp "$ZSH/templates/zshrc.zsh-template" "$HOME/.zshrc"

# تنظیم ZSH در .zshrc
sed -i "s|^export ZSH=.*$|export ZSH=\"$ZSH\"|" "$HOME/.zshrc"

# تغییر شل پیش‌فرض (اختیاری)
if command -v chsh >/dev/null 2>&1 && [ "$(basename -- "$SHELL")" != "zsh" ]; then
    echo "Do you want to change your default shell to zsh? [y/N]"
    read -r opt
    case $opt in
        [Yy]*)
            if command -v sudo >/dev/null 2>&1; then
                sudo chsh -s "$(command -v zsh)" "$USER"
            else
                chsh -s "$(command -v zsh)" "$USER"
            fi
            ;;
        *) echo "Shell change skipped." ;;
    esac
fi

echo "Oh My Zsh installed successfully!"
echo "Run 'zsh' or restart your terminal to use it."