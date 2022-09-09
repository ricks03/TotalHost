FROM httpd:2.4

RUN apt-get update
RUN apt-get install -y dos2unix build-essential cpanminus

RUN cpan DBI CGI CGI::Session CGI::Session::Auth CGI::Session::Auth::DBI
RUN cpan MIME::Lite MIME-tools MIME::Parser
RUN cpan File::Copy::Recursive
RUN cpan mail::pop3client Mail::POP3Client
RUN cpan Email::Valid

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
