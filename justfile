set positional-arguments
export docker_image_name := "releng-scripts"
export ENGINE := "podman"
default_owner := "paritytech"

# List available commands
_default:
  just --choose --chooser "fzf +s -x --tac --cycle"

# Install required tooling
setup:
  pip install pre-commit

# Show some help
help:
  just --list

tests *args:
  ./tasks/tests.sh "$@"

linters *args:
  ./tasks/linters.sh "$@"

releng-scripts *args:
  ./releng-scripts "$@"

# Run as container
run *args:
  $ENGINE run --rm -it releng-scripts "$@"

# Build the docker image
build_docker_image owner=default_owner:
  $ENGINE build -t {{owner}}/$docker_image_name .
  $ENGINE images | grep {{owner}}/$docker_image_name

# Push the docker image
publish_docker_image owner=default_owner: (build_docker_image owner)
  $ENGINE push {{owner}}/$docker_image_name

# Publish everything
publish: publish_docker_image

# Generate the readme as Markdown file
md:
    #!/usr/bin/env bash
    asciidoctor -b docbook -a leveloffset=+1 -o - README_src.adoc | pandoc   --markdown-headings=atx --wrap=preserve -t markdown_strict -f docbook - > README.md
