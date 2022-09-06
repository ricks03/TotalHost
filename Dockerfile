FROM httpd:2.4

RUN apt-get update
RUN apt-get install -y dos2unix build-essential cpanminus

# RUN cpan CGI CGI::Session CGI::Session::Auth MIME::Lite MIME-tools mail::pop3client \
#         MIME::Parser Mail::POP3Client File::Copy::Recursive Email::Valid

RUN rm /usr/local/apache2/htdocs/*
COPY ./html /usr/local/apache2/htdocs/html
COPY ./images /usr/local/apache2/htdocs/images
COPY ./downloads /usr/local/apache2/htdocs/downloads

COPY ./scripts /usr/local/apache2/scripts
RUN chmod -v 775 /usr/local/apache2/scripts/*.pl
RUN dos2unix /usr/local/apache2/scripts/*

COPY ./conf/httpd.conf /usr/local/apache2/conf/
