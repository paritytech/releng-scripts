set positional-arguments

tests *args:
  ./run tests "$@"

linters *args:
  ./run linters "$@"

bukt *args:
  ./bukt "$@"
