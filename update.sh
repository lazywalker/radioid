#!/usr/bin/env bash

#
# Copyright 2020 Michael BD7MQB <bd7mqb@qq.com>
# This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 3.0
#
# TODO: This is a shell version to be finished
# To use MAP in macOS, `brew install bash` first
#

DMRIDS=./download/DMRIds.dat
DMRIDS_TMP=./download/DMRIds.dat.tmp
COUNTRY_CODE=./CountryCode.txt

declare -A MAP=()

curl 'https://database.radioid.net/static/user.csv' 2>/dev/null | awk -F ',' '{print $1"\t"$2"\t"$3"\t"$4"\t"$6}' > ${DMRIDS}

rm -f ${DMRIDS_TMP}

while read line
do
    COUNTRY=`echo "${line}" | awk -F "\t" '{print $2}' | tr -d "[:space:]()'"`
    CODE=`echo "${line}" | awk -F "\t" '{print $1}'`
    MAP[${COUNTRY}]=${CODE}
done < ${COUNTRY_CODE}

# MAP["United_States"]=US
# echo ${MAP["UnitedStates"]}  

# for key in ${!MAP[@]}  
# do
#     echo ${MAP[$key]}  
# done  

while read line
do
    COUNTRY=`echo "${line}" | awk -F "\t" '{print $5}' | tr -d "[:space:]()'"`
    # CODE=`grep -w "${COUNTRY}$" CountryCode.txt | awk -F "\t" '{print $1}'`
    CODE=${MAP[$COUNTRY]}
    # echo "${COUNTRY} -- ${CODE}"

    echo -e "${line}\t${CODE}" | awk -F "\t" '{print $1"\t"$2"\t"$3"\t"$4"\t"$6}' >> ${DMRIDS_TMP}

done < ${DMRIDS}

gzip -f -k ${DMRIDS}
