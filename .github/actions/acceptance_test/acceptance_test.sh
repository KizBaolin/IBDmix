#!/bin/bash

set -euo pipefail
# set -x

test_type=$1

ibdmix="src/ibdmix"
generate_gt="src/generate_gt"
# to work for local tests
if [[ ! -f $ibdmix ]]; then
    ibdmix="../../../build/src/ibdmix"
    generate_gt="../../../build/src/generate_gt"
fi

echo "starting $test_type"

url_base="http://tigress-web.princeton.edu/~tcomi/ibdmix_tests"


read_result() {
    wget -qO - $1 | zcat
}

run_genotype() {
    $generate_gt \
        -a <(wget -qO - $1 | zcat) \
        -m <(wget -qO - $2 | zcat) \
        -o -
}

run_ibd_pop() {
    $ibdmix \
        -g <(wget -qO - $1 | zcat) \
        -s <(wget -qO - $2) \
        -r <(wget -qO - $3) \
        --LOD-threshold 3.0 \
        --minor-allele-count-threshold 1 \
        --archaic-error 0.01 \
        --modern-error-max 0.002 \
        --modern-error-proportion 2 \
        --output >( tail -n +2 )
    # the tail removes the header, which was absent in reference for these
}

run_ibd_all_mask() {
    $ibdmix \
        -g <(wget -qO - $1 | zcat) \
        -r <(wget -qO - $2) \
        --output >( tail -n +2 )
    # the tail removes the header, which was absent in reference for these
}

run_ibd_all_no_mask() {
    $ibdmix \
        -g <(wget -qO - $1 | zcat) \
        --output >( tail -n +2 )
    # the tail removes the header, which was absent in reference for these
}

run_ibd_extra() {
    $ibdmix \
        -g <(wget -qO - $1 | zcat) \
        -s <(wget -qO - "$url_base/cell_data/samples/GWD.txt") \
        $2 \
        --output >( cat )
}

if [[ $test_type == "gen_20" ]]; then
    resultfile="$url_base/cell_data/outputs/genotype/altai_1kg_20.gz"
    mod="$url_base/cell_data/mod_chr20.vcf.gz"
    arch="$url_base/cell_data/altai_chr20.vcf.gz"

    cmp \
        <(read_result $resultfile) \
        <(run_genotype $arch $mod)

elif [[ $test_type == "populations" ]]; then
    for pop in ACB ASW BEB CDX CEU CHB CHS CLM ESN FIN GBR GIH GWD \
        IBS ITU JPT KHV LWK MSL MXL PEL PJL PUR STU TSI YRI ; do
        echo $pop
        resultfile="$url_base/cell_data/outputs/ibd_raw/altai_1kg_${pop}_20.gz"

        genotype="$url_base/cell_data/outputs/genotype/altai_1kg_20.gz"
        sample="$url_base/cell_data/samples/${pop}.txt"
        mask="$url_base/cell_data/masks/chr20.bed"

        cmp \
            <(read_result "$resultfile") \
            <(run_ibd_pop $genotype $sample $mask)
    done

elif [[ $test_type == "all_mask" ]]; then
    resultfile="$url_base/cell_data/outputs/ibd_raw/all_with_mask.gz"

    genotype="$url_base/cell_data/outputs/genotype/altai_1kg_20.gz"
    mask="$url_base/cell_data/masks/chr20.bed"

    cmp \
        <(read_result "$resultfile") \
        <(run_ibd_all_mask $genotype $mask)

elif [[ $test_type == "all_no_mask" ]]; then
    resultfile="$url_base/cell_data/outputs/ibd_raw/all_no_mask.gz"

    genotype="$url_base/cell_data/outputs/genotype/altai_1kg_20.gz"

    cmp \
        <(read_result "$resultfile") \
        <(run_ibd_all_no_mask $genotype)

elif [[ $test_type == "extra" ]]; then
    genotype="$url_base/cell_data/outputs/genotype/altai_1kg_20.gz"

    resultfile="$url_base/cell_data/outputs/ibd_raw/GWD_20_inclusive.gz"

    echo "inclusive end"
    cmp \
        <(read_result "$resultfile") \
        <(run_ibd_extra $genotype "--inclusive-end")

    resultfile="$url_base/cell_data/outputs/ibd_raw/GWD_20_stats.gz"

    echo "more stats"
    cmp \
        <(read_result "$resultfile") \
        <(run_ibd_extra $genotype "--more-stats")

    resultfile="$url_base/terminal_tab/genotype.out.gz"
    mod="$url_base/terminal_tab/mod_chr22.vcf.gz"
    arch="$url_base/terminal_tab/AltNea_n10000.vcf.gz"

    echo "with tab"
    cmp \
        <(read_result $resultfile) \
        <(run_genotype $arch $mod)

else
    echo "Unknown test type $test_type"
    exit 1
fi

echo "passed $test_type"
