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


run *args:
  docker run --rm -it rs "$@"

# Generate the readme as .md
md:
    #!/usr/bin/env bash
    asciidoctor -b docbook -a leveloffset=+1 -o - README_src.adoc | pandoc   --markdown-headings=atx --wrap=preserve -t markdown_strict -f docbook - > README.md
