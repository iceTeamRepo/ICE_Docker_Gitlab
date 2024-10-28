## gitlab docker 설치


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
    #  SSH Server 용 Hostkey 설정
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
    # 확인용 라우팅 추가
    #----------------------------------------------------------------------
    add_internal_routing() {
      echo "127.0.0.1 gitlab.idtice.com" | sudo tee -a /etc/hosts
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
    ```

- **03 > 설치**
    1. 소스 다운로드
        ```bash
          $ git clone https://github.com/iceTeamRepo/ICE_Docker_Gitlab.git
        ```
    2. `/02_config/.env` 파일을 열어 변수 설정
    3. `/02_config/gitlab/ssl` 폴더를 열고 **ssl 인증서** 넣기. **주의:** 인증서는 **도메인 이름을 그대로 사용해야 인식됨.**
    4. 설치
        ```bash
          $ sudo su
          $ cd ICE_Docker_Gitlab/02_config
          
          # 서비스 시작
          $ docker network create gitlab-network
          $ docker compose -f docker-compose.yaml -p gitlab up -d
          
          # Gitlab root <initial_password> 얻기
          $ sudo docker exec -it $(sudo docker ps -aqf "name=gitlab-gitlab-1") grep 'Password:' /etc/gitlab/initial_root_password

          # Openldap - Sample DIF 적용
          $ docker exec -it openldap ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/init.ldif

          # 서비스 종료
          $ docker compose -f docker-compose.yaml -p gitlab down
          $ docker network rm gitlab-network
        ```
  
     5. 확인
        1. **gitlab** - https://<YOUR_DOMAIN> 에 접속하고 아래 명령으로 **root/<initial_password>**
        2. **phpldapadmin** - http://<YOUR_IP>:8090/ 에 접속하고 **cn=maintainer,dc=workspace,dc=local/maintainer-pswd**

- **04 > 백업 및 복원**

  - [Backup](https://docs.gitlab.com/ee/administration/backup_restore/backup_gitlab.html)
      - 사용중인 GitLab License와 버전 전체 확인 (버전이 다를 시 restore 불가)
      - [GitLab 설정파일](https://docs.gitlab.com/ee/administration/backup_restore/backup_gitlab.html?tab=Linux+package#storing-configuration-files) 백업
          - Linux Package
              - /etc/gitlab/gitlab-secrets.json
              - /etc/gitlab/gitlab.rb
          - Docker
              - /srv/gitlab/config
      - [백업 명령어](https://docs.gitlab.com/ee/administration/backup_restore/backup_gitlab.html?tab=Docker#backup-command)
          - Linux Package
              - sudo gitlab-backup create
          - Docker
              - docker exec **t** <container name> gitlab-backup create
  - [Restore](https://docs.gitlab.com/ee/administration/backup_restore/restore_gitlab.html)
      - 동일한 버전의 GitLab Server 재구축
      - [Linux](https://docs.gitlab.com/ee/administration/backup_restore/restore_gitlab.html#restore-for-linux-package-installations)
          - puma와 sidekiq 서비스 중지
              - sudo gitlab-ctl stop puma
              - sudo gitlab-ctl stop sidekiq
          - 백업 데이터를 백업 경로(/var/opt/gitlab/backups)로 옮긴 후 restore
              - sudo gitlab-backup restore BACKUP=<백업데이터파일명>
          - gitlab 재시작
              - sudo gitlab-ctl restart
      - [Docker](https://docs.gitlab.com/ee/administration/backup_restore/restore_gitlab.html#restore-for-docker-image-and-gitlab-helm-chart-installations)
          - 컨테이너 내부에서 위의 절차 반복 (상세내역은 문서참조)

- **참조페이지**

  - nginx configuration
    - https://docs.gitlab.com/omnibus/settings/nginx.html
  - https 설정
    - https://docs.gitlab.com/omnibus/settings/ssl/index.html#configure-https-manually
  - ldap 설정
    - https://docs.gitlab.com/ee/administration/auth/ldap/index.html
    - https://docs.gitlab.com/ee/administration/auth/ldap/ldap_synchronization.html
  
## gitlab 리소스 조정
 
nginx, mysql 같은 다른 패키지들과 달리, GitLab을 구성할 시 단순히 GitLab이 설치 되는것이 아니라 GitLab Rails(Puma, Sidekiq, etc), Gitaly, Redis, PostgreSQL, Nginx, Promethus 같은 네트워크, 스토리지, 모니터링 관련 여러 구성요소가 한꺼번에 설치된다.([Gitlab ombinus, Reference Architectures 참고](https://docs.gitlab.com/ee/administration/reference_architectures/1k_users.html))

![image.png](/pictures/image%206.png)

관련하여 [https://docs.gitlab.com/omnibus/settings/memory_constrained_envs.html](https://docs.gitlab.com/omnibus/settings/memory_constrained_envs.html) 에 메모리 최적화 방안은 아래와 같다. 기본값과 비교해 보려면 [gitlab.rb의 default](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template#L2625-2647) 값 페이지를 확인해보자.

```bash
# /etc/gitlab/gitlab.rb
puma['worker_processes'] = 0
puma['per_worker_max_memory_mb'] = 1024

sidekiq['max_concurrency'] = 10

prometheus_monitoring['enable'] = false

gitlab_rails['env'] = {
  'MALLOC_CONF' => 'dirty_decay_ms:1000,muzzy_decay_ms:1000'
}

gitaly['configuration'] = {
  concurrency: [
    {
      'rpc' => "/gitaly.SmartHTTPService/PostReceivePack",
      'max_per_repo' => 3,
    }, {
      'rpc' => "/gitaly.SSHService/SSHUploadPack",
      'max_per_repo' => 3,
    },
  ],
  cgroups: {
    repositories: {
      count: 2,
    },
    mountpoint: '/sys/fs/cgroup',
    hierarchy_root: 'gitaly',
    memory_bytes: 500000,
    cpu_shares: 512,
  },
}
gitaly['env'] = {
  'MALLOC_CONF' => 'dirty_decay_ms:1000,muzzy_decay_ms:1000',
  'GITALY_COMMAND_SPAWN_MAX_PARALLEL' => '2'
}

postgresql['shared_buffers'] = "256MB"

$ sudo gitlab-ctl reconfigure
```

- **Puma**
    - GitLab 의 Web 서버를 담당하는 구성요소
        
        > *Puma is a fast, multi-threaded, and highly concurrent HTTP 1.1 server for Ruby applications. It runs the core Rails application that provides the user-facing features of GitLab.*
        > 
        > 
        > [Configure the bundled Puma instance of the GitLab package](https://docs.gitlab.com/ee/administration/operations/puma.html)
        > 
    - **worker_processes** 설정
        - 기본적으로 Puma는 동시연결을 처리하기 위해 클러스터 모드로, 기본 2개의 worker_process를 갖도록 구성된다. 필요하다면 단일 프로세스로 처리할 수 있도록 설정값을 변경할 수 있다.
            
            ```bash
            puma['worker_processes'] = 0
            ```
            
    - **per_worker_max_memory_mb** 설정
        - 개별 worker의 최대 메모리 사용량을 다음 설정을 통해 제한할 수 있다. 디폴트는 1200Mb이다.
        - [Reducing memory use](https://docs.gitlab.com/ee/administration/operations/puma.html#reducing-memory-use)
            
            ```bash
            puma['per_worker_max_memory_mb'] = 1024 # 1GB
            ```
            
- **Sidekiq**
    - 비동기 작업을 처리하는 백그라운드 작업 큐
        
        > *Sidekiq is the background job processor GitLab uses to asynchronously run tasks*
        > 
    - 관련하여 아래 이슈들이 종종 있는 모양임
        - [https://serverfault.com/questions/818489/gitlab-extremely-high-memory-consumption-by-ruby-bundle-process](https://serverfault.com/questions/818489/gitlab-extremely-high-memory-consumption-by-ruby-bundle-process)
    - 기본적으로 sidekiq은 50개의 동시성(concurrency)를 갖고 구동된다. 다음 설정을 통해 그보다 적은 값으로 변경할 수 있다. 동시성이 줄어 백그라운드 작업이 queue에서 대기하는 시간이 길어지긴 할 것으로 보인다.
        
        ```bash
        # sudo vi /etc/gitlab/gitlab.rb 
        sidekiq['max_concurrency'] = 10
        ```
        
    - Sidekiq 메모리 제한 환경 변수 설정
        
        ```bash
        version: '3.7'
        services:
          gitlab:
            image: your-gitlab-image
            environment:
              - SIDEKIQ_MEMORY_KILLER_MAX_RSS=2000000
              - SIDEKIQ_MEMORY_KILLER_GRACE_TIME=900
              - SIDEKIQ_MEMORY_KILLER_HARD_LIMIT_RSS=3000000
              - SIDEKIQ_MEMORY_KILLER_CHECK_INTERVAL=3
              - SIDEKIQ_MEMORY_KILLER_SHUTDOWN_WAIT=30
              - GITLAB_MEMORY_WATCHDOG_ENABLED=true
              ...
        ```
        
        1. **SIDEKIQ_MEMORY_KILLER_MAX_RSS (KB)**:
            - **목적**: RSS(상주 집합 크기) 메모리에 대한 소프트 제한 설정.
            - **동작**: 이 제한을 초과하면 설정된 유예 시간 이상 지속되었을 때 Sidekiq가 재시작됨.
            - **기본값**: 2,000,000 KB (2 GB).
            - **참고**: 설정하지 않거나 0으로 설정하면 이 제한은 모니터링되지 않음.
        2. **SIDEKIQ_MEMORY_KILLER_GRACE_TIME (초)**:
            - **목적**: 소프트 제한을 초과할 수 있는 최대 시간 정의.
            - **기본값**: 900초 (15분).
            - **동작**: 이 시간 동안 메모리 사용량이 소프트 제한 아래로 떨어지면 재시작이 취소됨.
        3. **SIDEKIQ_MEMORY_KILLER_HARD_LIMIT_RSS (KB)**:
            - **목적**: RSS 메모리에 대한 하드 제한 설정.
            - **동작**: 이 제한을 초과하면 Sidekiq가 즉시 재시작됨.
            - **참고**: 설정하지 않거나 0으로 설정하면 이 제한은 모니터링되지 않음.
        4. **SIDEKIQ_MEMORY_KILLER_CHECK_INTERVAL (초)**:
            - **목적**: 메모리 사용량을 확인하는 주기 설정.
            - **기본값**: 3초.
        5. **SIDEKIQ_MEMORY_KILLER_SHUTDOWN_WAIT (초)**:
            - **목적**: 재시작 중 작업이 완료될 수 있는 최대 시간.
            - **기본값**: 30초.
            - **참고**: 이 기간 동안 새로운 작업은 수락되지 않음.
        6. **강제 종료**:
            - 재시작이 수행되지 않으면 Sidekiq는 종료 타임아웃(기본값 25초) + 2초 후에 강제로 종료됨. 실행 중인 작업은 SIGTERM 신호로 중단됨.
        7. **GITLAB_MEMORY_WATCHDOG_ENABLED**:
            - **목적**: 기본적으로 메모리 모니터링(워치독) 활성화.
            - **동작**: `false`로 설정하면 워치독이 비활성화됨.
- **Gitaly**
    - Gitlay는 git repository data를 저장하는 서비스
        
        > [*Gitaly](https://gitlab.com/gitlab-org/gitaly) provides high-level RPC access to Git repositories. It is used by GitLab to read and write Git data.*
        > 
        - NFS를 대체하며 Cluster 구성이 가능
        - 클러스터 구성시 gRPC 를 통해 다수의 Node간 git data 를 동기화
    - **Concurrency & Mem limit**
        - 기본값
            - Repo 당 HTTP Receive 20
            - SSH Upload 5의 동시성
            - 최대 메모리는 12GB(memory_bytes: 12884901888)
            
            ```bash
            gitaly['configuration'] = {
               ...
                concurrency: [
                  {
                    'rpc' => "/gitaly.SmartHTTPService/PostReceivePack",
                    'max_per_repo' => 3,
                  }, {
                    'rpc' => "/gitaly.SSHService/SSHUploadPack",
                    'max_per_repo' => 3,
                  },
                ],
                cgroups: {
                    repositories: {
                        count: 2,
                    },
                    mountpoint: '/sys/fs/cgroup',
                    hierarchy_root: 'gitaly',
                    memory_bytes: 500000, # 12884901888
                    cpu_shares: 512,
                },
            }
            ```
            
- **Prometheus**
    - GitLab은 자체 서비스 모니터링을 위한 Prometheus가 내장되어있다. 그러나 GitLab 자체에 대한 모니터링이 크게 필요하지않다면 내장 프로메테우스를 비활성활 수 있다.
        
        ```bash
        prometheus_monitoring['enable'] = false
        ```
        
- **Rails**
    - GitLab의 핵심 애플리케이션 프레임워크로, 웹 인터페이스와 API를 포함한 전체 시스템의 비즈니스 로직을 처리
        
        > *At the heart of GitLab is a web application built using the Ruby on Rails framework.*
        > 
    - GitLab Rails는 [jemalloc](https://github.com/jemalloc/jemalloc)이라는 메모리 할당자(memory allocator)를 사용한다. jemalloc은 성능 향상을 위해 필요한 메모리보다 더 많이 사전에 할당받는다. 이를 다음의 설정으로 변경할 수 있다.
        
        ```bash
        gitlab_rails['env'] = {
          'MALLOC_CONF' => 'dirty_decay_ms:1000,muzzy_decay_ms:1000'
        }
        
        gitaly['env'] = {
          'MALLOC_CONF' => 'dirty_decay_ms:1000,muzzy_decay_ms:1000'
        }
        ```
        
- **Postgresql**
    - GitLab의 주 데이터베이스로, Gitlab 자체의 유저 정보 및 프로젝트 등 데이터 관리를 위해 postgreSQL을 사용
    - 공식 문서 원문에는 나와있지 않지만, 관련 글들 구글링하던 중 [High memory usage for Gitlab CE](https://stackoverflow.com/questions/36122421/high-memory-usage-for-gitlab-ce)에서 제안되었다. shared_buffers는 PostgreSQL이 메모리에서 데이터를 읽고 쓸 때 사용하는 공유 메모리 영역의 크기를 제어하는 매개변수이다. 과다하게 낮추면 그것대로 작동을 느려지게 하므로 적정값으로 셋팅한다.
        
        ```bash
        postgresql['shared_buffers'] = "256MB"
        ```
        
- **이외 확인이 필요한 서비스들**
    - **Consul** : 서비스 디스커버리를 제공하여 서비스 위치와 상태 정보를 관리
    - **Patroni** : PostgreSQL 데이터베이스 클러스터의 고가용성을 관리하며, 자동 장애 복구와 리더 선출을 담당
    - **Pgbouncer** : 데이터베이스 connection pool 관리 및 failover 조치 수행
    - **Praefect** : Git 클라이언트와 Gitaly 스토리지 노드 간 투명한 프록시 역할
    - **Gitlab Workhorse** : GitLab의 리버스 프록시로, 대용량 파일 업로드, Git clone 및 push 등의 작업을 처리
    - **Redis** : GitLab에서 주로 캐싱 및 세션 데이터 저장에 사용
    - **Redis Sentinel** : Redis 인스턴스들의 상태를 모니터링하고, 장애 발생 시 자동으로 장애 복구 수행