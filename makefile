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
	echo "please add public key to other hosts .ssh/authorized_keys"
	cat /root/.ssh/id_rsa.pub

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
	sed -i /lib/systemd/system/docker.service -e 's/-H fd:\/\//-H tcp:\/\/0.0.0.0:4356 -H fd:\/\/ --experimental=true --metrics-addr=0.0.0.0:4999/'
	systemctl daemon-reload
	systemctl restart docker

swarm_init :
	if ifconfig | grep $(MASTER_IP) > /dev/null ; then \
		docker swarm init ; \
		echo "#!/bin/sh" > /tmp/join_as_manager.sh.tmp ;\
		docker swarm join-token manager | grep join >> /tmp/join_as_manager.sh.tmp ;\
		chmod +x /tmp/join_as_manager.sh.tmp ;\
		scp /tmp/join_as_manager.sh.tmp $(SLAVE_IP):/tmp/join_as_manager.sh ;\
	else \
		while [ ! -x /tmp/join_as_manager.sh ]; do echo "waiting swarm" ; sleep 10 ; done ;\
		/tmp/join_as_manager.sh ;\
	fi

install_portainer :
	mkdir -p /docker/share/portainer/data
	docker stack deploy -c portainer.yml portainer

install_gluster :
	cd /root/git_clone && git clone https://github.com/cretinon/jinade_gluster.git && cd jinade_gluster && 	make ARCH=x86_64 DISTRIB=debian build
	mkdir -p /glusterfs/data ; mkdir -p /glusterfs/metadata ; mkdir -p /glusterfs/etc
	if [ $(NODE) = "master" ];then echo "127.0.0.1 gluster-1" > /glusterfs/etc/hosts ; echo "10.2.0.11 gluster-2" >> /glusterfs/etc/hosts ; cd /root/git_clone/jinade_gluster ; make ARCH=x86_64 DISTRIB=debian IP=10.2.0.10 build start else echo "127.0.0.1 gluster-2" > /glusterfs/etc/hosts ; echo "10.2.0.10 gluster-1" >> /glusterfs/etc/hosts ;  cd /root/git_clone/jinade_gluster ; make ARCH=x86_64 DISTRIB=debian IP=10.2.0.11 build start ; fi 

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
