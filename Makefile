CHART_REPO := http://jenkins-x-chartmuseum:8080
NAME := conference
OS := $(shell uname)

CHARTMUSEUM_CREDS_USR := $(shell cat /builder/home/basic-auth-user.json)
CHARTMUSEUM_CREDS_PSW := $(shell cat /builder/home/basic-auth-pass.json)

init:
	helm init --client-only

setup: init
	helm repo add jenkins-x http://chartmuseum.jenkins-x.io
	helm repo add releases ${CHART_REPO}

build: clean setup
	helm dependency build conference
	helm lint conference

install: clean build
	helm upgrade ${NAME} conference --install

upgrade: clean build
	helm upgrade ${NAME} conference --install

delete:
	helm delete --purge ${NAME} conference

clean:
	rm -rf conference/charts
	rm -rf conference/${NAME}*.tgz
	rm -rf conference/requirements.lock

release: clean build
ifeq ($(OS),Darwin)
	sed -i "" -e "s/version:.*/version: $(VERSION)/" conference/Chart.yaml

else ifeq ($(OS),Linux)
	sed -i -e "s/version:.*/version: $(VERSION)/" conference/Chart.yaml
else
	exit -1
endif
	helm package conference
	curl --fail -u $(CHARTMUSEUM_CREDS_USR):$(CHARTMUSEUM_CREDS_PSW) --data-binary "@$(NAME)-$(VERSION).tgz" $(CHART_REPO)/api/charts
	rm -rf ${NAME}*.tgz
	jx step changelog  --verbose --version $(VERSION) --rev $(PULL_BASE_SHA)
