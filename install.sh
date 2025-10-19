#!/bin/bash

# Installation script for imgcrypt
# Author: Ash
# Version: 1.0
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║                                          ║"
echo "║       ImgCrypt Installer v1.0            ║"
echo "║      Secure Image Encryption Tool        ║"
echo "║                                  -Ash    ║"
echo "║                                          ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Running installation without root privileges...${NC}"
  echo -e "${YELLOW}The script will be installed in the local bin directory.${NC}"
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
else
  echo -e "${GREEN}Running installation with root privileges...${NC}"
  INSTALL_DIR="/usr/local/bin"
fi

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH.${NC}"
  echo -e "You may need to add it by running:"
  echo -e "    echo 'export PATH=\"\$PATH:$INSTALL_DIR\"' >> ~/.bashrc"
  echo -e "    source ~/.bashrc"
fi

echo -e "${BLUE}Checking dependencies...${NC}"
missing_deps=()

for cmd in openssl file basename dirname realpath; do
    if ! command -v "$cmd" &> /dev/null; then
        missing_deps+=("$cmd")
    fi
done

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "${RED}Missing dependencies:${NC}"
    for dep in "${missing_deps[@]}"; do
        echo "  - $dep"
    done
    
    echo ""
    echo -e "${YELLOW}Please install the missing dependencies before continuing.${NC}"
    echo "On Debian/Ubuntu systems, you can use:"
    echo "  sudo apt-get update && sudo apt-get install openssl file coreutils"
    
    read -p "Would you like to attempt to install these dependencies now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v apt-get &> /dev/null; then
            echo -e "${BLUE}Installing dependencies via apt-get...${NC}"
            if [ "$EUID" -ne 0 ]; then
                echo -e "${YELLOW}Root privileges required for package installation.${NC}"
                echo "Please run: sudo apt-get update && sudo apt-get install openssl file coreutils"
                exit 1
            else
                apt-get update && apt-get install -y openssl file coreutils
            fi
        else
            echo -e "${RED}Unable to automatically install dependencies.${NC}"
            echo "Please install the required packages manually."
            exit 1
        fi
    else
        echo -e "${RED}Installation aborted. Please install the required dependencies first.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}All dependencies are installed.${NC}"

SCRIPT_DIR=$(dirname "$(realpath "$0")")

if [ ! -f "$SCRIPT_DIR/imgcrypt.sh" ]; then
    echo -e "${RED}Error: imgcrypt.sh not found in the current directory.${NC}"
    echo "Please make sure the imgcrypt.sh script is in the same directory as this installer."
    exit 1
fi

echo -e "${BLUE}Installing imgcrypt to $INSTALL_DIR...${NC}"
cp "$SCRIPT_DIR/imgcrypt.sh" "$INSTALL_DIR/imgcrypt"

chmod +x "$INSTALL_DIR/imgcrypt"
if [ -f "$INSTALL_DIR/imgcrypt" ] && [ -x "$INSTALL_DIR/imgcrypt" ]; then
    echo -e "${GREEN}Installation successful!${NC}"
    echo -e "${BLUE}You can now use imgcrypt by typing:${NC}"
    echo "    imgcrypt -h"
    echo ""
    echo -e "${YELLOW}Example commands:${NC}"
    echo "    imgcrypt -e image.jpg            # Encrypt a single image"
    echo "    imgcrypt -d image.jpg.enc        # Decrypt an encrypted image"
    echo "    imgcrypt -e -r /path/to/images/  # Encrypt all images in directory"
else
    echo -e "${RED}Installation failed. Please check permissions and try again.${NC}"
    exit 1
fi

if [ "$EUID" -eq 0 ] && command -v gzip &> /dev/null; then
    echo -e "${BLUE}Creating manual page...${NC}"
    MANUAL_DIR="/usr/local/share/man/man1"
    mkdir -p "$MANUAL_DIR"

    cat > "$MANUAL_DIR/imgcrypt.1" << 'EOL'
.TH IMGCRYPT 1 "May 2025" "imgcrypt 1.0" "User Commands"
.SH NAME
imgcrypt \- image encryption and decryption tool
.SH SYNOPSIS
.B imgcrypt
[\fIOPTIONS\fR] \fIFILE/DIRECTORY\fR
.SH DESCRIPTION
.B imgcrypt
is a command line tool to securely encrypt and decrypt image files using AES-256-CBC encryption.
.SH OPTIONS
.TP
.BR \-e ", " \-\-encrypt
Encrypt image file(s)
.TP
.BR \-d ", " \-\-decrypt
Decrypt encrypted image file(s)
.TP
.BR \-r ", " \-\-recursive
Process directories recursively
.TP
.BR \-b ", " \-\-backup
Create backup of original files before processing
.TP
.BR \-p ", " \-\-password " " \fIPASSWORD\fR
Specify password (not recommended, use prompt instead)
.TP
.BR \-h ", " \-\-help
Display help message
.SH EXAMPLES
.TP
Encrypt a single image:
.B imgcrypt \-e image.jpg
.TP
Decrypt an encrypted image:
.B imgcrypt \-d image.jpg.enc
.TP
Encrypt all images in a directory:
.B imgcrypt \-e \-r /path/to/images/
.TP
Decrypt all encrypted images in a directory:
.B imgcrypt \-d \-r /path/to/encrypted/
.SH SUPPORTED FORMATS
.B imgcrypt
supports the following image formats: jpg, jpeg, png, bmp, gif, tiff, webp
.SH AUTHOR
Ash
.SH BUGS
Report bugs to your system administrator.
EOL
    gzip -f "$MANUAL_DIR/imgcrypt.1"
    
    if command -v mandb &> /dev/null; then
        mandb -q
        echo -e "${GREEN}Manual page installed. You can view it with:${NC}"
        echo "    man imgcrypt"
    else
        echo -e "${YELLOW}Manual page installed but mandb command not found.${NC}"
        echo "Manual page may not be immediately available."
    fi
fi

echo -e "${GREEN}ImgCrypt installation complete!${NC}"
