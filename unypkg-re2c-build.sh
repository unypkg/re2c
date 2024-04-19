#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

apt install -y python3 pip

wget -qO- uny.nu/pkg | bash -s buildsys
mkdir /uny/tmp

### Installing build dependencies
unyp install python openssl

### Install Python Dependencies
python3 -m pip install --upgrade pip
python3 -m pip install docutils pygments

pip3_bin=(/uny/pkg/python/*/bin/pip3)
"${pip3_bin[0]}" install --upgrade pip
"${pip3_bin[0]}" install docutils pygments

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
pkggit="https://github.com/skvadrik/re2c.git refs/tags/*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "[0-9.]*$" | tail --lines=1)"
latest_ver="$(echo "$latest_head" | grep -o "/[0-9.].*" | sed "s|/||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

check_for_repo_and_create
git_clone_source_repo

cd re2c || exit
./autogen.sh
cd /uny/sources || exit

version_details
archiving_source

rm -rf /uny/pkg/linux-api-headers

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/build/functions
pkgname="re2c"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths_temp

####################################################
### Start of individual build script

#unset LD_RUN_PATH

### Minimal build needed for full build
./configure \
    --disable-golang \
    --disable-rust \
    --prefix="$PWD"/install

make -j"$(nproc)"
make -j"$(nproc)" install
make -j"$(nproc)" distclean
./install/bin/re2c --version

### Full build
./configure \
    --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --enable-libs \
    --enable-parsers \
    --enable-lexers \
    --enable-docs \
    --enable-debug \
    RE2C_FOR_BUILD="$PWD"/install/bin/re2c

# shellcheck disable=SC2038
find "$PWD"/src -name '*.re' | xargs touch
make -j"$(nproc)"
bash -c "ulimit -s 256; make check -j$(nproc)"
python run_tests.py --skeleton
make -j"$(nproc)" install

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
