import argparse
import sys
import os
import logging
try:
    import pysam
except ImportError:
    print("Ошибка: библиотека pysam не установлена.")
    sys.exit(1)

# логирование
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# аргументы командной строки
def parse_args():
    parser = argparse.ArgumentParser(
        description='Конвертация SNP-файла в формат REF/ALT с использованием референсного генома GRCh38.',
    )
    parser.add_argument('--input', '-i', required=True, help='Путь к входному файлу')
    parser.add_argument('--output', '-o', required=True, help='Путь к выходному файлу')
    parser.add_argument('--ref', '-r', required=True, help='Путь к папке с референсными FASTA-файлами')
    return parser.parse_args()

VALID_CHROMOSOMES = {f"chr{i}" for i in range(1, 23)} | {"chrX", "chrY", "chrM"}

def main():
    args = parse_args()
    logger.info("Запуск скрипта конвертации SNP")

    # открываем входной и выходной файлы
    if not os.path.isfile(args.input):
        logger.error(f"Входной файл {args.input} не найден")
        sys.exit(1)
    # проверка директории с референсом
    if not os.path.isdir(args.ref):
        logger.error(f"Директория с референсом не найдена: {args.ref}")
        sys.exit(1)
    try:
        fin = open(args.input, 'r', newline='')
    except IOError as e:
        logger.error(f"Ошибка открытия входного файла: {e}")
        sys.exit(1)
    try:
        fout = open(args.output, 'w', newline='')
    except IOError as e:
        logger.error(f"Ошибка открытия выходного файла: {e}")
        fin.close()
        sys.exit(1)

    with fin, fout:
        # проверка заголовка
        header = fin.readline()
        if not header:
            logger.error("Входной файл пуст.")
            sys.exit(1)
        expected = ['#CHROM', 'POS', 'ID', 'allele1', 'allele2']
        if header.strip().split('\t') != expected:
            logger.error(f"Неверный заголовок файла. Ожидалось: {expected}")
            sys.exit(1)

        # заголовок выходного файла   
        fout.write("#CHROM\tPOS\tID\tREF\tALT\n")

        fasta_cache = {}
        success, fail = 0, 0
        for n, line in enumerate(fin, start=2):
            line = line.rstrip('\r\n')
            if not line: continue

            # разбиение строк по колонкам (должно быть 5)
            cols = line.split('\t')
            if len(cols) != 5:
                logger.warning(f"Строка {n}: неверное число колонок ({len(cols)}). Пропуск.")
                fail += 1
                continue
            chromosome, position, rs_id, allele1, allele2 = cols

            # проверка имени хромосомы
            if chromosome not in VALID_CHROMOSOMES:
                logger.warning(
                    f"Строка {n}: невалидное имя хромосомы '{chromosome}'. "
                    f"Ожидается одно из: chr1..chr22, chrX, chrY, chrM. Пропуск."
                )
                fail += 1
                continue

            # проверка что аллели — одиночные нуклеотиды A/C/G/T
            valid_bases = set("ACGT")
            if len(allele1) != 1 or len(allele2) != 1:
                logger.warning(
                    f"Строка {n}: аллели должны быть длиной 1 нуклеотид, "
                    f"получено '{allele1}'/'{allele2}'. Пропуск."
                )
                fail += 1
                continue
            if allele1.upper() not in valid_bases or allele2.upper() not in valid_bases:
                logger.warning(
                    f"Строка {n}: невалидные нуклеотиды '{allele1}'/'{allele2}' "
                    f"(допустимы только A/C/G/T). Пропуск."
                )
                fail += 1
                continue

            # перевод позиции в число
            try:
                position = int(position)
            except ValueError:
                logger.warning(f"Строка {n}: неверный формат записи позиции '{position}'. Пропуск.")
                fail += 1
                continue

            # открываем каждый хромосомный файл только один раз
            if chromosome not in fasta_cache:
                fasta_path = os.path.join(args.ref, f"{chromosome}.fa")
                if os.path.isfile(fasta_path):
                    fasta_cache[chromosome] = pysam.Fastafile(fasta_path)
                    logger.info(f"Загружен референс: {fasta_path}")
                else:
                    fasta_cache[chromosome] = None
            fasta = fasta_cache[chromosome]
            if fasta is None:
                logger.warning(f"Строка {n}: отсутствует файл референса для {chromosome}. Пропуск.")
                fail += 1
                continue

            # получение основания из референса
            try:
                ref_base = fasta.fetch(chromosome, position - 1, position).upper()
            except Exception as e:
                logger.warning(f"Строка {n}: ошибка чтения референса для {chromosome}:{position} - {e}")
                fail += 1
                continue

            # Сравнение и запись результата
            if ref_base == allele1.upper():
                fout.write(f"{chromosome}\t{position}\t{rs_id}\t{allele1.upper()}\t{allele2.upper()}\n")
                success += 1
            elif ref_base == allele2.upper():
                fout.write(f"{chromosome}\t{position}\t{rs_id}\t{allele2.upper()}\t{allele1.upper()}\n")
                success += 1
            else:
                logger.warning(f"Строка {n}: в референсе ({chromosome}:{position}) стоит '{ref_base}', а аллели - '{allele1}'/'{allele2}'. Пропуск.")
                fail += 1

    for f in fasta_cache.values():
        if f is not None:
            f.close()

    logger.info(f"Готово. Успешно: {success}, Пропущено: {fail}")

if __name__ == '__main__':
    main()