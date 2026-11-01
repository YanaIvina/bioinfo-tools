# Docker-образ для инструментов биоинформатики

## Введение

Данный репозиторий содержит `Dockerfile` для сборки образа на базе **Ubuntu 22.04**, включающего следующие биоинформатические инструменты, собранные из исходников:

- **samtools** (1.25)
- **bcftools** (1.25)
- **htslib** (1.25)
- **libdeflate** (1.26)
- **vcftools** (0.1.17)
- **pysam** (Python-библиотека для работы с FASTA/FASTQ/BAM/VCF)

Все специализированные программы и библиотеки установлены в отдельные подпапки внутри `/soft` с указанием версии в имени. Переменные окружения `PATH` и `LD_LIBRARY_PATH` настроены автоматически, а также созданы переменные `$SAMTOOLS`, `$BCFTOOLS`, `$VCFTOOLS` для быстрого доступа к исполняемым файлам.

Образ предназначен для воспроизводимого анализа NGS-данных и содержит Python-скрипт `convert_snp.py`, который конвертирует SNP-файл в формат REF/ALT с использованием референсного генома GRCh38.

## Начало работы

### Требования

Для работы с образом необходим установленный **Docker** (Docker Desktop для Windows/macOS или Docker Engine для Linux).

### Клонирование репозитория

Клонируйте репозиторий и перейдите в директорию с `Dockerfile`:

```bash
git clone https://github.com/YanaIvina/bioinfo-tools
cd bioinfo-tools
```

## Сборка Docker-образа

Сборка в текущей директории:

```bash
docker build -t bioinfo-tools .
```
Флаг `-t` даёт образу читаемое имя.

При необходимости можно переопределить версии инструментов с помощью `--build-arg`:

**Для Windows (PowerShell):**

```bash
docker build `
  --build-arg SAMTOOLS_VERSION=1.24 `
  --build-arg BCFTOOLS_VERSION=1.24 `
  --build-arg HTSLIB_VERSION=1.24 `
  --build-arg LIBDEFLATE_VERSION=1.25 `
  --build-arg VCFTOOLS_VERSION=0.1.17 `
  -t bioinfo-tools .
```

**Для Linux / macOS:**

```bash
docker build \
  --build-arg SAMTOOLS_VERSION=1.24 \
  --build-arg BCFTOOLS_VERSION=1.24 \
  --build-arg HTSLIB_VERSION=1.24 \
  --build-arg LIBDEFLATE_VERSION=1.25 \
  --build-arg VCFTOOLS_VERSION=0.1.17 \
  -t bioinfo-tools .
```

## Запуск Docker-образа в интерактивном режиме

Запуск контейнера в интерактивном режиме с монтированием текущей директории в `/workspace`:

**Для Windows (PowerShell):**

```bash
docker run -it --rm `
  -v "${PWD}:/workspace" `
  -v "${PWD}/ref/sepChrs:/ref/GRCh38.d1.vd1_mainChr/sepChrs" `
  bioinfo-tools
```

**Для Linux / macOS:**

```bash
docker run -it --rm \
  -v "$(pwd):/workspace" \
  -v "$(pwd)/ref/sepChrs:/ref/GRCh38.d1.vd1_mainChr/sepChrs" \
  bioinfo-tools
```

- `-it` - объединение `-i` *(interactive)* - вход в интерактивный режим и `-t` *(tty)* - выделение псевдотерминала;
- `--rm` *(remove)* - автоматическое удаление контейнера после выхода из него;
- `-v` *(volume)* — подключение тома (связывает папку на компьютере с папкой внутри контейнера)
    - `${PWD}` *(Print Working Directory)* — путь на компьютере, переменная PowerShell , которая автоматически подставляет текущий путь (вместо этой переменной можно прописать полный путь);
    - `/workspace` — путь внутри контейнера;
    - `${PWD}/ref/sepChrs:/ref/GRCh38.d1.vd1_mainChr/sepChrs` — монтирование подготовленного референса в папку.

### Проверка установки

После запуска контейнера можно проверить корректность установки:

```bash
$SAMTOOLS --version
$BCFTOOLS --version
$VCFTOOLS  --version
```

Также можно проверить, что samtools слинкован с собранными `htslib` и `libdeflate`:

```bash
ldd $SAMTOOLS | grep libhts
ldd $SAMTOOLS | grep libdeflate
```