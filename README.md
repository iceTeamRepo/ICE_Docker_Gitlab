# 02. gitlab 신규 설치

Created: 2024년 10월 25일 오전 10:47
Updated: 2024년 10월 25일 오후 4:33

- **01 > SSL 인증서 발급**
    1. Free SSL ([https://sslforweb.com/home](https://sslforweb.com/home)) 사이트에 로그인
    2. Create SSL
        
        ![image.png](/pictures/image.png)
        
    3. Route53 에 있는 Domain 의 Subdomain 인증서를 만드는 경우 아래 설정 후 **Create**
        
        ![image.png](/pictures/image%201.png)
        
    4.  기다리면 Domain 검증을 위한 **TXT 레코드와 값**을 보여주며 이를 복사해 놓음
        
        ![image.png](/pictures/image%202.png)
        
    5. Route53 에서 TXT 레코드 등록
        
        ![image.png](/pictures/image%203.png)
        
    6. Check 를 눌러 Status 통과 확인 후 **Validate Domain** 버튼 누름
        
        ![image.png](/pictures/image%204.png)
        
    7. SSL 인증서 다운로드
        
        ![image.png](/pictures/image%205.png)
        
    
- **02 > Ubuntu Server 에 Docker 및 Docker Compose 설치**
    
    ```bash
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
      clean_name=${name#*=}
    
      version=$(cat /etc/os-release | grep ^VERSION_ID= | sed 's/"//g')
      clean_version=${version#*=}
      major=${clean_version%.*}
      minor=${clean_version#*.}
      
      if [[ "$clean_name" == "Ubuntu" ]]; then
        operating_system="ubuntu"
      else
        operating_system="undef"
      fi
    
      echo "OS: $operating_system"
      echo "OS Major Release: $major"
      echo "OS Minor Release: $minor"
      install_log "check_os"
    }ICE_Docker_Gitlab
    
    #----------------------------------------------------------------------
    # preflight : 운영체제별 gitlab 설치위한 필요 패키지 및 유틸리티 설치
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
          ;;
        *)
          echo "Unsupported operating system."
          exit 1
          ;;
      esac
    }
    
    main
    ```
    
- **03 > 설치**
    1. 소스 다운로드
        
        ```bash
          $ git clone https://github.com/iceTeamRepo/ICE_Docker_Gitlab.git
        ```
        
    2. `/02_config/docker-compose.yaml` 파일을 열어 **gitlab.idtice.com** 을 LS산전의 Domain 으로 수정 
    3. `/02_config/gitlab/ssl` 폴더를 열고 **ssl 인증서** 넣기. 인증서는 domain 이름을 그대로 사용해야 인식됨
    4. 설치
        
        ```bash
          $ sudo su
          $ cd ICE_Docker_Gitlab/02_config
          
          # 서비스 시작
          $ docker network create gitlab-network
          $ docker-compose up -d
          
          # 서비스 종료
          $ docker-compose down
        ```
- **참조페이지**

  - nginx configuration
    - https://docs.gitlab.com/omnibus/settings/nginx.html
  - https 설정
    - https://docs.gitlab.com/omnibus/settings/ssl/index.html#configure-https-manually