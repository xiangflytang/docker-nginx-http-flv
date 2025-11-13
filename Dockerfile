FROM alpine:latest as builder

ARG NGINX_VERSION=1.21.1
ARG NGINX_HTTP_FLV_VERSION=1.2.9
ARG ALPINE_MIRROR=https://mirrors.aliyun.com/alpine/v3.14
ARG GITHUB_MIRROR=https://ghproxy.com/https://github.com

# 配置国内镜像源
RUN set -eux; \
    echo "${ALPINE_MIRROR}/main/" > /etc/apk/repositories; \
    echo "${ALPINE_MIRROR}/community/" >> /etc/apk/repositories; \
    apk update;

RUN apk add --no-cache \
        git \
        gcc \
        binutils \
        gmp \
        isl \
        libgomp \
        libatomic \
        libgcc \
        openssl \
        pkgconf \
        pkgconfig \
        mpc1 \
        libstdc++ \
        ca-certificates \
        libssh2 \
        curl \
        expat \
        pcre \
        musl-dev \
        libc-dev \
        pcre-dev \
        zlib-dev \
        openssl-dev \
	curl			\
        make

# 下载nginx（多镜像源备用）
RUN cd /tmp/ && \
    for mirror in \
        "https://mirrors.aliyun.com/nginx/nginx-${NGINX_VERSION}.tar.gz" \
        "https://mirrors.huaweicloud.com/nginx/nginx-${NGINX_VERSION}.tar.gz" \
        "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"; \
    do \
        echo "尝试从 $mirror 下载..."; \
        if curl --retry 3 --connect-timeout 30 -fsSL -o "nginx-${NGINX_VERSION}.tar.gz" "$mirror"; then \
            echo "下载成功"; \
            break; \
        fi; \
        echo "下载失败，尝试下一个镜像"; \
    done

# 克隆nginx-http-flv模块（多镜像源备用）
RUN cd /tmp/ && \
    # 尝试Gitee镜像
    git clone https://gitee.com/mirrors/nginx-http-flv-module.git -b v${NGINX_HTTP_FLV_VERSION} || \
    # 尝试GitHub加速
    git clone ${GITHUB_MIRROR}/winshining/nginx-http-flv-module.git -b v${NGINX_HTTP_FLV_VERSION} || \
    # 最后尝试原始GitHub
    git clone https://github.com/winshining/nginx-http-flv-module.git -b v${NGINX_HTTP_FLV_VERSION}

RUN cd /tmp/ && \
    tar xzf nginx-${NGINX_VERSION}.tar.gz && \
    cd nginx-${NGINX_VERSION} && \
    ./configure \
        --prefix=/opt/nginx \
        --with-http_ssl_module \
        --add-module=../nginx-http-flv-module && \
    make  && \
    make install

FROM alpine:latest
LABEL org.opencontainers.image.authors="lewang.dev@gmail.com"

# 配置运行时镜像源
RUN set -eux; \
    echo "https://mirrors.aliyun.com/alpine/v3.14/main/" > /etc/apk/repositories; \
    echo "https://mirrors.aliyun.com/alpine/v3.14/community/" >> /etc/apk/repositories; \
    apk update && \
    apk add --no-cache \
        openssl \
        libstdc++ \
        ca-certificates \
        pcre

COPY --from=builder /opt/nginx /opt/nginx
COPY --from=builder /tmp/nginx-http-flv-module/stat.xsl /opt/nginx/conf/stat.xsl
RUN rm -f /opt/nginx/conf/nginx.conf
COPY nginx.conf /opt/nginx/conf/nginx.conf
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 1935
EXPOSE 8080

STOPSIGNAL SIGTERM

CMD ["/opt/nginx/sbin/nginx", "-g", "daemon off;"]
