FROM perl:5.34

RUN cpan LWP::UserAgent

RUN wget -O /tmp/wait-for.tar.gz https://github.com/dnnrly/wait-for/releases/download/v0.0.5/wait-for_0.0.5_linux_amd64.tar.gz \
    && tar -zxvf /tmp/wait-for.tar.gz \
    && cp wait-for /usr/local/bin/

RUN wget -O /usr/local/bin/goose https://github.com/pressly/goose/releases/download/v3.7.0/goose_linux_x86_64 \
    && chmod a+x /usr/local/bin/goose