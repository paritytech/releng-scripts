set positional-arguments

tests *args:
  ./tasks/tests.sh "$@"

linters *args:
  ./tasks/linters.sh "$@"

rs *args:
  ./rs "$@"
