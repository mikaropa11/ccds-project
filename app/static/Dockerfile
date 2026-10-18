FROM httpd:2.4-alpine

COPY public/ /usr/local/apache2/htdocs/static/
COPY static.conf /usr/local/apache2/conf/extra/static.conf
RUN echo "Include conf/extra/static.conf" >> /usr/local/apache2/conf/httpd.conf

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/static/style.css >/dev/null || exit 1
