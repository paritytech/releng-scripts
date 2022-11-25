FROM ubuntu

COPY . .

ENTRYPOINT [ "./rs" ]
