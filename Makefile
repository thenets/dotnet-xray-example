IMAGE_TAG=webapp

build:
	docker build -t $(IMAGE_TAG) .

run:
	docker run -it --rm \
		-p 5000:80 \
		$(IMAGE_TAG)
