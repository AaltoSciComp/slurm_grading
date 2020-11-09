FROM debian:buster-20200908-slim

ENV LANG=C.UTF-8 USER=root HOME=/root

ENV PATH="/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin:/usr/local/sbin:/root/bin"

# Tools for dockerfiles and image management
COPY rootfs /

# Base tools that are used by all images
RUN apt_install \
    runit \
    gettext-base \
    ca-certificates \
    curl \
    jo \
    jq \
    make \
    time \
    git \
    openssh-client \
    file \
 # Copy single binaries from packages and remove packages
 && cp /usr/bin/chpst \
       /usr/bin/envsubst \
       /usr/local/bin \
 && dpkg -P runit gettext-base \
 && apt-get -qqy autoremove \
 && dpkg -l|awk '/^rc/ {print $2}'|xargs -r dpkg -P \
 && (cd /usr/local/bin && ln -sf chpst setuidgid && ln -sf chpst softlimit && ln -sf chpst setlock) \
\
 # Create basic folders
 && mkdir -p /feedback /submission /exercise \
 && chmod 0770 /feedback \
\
 # Change HOME for nobody from /nonexistent to /tmp
 && usermod -d /tmp nobody \
 # Create two more nobody users
 && groupadd doer -g 65501 \
 && useradd doer -u 65501 -g 65501 -c "a nobody user" -s /usr/sbin/nologin -m -k - \
 && groupadd tester -g 65502 \
 && useradd tester -u 65502 -g 65502 -c "a nobody user" -s /usr/sbin/nologin -m -k - \
 && :

# Install common YUM dependency packages
RUN apt_install \
        autoconf \
        bash-completion \
        bzip2 \
        libbz2-dev \
        file \
        iproute2 \
        build-essential \
        libgdbm-dev \
        git \
        glibc-source \
        libgmp-dev \
        libffi-dev \
        libgl-dev \
        libx11-dev \
        make \
        mariadb-server \
        libmariadb-dev \
        munge \
        libmunge-dev \
        libncurses-dev \
        libssl-dev \
        perl \
        pkg-config \
        psmisc \
        libreadline-dev \
        libsqlite3-dev \
        tcl-dev \
        tix-dev \
        tk \
        tk-dev \
        supervisor \
        wget \
        vim \
        liblzma-dev \
        zlib1g-dev

COPY files/install-python.sh /tmp

#Install Python versions
ARG PYTHON_VERSIONS="2.7 3.5 3.6 3.7 3.8"
RUN set -ex \
    && for version in ${PYTHON_VERSIONS}; do /tmp/install-python.sh "$version"; done \
    && rm -f /tmp/install-python.sh

# Compile, build and install Slurm from Git source
ARG SLURM_TAG=slurm-19-05-4-1
#!/bin/bash
RUN set -ex \
    && git clone https://github.com/SchedMD/slurm.git \
    && cd slurm \
    && git checkout tags/$SLURM_TAG \
    && ./configure --enable-debug --enable-front-end --prefix=/usr \
       --sysconfdir=/etc/slurm --with-mysql_config=/usr/bin \
       --libdir=/usr/lib64 \
    && make install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && cd .. \
    && rm -rf slurm \
    && groupadd -r slurm  \
    && useradd -r -g slurm slurm \
    && mkdir -p /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/lib/slurmd \
        /var/log/slurm \
    && chown slurm:root /var/spool/slurmd \
        /var/run/slurmd \
        /var/lib/slurmd \
        /var/log/slurm \
    && /usr/sbin/create-munge-key

# Set Vim and Git defaults
RUN set -ex \
    && echo "syntax on"           >> $HOME/.vimrc \
    && echo "set tabstop=4"       >> $HOME/.vimrc \
    && echo "set softtabstop=4"   >> $HOME/.vimrc \
    && echo "set shiftwidth=4"    >> $HOME/.vimrc \
    && echo "set expandtab"       >> $HOME/.vimrc \
    && echo "set autoindent"      >> $HOME/.vimrc \
    && echo "set fileformat=unix" >> $HOME/.vimrc \
    && echo "set encoding=utf-8"  >> $HOME/.vimrc \
    && git config --global color.ui auto \
    && git config --global push.default simple

# Copy Slurm configuration files into the container
COPY files/slurm/slurm.conf /etc/slurm/slurm.conf
COPY files/slurm/gres.conf /etc/slurm/gres.conf
COPY files/slurm/slurmdbd.conf /etc/slurm/slurmdbd.conf
COPY files/supervisord.conf /etc/

# Mark externally mounted volumes
VOLUME ["/var/lib/mysql", "/var/lib/slurmd", "/var/spool/slurmd", "/var/log/slurm"]

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Fixups for Slurm CentOS -> Debian
RUN \
    ln -s /var/run /run && \
    mkdir /var/run/munge && \
    chown munge:munge /var/run/munge && \
    mkdir /var/run/supervisor/

# Add Tini
ARG TINI_VERSION=v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /sbin/tini
RUN chmod +x /sbin/tini

# Base grading tools
COPY bin /usr/local/bin

# Base environment
WORKDIR /submission
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh", "/gw"]
# CMD ["/exercise/run.sh"]