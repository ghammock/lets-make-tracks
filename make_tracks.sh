#!/usr/bin/env bash
#
# Copyright (c) 2021, Gary Hammock
# SPDX-FileCopyrightText: 2021 Gary Hammock
# SPDX-License-Identifier: MIT
#
# Exit Codes:
#   0 - Everything successful
#   1 - Missing required dependencies (youtube-dl, ffmpeg, jq)
#   2 - Missing arguments / show help
#   3 - youtube-dl can't download from URL
#   4 - Cannot read info.json file
#   5 - ffmpeg failed to convert file

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

RED="\e[1;31m"
GREEN="\e[1;32m"
CYAN="\e[36m"
RESET="\e[0m"
BOLD="\e[1;4;37m"

USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:90.0) Gecko/20100101 Firefox/90.0"

url=""
make_flacs=1
make_mp3s=1

help () {
    echo ""
    echo "Usage:"
    echo "  $0 [option] URL"
    echo ""
    echo "Options:"
    echo "  --no-mp3        Don't create an MP3 directory or any MP3 files"
    echo "  --no-flac       Don't create a FLAC directory or any FLAC files"
    echo ""
    echo "You can't pass BOTH --no-mp3 and --no-flac (what's the point?)"
}

is_valid_youtube_url () {
    youtube_regex="^http[s]?:\/\/(www\.)?youtube\.[^\/]+\/watch\?v\=.+$"

    if [[ "${url}" =~ ${youtube_regex} ]]; then
        echo 1
    else
        echo 0
    fi
}

make_output_directories () {
    # Create the file output directories
    output_dir=${HOME}/Music/${title}
    if [[ ${make_flacs} -eq 1 ]]; then
        mkdir -p ${output_dir}/FLAC
    fi

    if [[ ${make_mp3s} -eq 1 ]]; then
        mkdir -p ${output_dir}/MP3
    fi
}

# Check that you have everything you need.
REQUIREMENTS=(youtube-dl ffmpeg jq)

requirements_missing=0
for prereq in ${REQUIREMENTS[@]}; do
    if [[ $(command -v ${prereq} &> /dev/null; echo $?) -ne 0 ]]; then
        requirements_missing = 1
        break
    fi
done

if [[ requirements_missing -eq 1 ]]; then
    echo -e "${BOLD}Missing required dependencies${RESET}"
    echo "This script requires:"
    echo "  youtube-dl (https://ytdl-org.github.io/youtube-dl/download.html),"
    echo "  ffmpeg (https://www.ffmpeg.org/download.html), and"
    echo "  jq (https://stedolan.github.io/jq/download/)"
    echo ""
    exit 1
fi

if [[ "$#" -eq 0 ]]; then
    echo -e "${RED}You have to pass a URL${RESET}"
    help
    exit 2
elif [[ "$#" -gt 2 ]]; then
    echo -e "${RED}Invalid number of arguments${RESET}"
    help
    exit 2
fi

while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
        --no-mp3)
            make_mp3s=0
        ;;

        --no-flac)
            make_flacs=0
        ;;

        *)
            url=${key}
            if [[ $(is_valid_youtube_url) -eq 0 ]]; then
                echo -e "${RED}Tried to parse ${url}${RESET}"
                echo -e "${RED}That doesn't look like a valid YouTube URL${RESET}"
                help
                exit 3
            fi
        ;;
    esac
    shift
done

default_output_name="$(youtube-dl \
    --get-filename            \
    --ignore-config           \
    --audio-format best       \
    --user-agent "${USER_AGENT}" \
    --referer "https://www.youtube.com/" \
    --format 'bestaudio/best' \
    "${url}" 2> /dev/null)"

if [[ ${default_output_name} == "" ]]; then
    echo -e "${RED}youtube-dl can't get download the metadata at the URL${RESET}"
    exit 3
fi

extension="${default_output_name##*.}"

tempfile="/tmp/make_tracks_$(date +%Y%m%d_%H%M%S).$$.${extension}"
echo "Downloading to ${tempfile}"
youtube-dl                    \
    --ignore-config           \
    --user-agent "${USER_AGENT}" \
    --referer "https://www.youtube.com/" \
    --write-info-json         \
    --format 'bestaudio/best' \
    --output "${tempfile}"      \
    "${url}" \
|| (echo -e "${RED}Error encountered while downloading ${url}.${RESET}"; exit 3)

json_file="${tempfile%.*}.info.json"
echo "Reading info file: ${json_file}"

if [[ ! -r ${json_file} ]]; then
    echo -e "${RED}Cannot find the requested file.${RESET} \U1f4a3"
    exit 4
fi

title=$(cat "${json_file}" | jq -r '.title' | sed -e 's/[^A-Za-z0-9._-]/_/g')
upload_date=$(jq -r '.upload_date' ${json_file} | cut -c -4)

thumbnail_url="$(jq -r '.thumbnail' ${json_file})"
thumbnail_ext="${thumbnail_url##*.}"
thumbnail_image_file="${tempfile%.*}.thumbnail.${thumbnail_ext}"

curl -fsSL -o "${thumbnail_image_file}" \
        --user-agent "${USER_AGENT}"    \
        --referer "${url}"              \
        "${thumbnail_url}"

if [[ (${thumbnail_ext} == "webp") && $(command -v dwebp &> /dev/null; echo $?) -eq 0 ]]; then
    dwebp "${tempfile%.*}.thumbnail.webp" -o "${tempfile%.*}.png"
    thumbnail_image_file="${thumbnail_image_file%.*}.png"
fi

make_output_directories

num_tracks=$(cat "${json_file}" | jq '.chapters | length')

for ((i = 0 ; i < ${num_tracks} ; i++)); do
    track_data=$(jq ".chapters[${i}] += {track: $((i + 1))} | .chapters[${i}]" "${json_file}")

    start_time=$(echo ${track_data} | jq -r '.start_time')
    duration=$(echo ${track_data} | jq -r '.end_time-.start_time')
    track_number=$(echo ${track_data} | jq -r '.track')
    track_title=$(echo ${track_data} | jq -r '.title')

    # Remove non-ASCII alphanumeric characters and set spaces to underscore.
    safe_track_title=$(echo ${track_title} | sed -e 's/[^A-Za-z0-9._-]//g' | sed -e 's/\s+/_/g')

    echo -en "\U1f3b6 Converting track ${track_number}"

    if [[ ${make_flacs} -eq 1 ]]; then
        ffmpeg -v quiet -y                                  \
            -i "${tempfile}"                                \
            -i "${thumbnail_image_file}"                    \
            -map 0:0                                        \
            -map 1:0                                        \
            -ss ${start_time}                               \
            -to ${duration}                                 \
            -f flac                                         \
            -codec:v copy                                   \
            -metadata title="${track_title}"                \
            -metadata album="${title}"                      \
            -metadata track="${track_number}/${num_tracks}" \
            -metadata date="${upload_date}"                 \
            -metadata publisher="YouTube"                   \
            -metadata description="${url}"                  \
            -metadata:s:v title="Album cover"               \
            -metadata:s:v comment="Cover (front)"           \
            -disposition:v attached_pic                     \
            "${output_dir}/FLAC/${track_number}-${safe_track_title}.flac" \
        && echo -en " - ${GREEN}FLAC SUCCESS! \u2714${RESET}" \
        || echo -en " - ${RED}FAILED! \u2718${RESET}"
    fi

    if [[ ${make_mp3s} -eq 1 ]]; then
        ffmpeg -v quiet -y                                  \
            -i "${tempfile}"                                \
            -i "${thumbnail_image_file}"                    \
            -map 0:0                                        \
            -map 1:0                                        \
            -ss ${start_time}                               \
            -to ${duration}                                 \
            -ac 2                                           \
            -acodec libmp3lame                              \
            -q:a 0                                          \
            -codec:v copy                                   \
            -id3v2_version 3                                \
            -write_id3v1 1                                  \
            -metadata title="${track_title}"                \
            -metadata album="${title}"                      \
            -metadata track="${track_number}/${num_tracks}" \
            -metadata date="${upload_date}"                 \
            -metadata publisher="YouTube"                   \
            -metadata description="${url}"                  \
            -metadata comment="${url}"                      \
            -metadata:s:v title="Album cover"               \
            -metadata:s:v comment="Cover (front)"           \
            "${output_dir}/MP3/${track_number}-${safe_track_title}.mp3" \
        && echo -en " - ${GREEN}MP3 SUCCESS! \u2714${RESET}" \
        || echo -en " - ${RED}FAILED! \u2718${RESET}"
    fi

    echo ""
done

echo "Cleaning up..."
rm -f ${tempfile%.*}*

echo ""
echo -e "${GREEN}All tracks successfully converted.${RESET} \U1f91f \u2728"

exit 0
