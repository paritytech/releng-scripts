set positional-arguments
export docker_image_name := "releng-scripts"
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

# Run rs
rs *args:
  ./rs "$@"


# Run using docker
run *args:
  docker run --rm -it rs "$@"

# Push the docker image
publish_docker_image owner=default_owner: (build_docker_image owner)
  docker push {{owner}}/$docker_image_name

# Publish everything
publish: publish_docker_image

# Generate the readme as Markdown file

md:
    #!/usr/bin/env bash
    asciidoctor -b docbook -a leveloffset=+1 -o - README_src.adoc | pandoc   --markdown-headings=atx --wrap=preserve -t markdown_strict -f docbook - > README.md
