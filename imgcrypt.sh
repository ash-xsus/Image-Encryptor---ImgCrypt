#!/bin/bash

# imgcrypt - Image Encryption Tool
# Version: 1.0

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' 
show_banner() {
    clear
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║                                          ║"
    echo "║            ImgCrypt v1.0                 ║"
    echo "║      Secure Image Encryption Tool        ║"
    echo "║                                -Ash      ║"
    echo "║                                          ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}
show_help() {
    echo -e "${BLUE}Usage:${NC}"
    echo "  imgcrypt [options] <file/directory>"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  -e, --encrypt        Encrypt image file(s)"
    echo "  -d, --decrypt        Decrypt image file(s)"
    echo "  -r, --recursive      Process directories recursively"
    echo "  -b, --backup         Create backup of original files"
    echo "  -p, --password       Specify password (not recommended, use prompt instead)"
    echo "  -h, --help           Display this help message"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  imgcrypt -e image.jpg                   # Encrypt a single image"
    echo "  imgcrypt -d image.jpg.enc               # Decrypt an encrypted image"
    echo "  imgcrypt -e -r /path/to/images/         # Encrypt all images in directory"
    echo "  imgcrypt -d -r /path/to/encrypted/      # Decrypt all encrypted images in directory"
    echo ""
    echo -e "${YELLOW}Supported image formats:${NC} jpg, jpeg, png, bmp, gif, tiff, webp"
    echo ""
}

check_dependencies() {
    local missing_deps=()
    
    for cmd in openssl file basename dirname realpath; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing dependencies.${NC}"
        echo "Please install the following packages:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "On Debian/Ubuntu systems, you can use:"
        echo "  sudo apt-get update && sudo apt-get install openssl file coreutils"
        exit 1
    fi
}

is_image() {
    local file="$1"
    local mime_type
    
    mime_type=$(file --mime-type -b "$file")
    
    if [[ $mime_type == image/* ]]; then
        return 0
    else
        return 1
    fi
}

encrypt_file() {
    local input_file="$1"
    local password="$2"
    local backup="$3"
    local output_file="${input_file}.enc"
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Error: File not found: $input_file${NC}"
        return 1
    fi
    if ! is_image "$input_file"; then
        echo -e "${YELLOW}Warning: $input_file does not appear to be an image file. Skipping.${NC}"
        return 1
    fi
    
    if [ "$backup" = true ]; then
        cp "$input_file" "${input_file}.bak"
        echo -e "${BLUE}Backup created: ${input_file}.bak${NC}"
    fi
    if openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "$input_file" -out "$output_file" -k "$password" 2>/dev/null; then
        echo -e "${GREEN}Successfully encrypted: $input_file -> $output_file${NC}"
        return 0
    else
        echo -e "${RED}Failed to encrypt: $input_file${NC}"
        return 1
    fi
}

decrypt_file() {
    local input_file="$1"
    local password="$2"
    local backup="$3"
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Error: File not found: $input_file${NC}"
        return 1
    fi
    if [[ "$input_file" == *.enc ]]; then
        local output_file="${input_file%.enc}"
    else
        local output_file="${input_file}.decrypted"
        echo -e "${YELLOW}Warning: Input file does not have .enc extension. Output will be: $output_file${NC}"
    fi
    
    if [ "$backup" = true ]; then
        cp "$input_file" "${input_file}.bak"
        echo -e "${BLUE}Backup created: ${input_file}.bak${NC}"
    fi
    
    if openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "$input_file" -out "$output_file" -k "$password" 2>/dev/null; then
        echo -e "${GREEN}Successfully decrypted: $input_file -> $output_file${NC}"
        
        if ! is_image "$output_file"; then
            echo -e "${YELLOW}Warning: Decrypted file does not appear to be an image. Password may be incorrect.${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}Failed to decrypt: $input_file (incorrect password or corrupt file)${NC}"
        return 1
    fi
}
process_directory() {
    local directory="$1"
    local operation="$2"
    local password="$3"
    local recursive="$4"
    local backup="$5"
    local files_processed=0
    local files_succeeded=0
    
    if [ ! -d "$directory" ]; then
        echo -e "${RED}Error: Directory not found: $directory${NC}"
        return 1
    fi
    
    local file_list
    if [ "$operation" = "encrypt" ]; then
        file_list=$(find "$directory" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.tiff" -o -iname "*.webp" \) 2>/dev/null)
    else # decrypt
        file_list=$(find "$directory" -maxdepth 1 -type f -iname "*.enc" 2>/dev/null)
    fi
    
    for file in $file_list; do
        files_processed=$((files_processed + 1))
        
        if [ "$operation" = "encrypt" ]; then
            encrypt_file "$file" "$password" "$backup" && files_succeeded=$((files_succeeded + 1))
        else
            decrypt_file "$file" "$password" "$backup" && files_succeeded=$((files_succeeded + 1))
        fi
    done
    
    if [ "$recursive" = true ]; then
        local subdirs
        subdirs=$(find "$directory" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
        
        for subdir in $subdirs; do
            local sub_processed=0
            local sub_succeeded=0
            
            process_directory "$subdir" "$operation" "$password" "$recursive" "$backup"
            sub_processed=$?
            sub_succeeded=$((sub_processed >> 8))
            sub_processed=$((sub_processed & 255))
            
            files_processed=$((files_processed + sub_processed))
            files_succeeded=$((files_succeeded + sub_succeeded))
        done
    fi
    
    return $((files_succeeded << 8 | files_processed))
}

main() {
    local operation=""
    local recursive=false
    local backup=false
    local password=""
    local target=""
    
    check_dependencies
    while [ $# -gt 0 ]; do
        case "$1" in
            -e|--encrypt)
                operation="encrypt"
                shift
                ;;
            -d|--decrypt)
                operation="decrypt"
                shift
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -b|--backup)
                backup=true
                shift
                ;;
            -p|--password)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    echo -e "${RED}Error: Password option requires an argument${NC}"
                    show_help
                    exit 1
                fi
                password="$2"
                shift 2
                ;;
            -h|--help)
                show_banner
                show_help
                exit 0
                ;;
            -*)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
            *)
                target="$1"
                shift
                ;;
        esac
    done
    
    show_banner
    if [ -z "$operation" ]; then
        echo -e "${RED}Error: No operation specified. Use -e to encrypt or -d to decrypt.${NC}"
        show_help
        exit 1
    fi
    
    if [ -z "$target" ]; then
        echo -e "${RED}Error: No target file or directory specified.${NC}"
        show_help
        exit 1
    fi
    
    if [ -z "$password" ]; then
        echo -e "${YELLOW}Enter password for ${operation}ion:${NC}"
        read -s password
        echo ""
        
        echo -e "${YELLOW}Confirm password:${NC}"
        read -s confirm_password
        echo ""
        
        if [ "$password" != "$confirm_password" ]; then
            echo -e "${RED}Error: Passwords do not match.${NC}"
            exit 1
        fi
        
        if [ -z "$password" ]; then
            echo -e "${RED}Error: Empty password not allowed.${NC}"
            exit 1
        fi
    fi
    
    local files_processed=0
    local files_succeeded=0
    
    if [ -d "$target" ]; then
       
        process_directory "$target" "$operation" "$password" "$recursive" "$backup"
        exit_code=$?
        files_succeeded=$((exit_code >> 8))
        files_processed=$((exit_code & 255))
    elif [ -f "$target" ]; then
    
        files_processed=1
        
        if [ "$operation" = "encrypt" ]; then
            encrypt_file "$target" "$password" "$backup" && files_succeeded=1
        else
            decrypt_file "$target" "$password" "$backup" && files_succeeded=1
        fi
    else
        echo -e "${RED}Error: Target not found: $target${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}Operation Summary:${NC}"
    echo "  Files processed: $files_processed"
    echo "  Files succeeded: $files_succeeded"
    
    if [ $files_processed -eq $files_succeeded ]; then
        echo -e "${GREEN}All operations completed successfully.${NC}"
    elif [ $files_succeeded -eq 0 ]; then
        echo -e "${RED}All operations failed.${NC}"
    else
        echo -e "${YELLOW}Some operations failed. Check the output above for details.${NC}"
    fi
}

# Call main function with all arguments
main "$@"
