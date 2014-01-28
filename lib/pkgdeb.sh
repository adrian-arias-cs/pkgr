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
    if [[ "${ver}" =~ ^(v)?([0-9]){1,2}\.([0-9]){1,2}\.([0-9]){1,3}-rc([0-9]){1,2}$ ]]; then
        version=`echo "${ver}" | awk -F'-' '{print $1}'`
        # if the version string begins with a lower-case 'v'
        if [ `echo ${version:0:1}` = 'v' ]; then
            # set version to remainder of string after position 1 (drop the v)
            version=`echo ${version:1}`
        fi
        rc=`echo "${ver}" | awk -F'-' '{print $2}'`
        build_dir="${BUILDROOT}/${pkg}-${version}~${rc}"
    else
        version="${ver}"
        # if the version string begins with a lower-case 'v'
        if [ `echo ${version:0:1}` = 'v' ]; then
            # set version to remainder of string after position 1 (drop the v)
            version=`echo ${version:1}`
        fi
        build_dir="${BUILDROOT}/${pkg}-${version}"
    fi
    
    
    if [ ! -d "${build_dir}" ]; then
        mkdir ${build_dir}
    else
        rm -rf ${build_dir}/*
    fi

    pkgsrcdir="${SOURCESDIR}/${pkg}"

    if [ ! -d "${pkgsrcdir}" ]; then
        clean_buildroot
        die "*** Either the specified project or it's source directory doesn't exist. ***"
    fi

    pushd "${pkgsrcdir}" > /dev/null

    if [ $IS_NEW -eq 1 ]; then
        create_deb_pkg "${pkg}" "${ver}"
    else
        pkg_new_release "${pkg}" "${ver}"
    fi
 
    popd > /dev/null

    copy_build_artifacts_to_pkgstore

    clean_buildroot
fi

# vim: ts=4 sw=4 expandtab

