#!/bin/bash

# See https://github.com/kosua20/MIDIVisualizer

set -e

MIDIVISUALIZER="/home/russell/DevOps/3rdParty/github/MIDIVisualizer/build/MIDIVisualizer"

src="${1}"
shift 
[ -z "$src" ] && printf "ERROR: no input file given\n" && exit 1
[ ! -e "$src" ] && printf "ERROR: can't find input file '${src}'\n" && exit 1

preroll=3

base="${src%\.*}"
src_ly="${base}.ly"
src_midi="${base}.midi"
vf="${base}.mp4"
vf2="${base}_2.mp4"
af="${base}.flac"
af2="${base}_2.flac"


function gen_midi() {
	printf "DEBUG: gen_midi()\n"

	rm -f "${src_midi}"
	lilypond ${src_ly} # &>/dev/null
}

function gen_vid() {
	printf "DEBUG: gen_vid()\n"

	rm -f "${vf}"
	opts="--midi ${src_midi}"
	opts="$opts --export ${vf}"
	opts="$opts --format MPEG4"
	opts="$opts --framerate 30"
	opts="$opts --bitrate 1"
	opts="$opts --hide-window 1"
	opts="$opts --color-bg 0 0 0"
	opts="$opts --flashes-size 0.1" 
	opts="$opts --particles-count 1"
	opts="$opts --preroll ${preroll}"

	${MIDIVISUALIZER} ${opts} #| grep -v "[INFO]" # &>/dev/null
}

function gen_aud(){
	printf "DEBUG: gen_aud()\n"

	rm -f "${af}" "${af2}"
	timidity "${src_midi}" --volume=150 -Ow -o "${af}" &>/dev/null

	# Calculate the intro delay
	delay=0
	if [[ $tempo -ne 0 && $intro_rest_count -ne 0 ]]; then
		# from tempo, intro rest count, and preroll
		delay=$(echo "scale=4; (${intro_rest_count}/${tempo} * 60000) + (${preroll} * 1000) - 100" | bc)
	else
		# from the preroll alone
		delay=$[ ${preroll} * 1000 - 100 ]
	fi 

	echo "DEBUG: delay: ${delay}"

	if (( $(echo "${delay} > 0.0" | bc -l)  )); then 
		ffmpeg -i "${af}" -af "adelay=${delay}ms:all=true" "${af2}" &>/dev/null
		rm -f "${af}"
		mv "${af2}" "${af}"
	fi
}

function combine(){
	printf "DEBUG: combine()\n"

	rm -f "${vf2}"
	ffmpeg -i "${vf}" -i "${af}" -c copy -map 0:v:0 -map 1:a:0 "${vf2}" #&>/dev/null
	rm -f "${vf}" 
	mv "${vf2}" "${vf}"
}

function cleanup(){
	printf "DEBUG: cleanup()\n"

	rm -f "${af}" "${af2}" "${vf2}"
}

function play() {
	printf "DEBUG: play()\n"

	vlc "$vf" #&>/dev/null & 
}

tempo=0
intro_rest_count=0

# Perform tasks
first=1
while [[ ! -z "${1}" || $first -eq 1 ]]; do
	case $1 in
	    --tempo)
			printf "DEBUG: case '--tempo' ($1 $2)\n"
			tempo=${2}
			shift; shift
			;;
		--intro-rest-count)
			printf "DEBUG: case '--intro-rest-count' ($1 $2)\n"
			intro_rest_count=${2}
			shift; shift 
			;;
		--preroll)
			printf "DEBUG: case '--preroll' ($1 $2)\n"
			if [ ! -z ${2} ]; then
				preroll="${2}"
			fi
			printf "DEBUG: preroll:${preroll}\n"
			shift; shift
			;;
		midi)
			printf "DEBUG: case 'midi' ($1)\n"
			gen_midi
			first=0
			shift 
			;;
		video)
			printf "DEBUG: case 'video' ($1)\n"
			gen_vid
			first=0
			shift 
			;;
		audio)
			printf "DEBUG: case 'audio' ($1)\n"
			gen_aud
			first=0
			shift 
			;;
		combine)
			printf "DEBUG: case 'combine' ($1)\n"
			combine
			first=0
			shift 
			;;
		cleanup)
			printf "DEBUG: case 'cleanup' ($1)\n"
			cleanup
			first=0
			shift 
			;;
		play)
			printf "DEBUG: case 'play' ($1)\n"
			play
			first=0
			shift 
			;;
		*)
			printf "DEBUG: case '*' ($1)\n"
			gen_midi
			gen_vid
			gen_aud
			combine
			cleanup
			play  
			first=0
			;;
	esac
done 

exit 0