FROM apluslms/grading-base:latest

ENV PATH="/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin:/usr/local/sbin:/root/bin"

# Install common YUM dependency packages
RUN apt_install \
        autoconf \
        automake \
        bash-completion \
        bzip2 \
        libbz2-dev \
        file \
        iproute2 \
        build-essential \
        libgdbm-dev \
        git \
        glibc-source \
        lmod \
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
        tcl \
        tcl-dev \
        tix-dev \
        tk \
        tk-dev \
        sed \
        supervisor \
        procps \
        wget \
        vim \
        liblzma-dev \
        zlib1g-dev \
        python3

COPY files/install-python.sh /tmp

#Install Python versions
ARG PYTHON_VERSIONS="2.7 3.5 3.6 3.7 3.8"
RUN set -ex \
    && for version in ${PYTHON_VERSIONS}; do /tmp/install-python.sh "$version"; done \
    && rm -f /tmp/install-python.sh

# Compile, build and install Slurm from Git source
ARG SLURM_TAG=slurm-19-05-4-1
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

# Add some modulefiles: hello and pi
RUN \
    mkdir -p /usr/local/modules/hello/bin/ && \
    mkdir -p /usr/local/modules/pi/bin/ && \
    cd /tmp && \
    git clone https://github.com/AaltoSciComp/hpc-examples && \
    mv hpc-examples/slurm/pi.py /usr/local/modules/pi/bin/pi && \
    mv hpc-examples/slurm/pi_aggregation.py /usr/local/modules/pi/bin/pi_aggregation && \
    mv hpc-examples/slurm/pi-mpi.py /usr/local/modules/pi/bin/pi-mpi && \
    gcc hpc-examples/slurm/pi-openmp.c -o /usr/local/modules/pi/bin/pi-openmp && \
    chmod a+x /usr/local/modules/pi/bin/* && \
    rm -rf hpc-examples
COPY files/hello-world /usr/local/modules/hello/bin/
COPY files/modulefiles/ /usr/share/modulefiles/
RUN echo "/usr/share/modulefiles/" >> /etc/lmod/modulespath 


ENV PATH="/root/miniconda3/bin:${PATH}"
ARG PATH="/root/miniconda3/bin:${PATH}"
RUN apt-get update

RUN apt-get install -y wget && rm -rf /var/lib/apt/lists/*

RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && mkdir -p /usr/local/modules/conda/bin/ \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh 
RUN conda --version

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh", "/gw"]
CMD bash -c "source /etc/profile.d/lmod.sh && bash"