#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

#apt install -y

wget -qO- uny.nu/pkg | bash -s buildsys
mkdir /uny/tmp

### Installing build dependencies
unyp install python

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/uny/build/github_conf
source /uny/uny/build/download_functions
source /uny/git/unypkg/fn

######################################################################################################################
### Timestamp & Download

uny_build_date_seconds_now="$(date +%s)"
uny_build_date_now="$(date -d @"$uny_build_date_seconds_now" +"%Y-%m-%dT%H.%M.%SZ")"

mkdir -pv /uny/sources
cd /uny/sources || exit

pkgname="re2c"
pkggit="https://github.com/php/php-src.git refs/tags/php-7.4*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "php-7.4[0-9.]*$" | tail --lines=1)"
latest_ver="$(echo "$latest_head" | grep -o "php-[0-9.]*" | sed "s|php-||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

check_for_repo_and_create
git_clone_source_repo

cd php-src || exit

autoreconf -i -W all

cd /uny/sources || exit

version_details
archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/build/functions
pkgname="php"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths_temp

####################################################
### Start of individual build script

unset LD_RUN_PATH

./configure \
    --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --with-openssl \
    --enable-fpm \
    --disable-cgi \
    --disable-phpdbg \
    --enable-sockets \
    --without-sqlite3 \
    --without-pdo-sqlite \
    --with-mysqli \
    --with-pdo-mysql \
    --enable-ctype \
    --with-curl \
    --enable-exif \
    --enable-mbstring \
    --with-zip \
    --with-bz2 \
    --enable-bcmath \
    --with-jpeg \
    --with-webp \
    --enable-intl \
    --enable-pcntl \
    --with-ldap \
    --with-gmp \
    --with-password-argon2 \
    --with-sodium \
    --with-zlib \
    --with-freetype \
    --enable-soap \
    --enable-gd \
    --with-imagick \
    --enable-redis=shared

make -j"$(nproc)"

make install

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
