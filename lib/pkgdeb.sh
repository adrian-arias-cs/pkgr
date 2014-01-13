#!/bin/bash

BUILDROOT='/tmp/pkgbuild'
PKGSTORE='/home/pkgr/pkgstore'
SOURCESDIR='/home/pkgr/source'

[[ -n $DEBUG ]] && DEBUG=$DEBUG || DEBUG=0

. ./lib/funcs.sh

print_usage()
{
    echo -e "`basename $0`: Incorrect usage"
    echo -e "`basename $0` <project name> <branch or tag>"
}

die()
{
    local frame=0

    echo "$*"

    if [ -n ${DEBUG} ] && [ ${DEBUG} -eq 1 ]; then
        while caller $frame; do
            ((frame++))
        done
    fi

    exit 1
}

# 2 arguments required.
# TODO: add more strice parameter validation. Check for empty strings.
if [ $# -ne 2 ]; then
    print_usage
else
    pkg=$1
    ver=$2

    if [ ! -d "${BUILDROOT}" ]; then
        mkdir "${BUILDROOT}"
    fi

    # check for rc version
    if [[ "${ver}" =~ ^([0-9]){1,2}\.([0-9]){1,2}\.([0-9]){1,3}-rc([0-9]){1,2}$ ]]; then
        version=`echo "${ver}" | awk -F'-' '{print $1}'`
        rc=`echo "${ver}" | awk -F'-' '{print $2}'`
        build_dir="${BUILDROOT}/${pkg}-${version}~${rc}"
    else
        version="${ver}"
        build_dir="${BUILDROOT}/${pkg}-${version}"
    fi
    
    if [ ! -d "${build_dir}" ]; then
        mkdir ${build_dir}
    else
        rm -rf ${build_dir}/*
    fi

#    create_deb_pkg "${pkg}" "${ver}"

    pkg_new_release "${pkg}" "${ver}"

    copy_build_artifacts_to_pkgstore

    clean_buildroot
fi

# vim: ts=4 sw=4 expandtab
