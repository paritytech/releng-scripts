set positional-arguments

tests *args:
  ./tasks/tests.sh "$@"

linters *args:
  ./tasks/linters.sh "$@"

bukt *args:
  ./bukt "$@"
