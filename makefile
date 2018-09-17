-include makefile.pass

# {{{ -- meta

OPSYS            := jinade
SVCNAME          := install

USERNAME         := cretinon
GITHUB_USER      := cretinon
EMAIL            := jacques@cretinon.fr

# -- }}}

# {{{ -- docker targets

install_deb_pkg : 
	apt-get update && apt-get upgrade && apt-get -y -q install --no-install-recommends apt-show-versions dnsutils net-tools lsof procps git curl ca-certificates bash emacs make

init_ssh :
	ssh-keygen -q -t rsa -f /root/.ssh/id_rsa -N ""

enable_swap :
	dd if=/dev/zero of=/swap bs=1024 count=1024000
	mkswap -c /swap 1024000
	chmod 0600 /swap
	swapon /swap

install_docker :
	echo "please disable proxy in your apt.conf"
	curl -sSL https://get.docker.com | sh 
	curl -L https://github.com/docker/compose/releases/download/1.17.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
	sed -i /lib/systemd/system/docker.service -e 's/-H fd:\/\//-H tcp:\/\/0.0.0.0:4356 -H fd:\/\/ --experimental=true --metrics-addr=0.0.0.0:9323/'
	systemctl daemon-reload
	systemctl restart docker

swarm_init :
	if ifconfig | grep -w $(MASTER_IP) > /dev/null ; then \
		docker swarm init ; \
		echo "#!/bin/sh" > /tmp/join_as_manager.sh.tmp ;\
		docker swarm join-token manager | grep join >> /tmp/join_as_manager.sh.tmp ;\
		chmod +x /tmp/join_as_manager.sh.tmp ;\
		scp -oStrictHostKeyChecking=no /tmp/join_as_manager.sh.tmp $(SLAVE1_IP):/tmp/join_as_manager.sh ;\
		scp -oStrictHostKeyChecking=no /tmp/join_as_manager.sh.tmp $(SLAVE2_IP):/tmp/join_as_manager.sh ;\
	else \
		while [ ! -x /tmp/join_as_manager.sh ]; do echo "waiting swarm" ; sleep 10 ; done ;\
		/tmp/join_as_manager.sh ;\
	fi

install_portainer :
	mkdir -p /docker/share/portainer/data
	docker stack deploy -c portainer.yml portainer

install_gluster :
	cd /git_clone && git clone https://github.com/cretinon/jinade_gluster.git
	mkdir -p /glusterfs/data ; mkdir -p /glusterfs/metadata ; mkdir -p /glusterfs/etc
	if [ $(NODE) = "master" ];then \
		echo "127.0.0.1 gluster-1" > /glusterfs/etc/hosts ; \
		echo "10.2.0.11 gluster-2" >> /glusterfs/etc/hosts ; \
		cd /git_clone/jinade_gluster ; \
		make ARCH=x86_64 DISTRIB=debian IP=10.2.0.10 build start ;\
	else \
		echo "127.0.0.1 gluster-2" > /glusterfs/etc/hosts ; \
		echo "10.2.0.10 gluster-1" >> /glusterfs/etc/hosts ;  \
		cd /git_clone/jinade_gluster ; \
		make ARCH=x86_64 DISTRIB=debian IP=10.2.0.11 build start ; \
	fi

install_swarmprom :
	cd /git_clone && git clone https://github.com/stefanprodan/swarmprom.git
	cd swarmprom
	ADMIN_USER=admin \
	ADMIN_PASSWORD=$(PASS_SLACK) \
	SLACK_URL=$(SLACK_URL) \
	SLACK_CHANNEL=devops-alerts \
	SLACK_USER=jacques \
	docker stack deploy -c docker-compose.yml mon

ifeq "$(NODE)" "master"
CONTARGS    := -j -v -c -d jinade.me -m --ns1 jinade1 --ipns1 217.182.142.201 -r
else
CONTARGS    := -j -v -c -d jinade.me -s -r
endif

install_bind :
	cd /root/git_clone && git clone https://github.com/cretinon/jinade_bind9.git
	if [ $(NODE) = "master" ];then \
		cd /root/git_clone/jinade_bind9 ; \
		make ARCH=x86_64 DISTRIB=debian IP=10.2.1.10 CONTARGS='$(CONTARGS)' build start ;\
		sleep 5 ;\
		make ARCH=x86_64 DISTRIB=debian EXECCOMMAND="/bin/bash -c '/usr/local/entrypoint.sh -v -j -d jinade.me -m -u A -h jinade2.jinade.me -a 217.182.142.99'"  eshell ;\
		make ARCH=x86_64 DISTRIB=debian EXECCOMMAND="/bin/bash -c '/usr/local/entrypoint.sh -v -j -d jinade.me -m -u NS -h jinade2.jinade.me -a 217.182.142.99'" eshell ;\
	else \
		cd /root/git_clone/jinade_bind9 ; \
		make ARCH=x86_64 DISTRIB=debian IP=10.2.1.11 CONTARGS='$(CONTARGS)' build start ; \
	fi 

# -- }}}

# {{{ -- New SCV / OPSYS

CUR_DIR := $(shell pwd)
BASE_DIR := $(shell cd .. ; pwd)

ifeq "$(origin NEW_OPSYS)" "undefined"
NEW_OPSYS := $(OPSYS)
endif

ifeq "$(origin NEW_SVC)" "undefined"
NEW_SVC := $(SVCNAME)
endif

NEW_SVC_DIR := $(NEW_OPSYS)_$(NEW_SVC)


svc_first_push :
		curl -u '$(GITHUB_USER):$(GITHUB_PASS)' https://api.github.com/user/repos -d '{"name":"'$(OPSYS)_$(SVCNAME)'"}' ;\
		git init ;\
		git add makefile README.md .dockerignore .gitignore  ;\
		git commit -m "first commit" ;\
		git remote add origin https://$(GITHUB_USER):$(GITHUB_PASS)@github.com/$(GITHUB_USER)/$(OPSYS)_$(SVCNAME).git ;\
		git push origin master ;\
		git push https://$(GITHUB_USER):$(GITHUB_PASS)@github.com/$(GITHUB_USER)/$(OPSYS)_$(SVCNAME).git ;\
# -- }}}
