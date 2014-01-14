#!/bin/bash

BUILDROOT='/tmp/pkgbuild'
PKGSTORE='/tmp/pkgr/pkgstore/deb'
SOURCESDIR='/home/pkgr/source'

. ./lib/funcs.sh

# 2 arguments required.
# TODO: add more strict parameter validation. Check for empty strings.
if [ $# -ne 2 ]; then
    die "*** invalid invocation of ${BASH_SOURCE[0]} *** \nTwo arguments are required (project name and version)\n"
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

    if [ $IS_NEW -eq 1 ]; then
        create_deb_pkg "${pkg}" "${ver}"
    else
        pkg_new_release "${pkg}" "${ver}"
    fi

    copy_build_artifacts_to_pkgstore

    clean_buildroot
fi

# vim: ts=4 sw=4 expandtab

