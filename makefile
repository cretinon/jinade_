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
