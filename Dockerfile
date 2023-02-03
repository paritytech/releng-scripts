FROM ubuntu

WORKDIR /scripts

COPY . .

ENTRYPOINT [ "./rs" ]
