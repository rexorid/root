#!/bin/bash

TESTFILE="test123zz"
echo "TESTPAGE_$(date +%s)" > "/tmp/$TESTFILE"

# Function to extract domain from vhost config file
extract_domain() {
    local config_file="$1"
    local domain=""
    
    # Try to extract ServerName or server_name from config
    if [ -f "$config_file" ]; then
        # For Apache config
        domain=$(grep -i "^[[:space:]]*ServerName" "$config_file" | head -1 | awk '{print $2}')
        
        # If not found in Apache format, try Nginx format
        if [ -z "$domain" ]; then
            domain=$(grep -i "^[[:space:]]*server_name" "$config_file" | head -1 | sed 's/.*server_name//' | awk '{print $1}' | tr -d ';')
        fi
        
        # If still empty, try to get from filename
        if [ -z "$domain" ]; then
            domain=$(basename "$config_file" | sed 's/\.conf$//' | sed 's/\.ssl$//')
        fi
    fi
    
    echo "$domain"
}

# Collect all domains from vhost configurations
declare -A domains_map
declare -a domains_list

# Check Apache vhosts
if [ -d "/usr/local/apache/conf.d/vhosts/" ]; then
    for config in /usr/local/apache/conf.d/vhosts/*.conf; do
        if [ -f "$config" ]; then
            domain=$(extract_domain "$config")
            if [ -n "$domain" ]; then
                domains_map["$domain"]="$config"
                domains_list+=("$domain")
            fi
        fi
    done
fi

# Check Nginx vhosts
if [ -d "/etc/nginx/conf.d/vhosts/" ]; then
    for config in /etc/nginx/conf.d/vhosts/*.conf; do
        if [ -f "$config" ]; then
            domain=$(extract_domain "$config")
            if [ -n "$domain" ] && [ -z "${domains_map[$domain]}" ]; then
                domains_map["$domain"]="$config"
                domains_list+=("$domain")
            fi
        fi
    done
fi

# If no domains found, exit
if [ ${#domains_list[@]} -eq 0 ]; then
    echo "No domains found in vhost configurations"
    rm -f "/tmp/$TESTFILE"
    exit 1
fi

echo "Found ${#domains_list[@]} domains to check"
echo "----------------------------------------"

# Check each domain
for domain in "${domains_list[@]}"; do
    # Determine document root for each domain
    # Try to find in Apache config first
    doc_root=""
    config_file="${domains_map[$domain]}"
    
    if [ -f "$config_file" ]; then
        # Try Apache DocumentRoot
        doc_root=$(grep -i "^[[:space:]]*DocumentRoot" "$config_file" | head -1 | awk '{print $2}' | tr -d '"')
        
        # If not found, try Nginx root
        if [ -z "$doc_root" ]; then
            doc_root=$(grep -i "^[[:space:]]*root" "$config_file" | head -1 | sed 's/.*root//' | awk '{print $1}' | tr -d ';')
        fi
    fi
    
    # If no doc_root found, try to find in /home/*/public_html/
    if [ -z "$doc_root" ] || [ ! -d "$doc_root" ]; then
        # Search for domain in /home/*/public_html/
        for user_dir in /home/*/; do
            if [ -d "${user_dir}public_html" ]; then
                # Check if this might be the domain's directory
                potential_root="${user_dir}public_html"
                
                # Look for domain-specific files or just use the directory
                if [ -d "$potential_root" ]; then
                    doc_root="$potential_root"
                    break
                fi
            fi
        done
    fi
    
    # If still no doc_root, try to find based on username
    if [ -z "$doc_root" ] || [ ! -d "$doc_root" ]; then
        # Extract username from domain or use domain name as username
        username=$(echo "$domain" | cut -d'.' -f1)
        if [ -d "/home/$username/public_html" ]; then
            doc_root="/home/$username/public_html"
        fi
    fi
    
    if [ -z "$doc_root" ] || [ ! -d "$doc_root" ]; then
        echo "✗ $domain - document root not found"
        continue
    fi
    
    # Check if it's Laravel
    LARAVEL=""
    if [ -d "${doc_root}storage" ]; then
        LARAVEL="yes"
    fi
    
    # Copy test file
    if [ -n "$LARAVEL" ]; then
        if [ -d "${doc_root}public" ]; then
            cp "/tmp/$TESTFILE" "${doc_root}public/" 2>/dev/null
            test_path="${doc_root}public/${TESTFILE}"
        else
            echo "✗ $domain - Laravel public directory not found"
            continue
        fi
    else
        cp "/tmp/$TESTFILE" "$doc_root/" 2>/dev/null
        test_path="${doc_root}${TESTFILE}"
    fi
    
    # Test accessibility
    url="https://${domain}/${TESTFILE}"
    response=$(curl -s -L --max-time 10 --connect-timeout 5 -k "$url")
    
    if echo "$response" | grep -q "TESTPAGE_"; then
        echo "✓ $domain - accessible (doc_root: $doc_root)"
    else
        # Try http if https fails
        url="http://${domain}/${TESTFILE}"
        response=$(curl -s -L --max-time 10 --connect-timeout 5 -k "$url")
        if echo "$response" | grep -q "TESTPAGE_"; then
            echo "✓ $domain - accessible (HTTP only, doc_root: $doc_root)"
        else
            echo "✗ $domain - not accessible (doc_root: $doc_root)"
        fi
    fi
    
    # Cleanup test file
    rm -f "$test_path" 2>/dev/null
done

# Cleanup temp file
rm -f "/tmp/$TESTFILE"

echo "----------------------------------------"
echo "Done checking domains"