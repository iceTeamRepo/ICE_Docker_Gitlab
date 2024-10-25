#!/usr/bin/env bash

install_log() {
  local message="$1"

  # Check if the file exists
  if [ ! -f "/tmp/install_log.sh" ]; then
    # If the file does not exist, create it
    touch "/tmp/install_log.sh"
  fi

  # Append the message to the file
  echo "$message" >> "/tmp/install_log.sh"
}

#----------------------------------------------------------------------
# check_os :  운영 체제 종류를 확인
#----------------------------------------------------------------------
check_os() {
  name=$(cat /etc/os-release | grep ^NAME= | sed 's/"//g')
  clean_name=$${name#*=}

  version=$(cat /etc/os-release | grep ^VERSION_ID= | sed 's/"//g')
  clean_version=$${version#*=}
  major=$${clean_version%.*}
  minor=$${clean_version#*.}
  
  if [[ "$clean_name" == "Ubuntu" ]]; then
    operating_system="ubuntu"
  else
    operating_system="undef"
  fi

  echo "OS: $operating_system"
  echo "OS Major Release: $major"
  echo "OS Minor Release: $minor"
  install_log "check_os"
}

#----------------------------------------------------------------------
# preflight : 운영체제별 gitlab 설치위한 필요 패키지 및 유틸리티 설치
#           :  SSH 프로토콜을 사용하여 서버에 연결하려면 서버에 OpenSSH가 설치되어 있어야 하며, 포트 22가 열려 있어야 함
#----------------------------------------------------------------------
preflight() {
  if [[ "$operating_system" == "ubuntu" ]]; then
    apt update && apt upgrade -y
    apt install -y \
      unzip \
      software-properties-common \
      ntp \
      curl \
      gnupg \
      openssl \
      jq \
      openssh-server \
      ca-certificates \
      nfs-common \
      cifs-utils \
      tzdata \
      perl \
      postfix
    install_log "preflight"
  else
    install_log "Preflight setup is only supported on Ubuntu."
  fi
}

#----------------------------------------------------------------------
#  Timezone 설정
#----------------------------------------------------------------------
configure_timezone() {
  sudo timedatectl set-timezone Asia/Seoul
}

#----------------------------------------------------------------------
#  SSH hostkey 설정
#----------------------------------------------------------------------
configure_ssh_host_keys() {
  local ssh_static_dir="/etc/ssh_static"

  # SSH 호스트 키 디렉토리 생성
  sudo mkdir -p /etc/ssh_static
  
  # 기존 SSH 설정을 새 디렉토리로 복사
  sudo cp -R /etc/ssh/* /etc/ssh_static
  
  # SSH 디렉토리로 이동
  cd /etc/ssh_static
  
  # SSH 호스트 키 경로를 추가 
  sudo bash -c 'cat <<-EOF >> /etc/ssh/sshd_config
# HostKeys for protocol version 2
HostKey /etc/ssh_static/ssh_host_rsa_key
HostKey /etc/ssh_static/ssh_host_dsa_key
HostKey /etc/ssh_static/ssh_host_ecdsa_key
HostKey /etc/ssh_static/ssh_host_ed25519_key
EOF'
  
  install_log "configure_ssh_host_keys"
}

#----------------------------------------------------------------------
# Docker 및 Docker Compose 설치
#----------------------------------------------------------------------
install_docker_compose() {
	sudo sysctl -w vm.max_map_count=262144
	sudo sysctl -w fs.file-max=65536
	sudo ulimit -n 65536
	sudo ulimit -u 4096
	
	# docker install
	curl -fsSL get.docker.com -o get-docker.sh
	sh get-docker.sh
	rm -rf ./get-docker.sh
	
	# dcs install
	curl -sL bit.ly/ralf_dcs -o ./dcs
	chmod 755 ./dcs
	sudo mv ./dcs /usr/bin/dcs
	
	# docker-compose install
	curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
	ln -sfT /usr/local/bin/docker-compose /usr/bin/docker-compose

  # ubuntu 를 docker 그룹에 추가
  sudo usermod -aG docker ubuntu
}

add_internal_routing() {
  echo "127.0.0.1 ${domain}" | sudo tee -a /etc/hosts
%{ if traefik_domain != "" ~}
  echo "127.0.0.1 ${traefik_domain}" | sudo tee -a /etc/hosts 
%{ endif ~}
}

#----------------------------------------------------------------------
# Main
#----------------------------------------------------------------------
main() {
  check_os
  case "$operating_system" in
    "ubuntu")
      DEBIAN_FRONTEND=noninteractive
      export DEBIAN_FRONTEND 
      preflight
      configure_timezone
      configure_ssh_host_keys 
      install_docker_compose
      add_internal_routing
      ;;
    *)
      echo "Unsupported operating system."
      exit 1
      ;;
  esac
}

main