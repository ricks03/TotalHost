FROM httpd:2.4

RUN apt-get update
RUN apt-get install -y dos2unix build-essential cpanminus

# RUN cpan CGI CGI::Session CGI::Session::Auth MIME::Lite MIME-tools mail::pop3client \
#         MIME::Parser Mail::POP3Client File::Copy::Recursive Email::Valid

ENV TOTALHOST_DOC_ROOT=/usr/local/apache2/totalhost-htdocs

RUN mkdir -p ${TOTALHOST_DOC_ROOT}
COPY ./html ${TOTALHOST_DOC_ROOT}/html
COPY ./images ${TOTALHOST_DOC_ROOT}/images
COPY ./downloads ${TOTALHOST_DOC_ROOT}/downloads

COPY ./scripts /${TOTALHOST_DOC_ROOT}/scripts
RUN dos2unix ${TOTALHOST_DOC_ROOT}/scripts/*

RUN chown -R www-data:www-data ${TOTALHOST_DOC_ROOT}
RUN chmod -R a+r ${TOTALHOST_DOC_ROOT}
RUN chmod -v 775 ${TOTALHOST_DOC_ROOT}/scripts/*.pl

COPY ./conf/ /usr/local/apache2/conf/

EXPOSE 8080
