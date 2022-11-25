set positional-arguments
export docker_image_name := "releng-scripts"
default_owner := "paritytech"

# List available commands
_default:
  just --choose --chooser "fzf +s -x --tac --cycle"

# Show some help
help:
	just --list

tests *args:
  ./tasks/tests.sh "$@"

linters *args:
  ./tasks/linters.sh "$@"

rs *args:
  ./rs "$@"

# Build the Docker image
build_docker_image owner=default_owner:
  docker build -t $docker_image_name -t {{owner}}/$docker_image_name .
  docker images | grep "rs"

run *args:
  docker run --rm -it rs "$@"

# Push the docker image
publish_docker_image owner=default_owner: (build_docker_image owner)
  docker push {{owner}}/$docker_image_name

# Publish everything
publish: publish_docker_image
