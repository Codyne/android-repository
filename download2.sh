#!/bin/bash

basedir=$(dirname "$0")

DL_HOST=${DL_HOST:-https://dl.google.com}
DL_PATH=android/repository

echo synchronizing indices

# TODO auto detect latest version, e.g. 2-1 and 3
# How to discover these files?
# Option 1, proxy and logging
# Option 2, ????
sites=("repository")
sites+=("repository-10")
sites+=("repository-11")
sites+=("repository-12")
sites+=("repository2-1")
sites+=("repository2-2")
sites+=("repository2-3")

addon_sites=("addon")
addon_sites=("addon-6")
addon_sites=("addons_list-1")
addon_sites+=("addons_list-2")
addon_sites+=("addons_list-3")
addon_sites+=("addons_list-4")
addon_sites+=("addons_list-5")
addon_sites+=("addons_list-6")

for addon_site in "${addon_sites[@]}"; do
    wget -N "${DL_HOST}/${DL_PATH}/${addon_site}.xml" -P ${DL_PATH}

    while read -r addon_site; do
	    sites+=("${addon_site}")
    done <<< "$(perl -nle 'print $& if m{(?<=<url>).*(?=</url>)}' ${DL_PATH}/${addon_site}.xml | sed s/.xml//g)"
done

for site in "${sites[@]}"; do
	sub_path=$(echo "${site}" | perl -nle 'print $& if m{.*/|}')
	wget -N "${DL_HOST}/${DL_PATH}/${site}.xml" -P "${DL_PATH}/${sub_path}"
done

echo downloading packages

for site in "${sites[@]}"; do
	echo "${site}"
	sub_path=$(echo "${site}" | perl -nle 'print $& if m{.*/|}')
	perl -nle 'print $& if m{(?<=<url>).*(?=</url>)}' "${DL_PATH}/${site}.xml" | sed "s~^~${DL_HOST}/${DL_PATH}/${sub_path}~g" | wget -N -P "${DL_PATH}/${sub_path}" -c -i -
done

echo removing obsolete files

for addon_site in "${addon_sites[@]}"; do
    echo ${DL_PATH}/${addon_site}.xml > ${DL_PATH}/downloaded
done

for site in "${sites[@]}"; do
	sub_path=$(echo "${site}" | perl -nle 'print $& if m{.*/|}')
	echo "${DL_PATH}/${site}.xml" >> ${DL_PATH}/downloaded
	perl -nle 'print $& if m{(?<=<url>).*(?=</url>)}' "${DL_PATH}/${site}.xml" | sed "s~^~${DL_PATH}/${sub_path}~g" >> ${DL_PATH}/downloaded
done

downloaded=$(cat ${DL_PATH}/downloaded)
while read -r file; do
	if ! echo "${downloaded}" | grep -q "${file}"; then
		echo "${file}"
		rm "${file}"
	fi
done <<< "$(find ${DL_PATH} -type f -not -path ${DL_PATH}/downloaded)"

echo
echo Apache httpd
echo 'include the following lines in your apache httpd.conf file (or a file included by it, e.g. httpd-vhosts.conf)'
sed -e "s~\${dir}~'$(pwd)'~g" "${basedir}/apache2.conf"

echo
echo nginx
echo 'include the following lines in your nginx.conf file'
sed -e "s~\${dir}~'$(pwd)'~g" "${basedir}/nginx.conf"

echo
echo How to setup client to use your mirror?
echo "export SDK_TEST_BASE_URL=http://your-mirror/${DL_PATH}/"
echo "open -a 'Android Studio'"
