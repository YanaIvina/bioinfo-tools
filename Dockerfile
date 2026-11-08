FROM ubuntu:22.04

# Версии инструментов
ARG SAMTOOLS_VERSION=1.25
ARG HTSLIB_VERSION=1.25
ARG LIBDEFLATE_VERSION=1.26
ARG BCFTOOLS_VERSION=1.25
ARG VCFTOOLS_VERSION=0.1.17

ENV DEBIAN_FRONTEND=noninteractive
ENV SOFT=/soft

# Полные пути до директорий с исполняемыми файлами
ENV PATH=$SOFT/samtools-${SAMTOOLS_VERSION}/bin:$SOFT/bcftools-${BCFTOOLS_VERSION}/bin:$SOFT/vcftools-${VCFTOOLS_VERSION}/bin:$PATH
# динамические библиотеки
ENV LD_LIBRARY_PATH=$SOFT/htslib-${HTSLIB_VERSION}/lib:$SOFT/libdeflate-${LIBDEFLATE_VERSION}/lib
# полные пути до исполняемых файлов 
ENV SAMTOOLS=$SOFT/samtools-${SAMTOOLS_VERSION}/bin/samtools
ENV BCFTOOLS=$SOFT/bcftools-${BCFTOOLS_VERSION}/bin/bcftools
ENV VCFTOOLS=$SOFT/vcftools-${VCFTOOLS_VERSION}/bin/vcftools

# Общие пакеты одним слоем с удалением лишних файлов
# базовые зависимости + зависимости htslib, samtools, bcftools, vcftools + Python для скрипта Задачи №3 (convert_snp.py, pysam)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential pkg-config autoconf automake libtool wget ca-certificates \
    zlib1g-dev libbz2-dev liblzma-dev libcurl4-openssl-dev libssl-dev perl libgsl-dev libncurses-dev cmake\
    python3 python3-pip python3-dev \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p $SOFT /tmp/build
# временный каталог для сборки
WORKDIR /tmp/build

# СКАЧИВАНИЕ АРХИВА -> РАСПАКОВКА -> СБОРКА С РАСПАРАЛЛЕРИВАНИЕМ -> УСТАНОВКА -> УДАЛЕНИЕ ИСХОДНИКОВ

# ---------- libdeflate 1.26 (релиз 2026-08-22) ----------
RUN wget -q https://github.com/ebiggers/libdeflate/archive/refs/tags/v${LIBDEFLATE_VERSION}.tar.gz && \
    tar -xzf v${LIBDEFLATE_VERSION}.tar.gz && \
    cd libdeflate-${LIBDEFLATE_VERSION} && \
    cmake -B build -DCMAKE_INSTALL_PREFIX=$SOFT/libdeflate-${LIBDEFLATE_VERSION} -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j$(nproc) && \
    cmake --install build && \
    cd /tmp/build && \
    rm -rf libdeflate-${LIBDEFLATE_VERSION} v${LIBDEFLATE_VERSION}.tar.gz

# ---------- htslib 1.25 (релиз 2026-10-27) ----------
RUN wget -q https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 && \
    tar -xjf htslib-${HTSLIB_VERSION}.tar.bz2 && \
    cd htslib-${HTSLIB_VERSION} && \
    CPPFLAGS="-I$SOFT/libdeflate-${LIBDEFLATE_VERSION}/include" \
    LDFLAGS="-L$SOFT/libdeflate-${LIBDEFLATE_VERSION}/lib" \
    ./configure --prefix=$SOFT/htslib-${HTSLIB_VERSION} --with-libdeflate && \
    make -j$(nproc) && \
    make install && \
    cd /tmp/build && \
    rm -rf htslib-${HTSLIB_VERSION} htslib-${HTSLIB_VERSION}.tar.bz2

# ---------- samtools 1.25 (релиз 2026-10-27) ----------
RUN wget -q https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 && \
    tar -xjf samtools-${SAMTOOLS_VERSION}.tar.bz2 && \
    cd samtools-${SAMTOOLS_VERSION} && \
    ./configure --prefix=$SOFT/samtools-${SAMTOOLS_VERSION} --with-htslib=$SOFT/htslib-${HTSLIB_VERSION} && \
    make -j$(nproc) && \
    make install && \
    cd /tmp/build && \
    rm -rf samtools-${SAMTOOLS_VERSION} samtools-${SAMTOOLS_VERSION}.tar.bz2


# ---------- bcftools 1.25 (релиз 2026-10-27) ----------
RUN wget -q https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2 && \
    tar -xjf bcftools-${BCFTOOLS_VERSION}.tar.bz2 && \
    cd bcftools-${BCFTOOLS_VERSION} && \
    CPPFLAGS="-I$SOFT/libdeflate-${LIBDEFLATE_VERSION}/include" \
    LDFLAGS="-L$SOFT/libdeflate-${LIBDEFLATE_VERSION}/lib" \
    ./configure --prefix=$SOFT/bcftools-${BCFTOOLS_VERSION} --with-htslib=$SOFT/htslib-${HTSLIB_VERSION} && \
    make -j$(nproc) && \
    make install && \
    cd /tmp/build && \
    rm -rf bcftools-${BCFTOOLS_VERSION} bcftools-${BCFTOOLS_VERSION}.tar.bz2

# ---------- vcftools 0.1.17 (релиз 2025-08-22) ----------
RUN wget -q https://github.com/vcftools/vcftools/releases/download/v${VCFTOOLS_VERSION}/vcftools-${VCFTOOLS_VERSION}.tar.gz && \
    tar -xzf vcftools-${VCFTOOLS_VERSION}.tar.gz && \
    cd vcftools-${VCFTOOLS_VERSION} && \
    ./configure --prefix=$SOFT/vcftools-${VCFTOOLS_VERSION} && \
    make -j$(nproc) && \
    make install && \
    cd /tmp/build && \
    rm -rf vcftools-${VCFTOOLS_VERSION} vcftools-${VCFTOOLS_VERSION}.tar.gz

# Проверка установки
RUN samtools --version && bcftools --version && vcftools --version

# Python-зависимости и скрипт для Задачи №3
RUN pip3 install --no-cache-dir pysam=0.24.1
WORKDIR /workspace
COPY convert_snp.py /workspace/convert_snp.py

# Открыть интерактивный терминал при запуске
CMD ["/bin/bash"]