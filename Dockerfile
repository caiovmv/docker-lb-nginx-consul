FROM debian:stretch-slim

MAINTAINER "Caio Villela <villela.caio@gmail.com"

ENV NGINX_VERSION 1.13.1-1~stretch
ENV NJS_VERSION   1.13.1.0.1.10-1~stretch

ENV CONSUL_TEMPLATE_VERSION="0.18.4"

RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y gnupg1 vim bash telnet wget net-tools sysstat curl ca-certificates gnupg1 unzip ntp\
        && apt-get upgrade -y \
        && \
	NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
	apt-get remove --purge -y gnupg1 && apt-get -y --purge autoremove && rm -rf /var/lib/apt/lists/* \
	&& echo "deb http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
						nginx=${NGINX_VERSION} \
						nginx-module-xslt=${NGINX_VERSION} \
						nginx-module-geoip=${NGINX_VERSION} \
						nginx-module-image-filter=${NGINX_VERSION} \
						nginx-module-njs=${NJS_VERSION} \
						gettext-base \
	&& rm -rf /var/lib/apt/lists/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

ENV CT_URL https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip
#ENV CT_URL https://releases.hashicorp.com/consul-template/0.18.5/consul-template_0.18.5_linux_amd64.zip
RUN curl -o consul-template.zip $CT_URL
RUN unzip consul-template.zip
RUN chmod a+x consul-template
RUN mv consul-template /usr/bin/consul-template

ADD nginx.service /etc/service/nginx/run
ADD consul-template.service /etc/service/consul-template/run

RUN rm -v /etc/nginx/conf.d/*
ADD nginx.conf /etc/consul-templates/nginx.conf

CMD ["/usr/bin/runsvdir", "/etc/service"]

EXPOSE 80

STOPSIGNAL SIGTERM

#CMD ["nginx", "-g", "daemon off;"]
