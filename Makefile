NAME = dockerizer 
HARDWARE = $(shell uname -m)
VERSION ?= 0.1.0
IMAGE_NAME ?= $(NAME)
BUILD_TAG ?= dev

build:
	mkdir -p include/buildpacks
	cat buildpacks/lastbackend/*/buildpack* | sed 'N;s/\n/ /' > include/buildpacks/lastbackend.txt
	cat buildpacks/heroku/*/buildpack*      | sed 'N;s/\n/ /' > include/buildpacks/heroku.txt
	cp -r dockerfiles /tmp/dockerfiles
	go-bindata include
	mkdir -p build/linux  && GOOS=linux  go build -ldflags "-X main.Version=$(VERSION)" -o build/linux/$(NAME)
	mkdir -p build/darwin && GOOS=darwin go build -ldflags "-X main.Version=$(VERSION)" -o build/darwin/$(NAME)

image:
	docker build -f Dockerfile -t $(NAME) .

rebuild:
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v ${PWD}:/usr/src/dockerizer \
		-w /usr/src/dockerizer \
		-e IMAGE_NAME=$(IMAGE_NAME) -e BUILD_TAG=$(BUILD_TAG) -e VERSION=master \
		$(NAME) make -e build

clean:
	rm -rf build/*
	docker rm $(shell docker ps -aq) || true
	docker rmi $(NAME)-build || true

deps:
	go get -u github.com/jteeuwen/go-bindata/...
	go get -u github.com/progrium/gh-release/...
	go get -u github.com/progrium/basht/...
	go get || true

buildpacks-install:
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v ${PWD}:/usr/src/dockerizer \
		-v /tmp/buildpacks:/tmp/buildpacks \
		-v /opt/lastbackend/buildpacks:/tmp/lastbackend \
		-w /usr/src/dockerizer \
		-e IMAGE_NAME=$(IMAGE_NAME) \
		-e BUILD_TAG=$(BUILD_TAG) -e VERSION=master \
		$(NAME) dockerizer buildpack install

test:
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v ${PWD}:/usr/src/dockerizer \
		-v /tmp/buildpacks:/tmp/buildpacks \
		-v /opt/lastbackend/buildpacks:/tmp/buildpacks/lastbackend \
		-w /usr/src/dockerizer \
		-e IMAGE_NAME=$(IMAGE_NAME) \
		-e BUILD_TAG=$(BUILD_TAG) -e VERSION=master \
		$(NAME) basht tests/*/tests.sh

release: build
	rm -rf release && mkdir release
	tar -zcf release/$(NAME)_$(VERSION)_linux_$(HARDWARE).tgz -C build/linux $(NAME)
	tar -zcf release/$(NAME)_$(VERSION)_darwin_$(HARDWARE).tgz -C build/darwin $(NAME)
	gh-release create lastbackend/$(NAME) $(VERSION) $(s-ldflagsarse --abbrev-ref HEAD) v$(VERSION)

.PHONY: build
