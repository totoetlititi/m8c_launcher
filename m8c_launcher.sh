#!/bin/bash
# from totoetlititi@free.fr 
#
# replace all "2>&1 > /dev/tty1" by "3>&1 1>&2 2>&3 3>&-" to use this script thru ssh, to display dialogs

###################################################
# CONSOLE MANAGEMENT
###################################################

sudo chmod 666 /dev/tty1
# clear the screen
printf "\033c" > /dev/tty1

# hide cursor
printf "\e[?25l" > /dev/tty1
# dialog --clear

export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

# clear the screen
printf "\033c" > /dev/tty1

# force to go back to tty1...
sudo chvt 1

sudo /opt/wifi/oga_controls $(dirname -- "$0")/m8_launcher.sh rg552 &


###################################################
# MAIN VARIABLES
###################################################

sink_default="rockchip,rk817-codec"
source_default="rockchip,rk817-codec"
m8_card_default="M8"
audioserver_default="alsa"
cpu_default="powersave"
kill_emulationstation_default="no"


# config file
config_file=$(dirname -- "$0")/config.m8.conf
pulse_config_file=$(dirname -- "$0")/config.pulse.pa
# other
sinks_list=""
sources_list=""


###################################################
# FUNCTIONS
###################################################

function kill_everything {
	echo m8c_launcher: cleaning all processes
	sudo pulseaudio -k
	sudo pkill -f pulseaudio
	sudo pkill oga_controls
	sudo pkill alsaloop
	sudo chvt 1
	# exit 0
}

function force_variables_to_default {
	sink=$sink_default
	source=$source_default
	m8_card=$m8_card_default
	audioserver=$audioserver_default
	cpu=$cpu_default
	kill_emulationstation=$kill_emulationstation_default
}


# test if M8 is connected, if not, ask to do it
function check_M8 {
	echo m8c_launcher: check_M8
	M8_is_present=0
	M8_tmp=$(aplay -l | grep -e "M8" | cut -f 1 -d \]  | cut -f 2 -d \[)
	while [[ ! "$M8_tmp" == "M8" ]] 
	do
		dialog --no-label "exit" --yes-label "ok" --yesno "Connect the M8..." 0 0 2>&1 > /dev/tty1 
		case $? in
			0) M8_tmp=$(aplay -l | grep -e "M8" | cut -f 1 -d \]  | cut -f 2 -d \[ );;
			*) 
				kill_everything
				;;
		esac
	done
}

# get the list of all sound card (outputs only) seen by alsa
function get_alsa_cards_name {
	echo m8c_launcher: get_alsa_cards_name
	mapfile -t sinks_list< <(aplay -l | grep -e "card" | cut -f 1 -d \] | cut -f 2 -d \[)
	sinks_list=( "Default" "${sinks_list[@]}" )
	mapfile -t sources_list< <(arecord -l | grep -e "card" | cut -f 1 -d \] | cut -f 2 -d \[)
}

# get first alsa card
function get_alsa_card0_name {
	echo m8c_launcher: get_alsa_card0_name
	sink=${sinks_list[0]}
}

function update_config_file {
	echo  m8c_launcher: update_config_file
	echo  sink: $sink > "$config_file"
	echo  source: $source >> "$config_file"
	echo  audioserver: $audioserver >> "$config_file"
	echo  cpu: $cpu >> "$config_file"
	echo  kill_emulationstation: $kill_emulationstation >> "$config_file"
}

# check if the config file does not exist
# if not: create the config file
# else: read file and get variables
function load_config_file {
	echo m8c_launcher: load_config_file
	if [ ! -f "$config_file" ] 
	then 
		update_config_file
	else 
		sink=$(cat "$config_file" | grep -e "sink:" | sed s/"sink: "//)
		source=$(cat "$config_file" | grep -e "source:" | sed s/"source: "//)
		audioserver=$(cat "$config_file" | grep -e "audioserver:" | sed s/"audioserver: "//)
		cpu=$(cat "$config_file" | grep -e "cpu:" | sed s/"cpu: "//)
		kill_emulationstation=$(cat "$config_file" | grep -e "kill_emulationstation:" | sed s/"kill_emulationstation: "//)
	fi
}


###################################################
# MENU
###################################################

function menu_set_audioserver {
	echo m8c_launcher: "set audioserver"	
	ask=$(dialog --no-tags --no-shadow --default-item $audioserver --menu "Choose audio server:" 10 60 0 "alsa" "alsa" "pulse" "pulse" 2>&1 > /dev/tty1) 
	case $? in
		0) 
			audioserver=$ask
			update_config_file
			;;
	esac
	menu_main
}

function menu_set_sink {
	echo m8c_launcher: "set sink"
	get_alsa_cards_name
	items=()
	sink_index=0
	for (( i=0; i<${#sinks_list[@]}; i++ )) ; do
		items+=($((i+1)) "${sinks_list[$i]}")
		if [[ "${sinks_list[$i]}" == "$sink" ]]; then 
			sink_index=$((i+1))
		fi
	done
	ask=$(dialog --no-tags --no-shadow --default-item $sink_index --menu "Choose M8 output sound card:" 10 40 0 "${items[@]}" 2>&1 > /dev/tty1) 
	case $? in
		0) 
			sink=${sinks_list[$(($ask))-1]}
			update_config_file
			;;
	esac
	menu_main
}

function menu_set_source {
	echo m8c_launcher: "set source"
	get_alsa_cards_name
	items=()
	source_index=0
	for (( i=0; i<${#sources_list[@]}; i++ )) ; do
		items+=($((i+1)) "${sources_list[$i]}")
		if [[ "${sources_list[$i]}" == "$source" ]]; then 
			source_index=$((i+1))
		fi
	done
	ask=$(dialog --no-tags --no-shadow --default-item $source_index --menu "Choose M8 input sound card:" 10 40 0 "${items[@]}" 2>&1 > /dev/tty1) 
	case $? in
		0) 
			source=${sources_list[$(($ask))-1]}
			update_config_file
			;;
	esac
	menu_main
}

function menu_set_cpu {
	echo m8c_launcher: "set cpu"
	ask=$(dialog --no-tags --no-shadow --default-item $cpu --menu "Choose CPU governor:" 10 60 0 "powersave" "powersave" "performance" "performance" 2>&1 > /dev/tty1)
	case $? in
		0) 
			cpu=$ask 
			update_config_file
			;;
	esac
	menu_main
}

function menu_reset_settings {
	echo m8c_launcher: "reset settings"
	ask=$(dialog --no-tags --no-shadow --default-item 1 --yesno "Reset settings ?" 0 0 2>&1 > /dev/tty1)
	case $? in
		0) 
			force_variables_to_default
			update_config_file
			;;
	esac
	menu_main
}

function menu_kill_emulationstation {
	echo m8c_launcher: "kill emulationstation ?"
	ask=$(dialog --no-tags --no-shadow --default-item $kill_emulationstation --menu "Kill EmulationStation:" 10 60 0 "yes" "yes" "no" "no" 2>&1 > /dev/tty1)
	case $? in
		0) 
			kill_emulationstation=$ask 
			update_config_file
			;;
	esac
	menu_main
}

function menu_main {
	echo m8c_launcher: "main menu"
	# --no-tags
	ask=$(dialog --no-shadow --cancel-label "exit" \
		--menu "m8c_launcher - current config: \n \n    * audioserver: $audioserver\n    * output: $sink\n    * input: $source\n    * cpu: $cpu \n " 22 58 6 \
		1 "run m8c" \
		2 "M8 outputs" \
		3 "M8 inputs" \
		4 "audioserver" \
		5 "CPU governor" \
		6 "reset settings" 2>&1 > /dev/tty1) # 3>&1 1>&2 2>&3 3>&-)
	case $? in
		0) 
			echo m8c_launcher: go to run_m8c
			;;
		*) 	
			echo m8c_launcher: go to kill_everything
			kill_everything 
			;;
	esac
	case $ask in
		1) run_m8c ;; 
		2) menu_set_sink ;;
		3) menu_set_source ;;
		4) menu_set_audioserver ;;
		5) menu_set_cpu ;;
		6) menu_reset_settings ;;
	esac
}



###################################################
# RUN M8C WITH SETTINGS
###################################################

function run_m8c {
	echo m8c_launcher: "run m8c"

	# cleaning the screen, to leave a black scrren when m8c process stops
	dialog --infobox " loading ...  " 3 17 2>&1 > /dev/tty1 

	echo m8c_launcher: sink: $sink 
	echo m8c_launcher: source: $source
	echo m8c_launcher: m8: $m8_card
	echo m8c_launcher: audioserver: $audioserver 
	echo m8c_launcher: cpu: $cpu 

	# m8c settings
	sed -i "/^idle_ms=/s/=.*/=25/" ~/.local/share/m8c/config.ini

	# set cpu governor to powersave to minimize audio "crackles"
	echo $cpu | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor


	##############################################
	# PULSE
	##############################################
	# if audioserver is pulse, 
	# 	run pulse 
	# 	get pulse names for sink, source & m8
	# 	make configpulse.pa file
	#	run m8c
	# 	start pulseaudio server
	if [[ "$audioserver" == "pulse" ]]; then
		echo m8c_launcher: make pulse config file

		# pulseaudio must be running to get list-sinks and list-sources
		pulseaudio --start
		sleep 2
		mapfile -t pulse_sinks_alsa< <(pacmd list-sinks | grep -e "alsa.card_name = " | cut -f2 -d \")
		mapfile -t pulse_sinks_name< <(pacmd list-sinks | grep -e "name:" | cut -f2 -d "<" | cut -f1 -d ">")
		mapfile -t pulse_sources_alsa< <(pacmd list-sources | grep -e "alsa.card_name = " | cut -f2 -d \")
		mapfile -t pulse_sources_name< <(pacmd list-sources | grep -e "name:" | cut -f2 -d "<" | cut -f1 -d ">")

		pulse_sink=""
		pulse_source=""
		pulse_source_m8=""
		pulse_sink_m8=""

		# get sink pulse name
		if [[ "$sink" == "Default" ]]; then
			pulse_sink=$( pacmd list-sinks | grep -A1 '* index'| grep -oP '(?<=name:).*' | sed 's/[<>]//g' ) # thanks chatGPT...
		else
			for (( i=0; i<${#pulse_sinks_alsa[@]}; i++ )); do
				s="${pulse_sinks_alsa[$i]}"
				if [[ "$s" == "$sink" ]]; then 
					pulse_sink=${pulse_sinks_name[$i]}
				fi
			done
		fi

		# get source pulse name
		for (( i=0; i<${#pulse_sources_alsa[@]}; i++ )); do
			s="${pulse_sources_alsa[$i]}"
			if [[ $s == "$source" ]]; then
				pulse_source=${pulse_sources_name[$i]}
			fi
		done

		# get m8 source pulse name
		for (( i=0; i<${#pulse_sources_name[@]}; i++ )); do
			s="${pulse_sources_name[$i]}"
			if [[ $s == *"M8"* ]]; then
				if [[ "$s" != *"monitor"* ]]; then 
					pulse_source_m8=$s
				fi
			fi
		done

		# get m8 sinks pulse name
		for (( i=0; i<${#pulse_sinks_name[@]}; i++ )); do
			s="${pulse_sinks_name[$i]}"
			if [[ $s == *"M8"* ]]; then
				pulse_sink_m8=$s
			fi
		done

		echo m8c_launcher: pulse_sink "$pulse_sink"
		echo m8c_launcher: pulse_source "$pulse_source"
		echo m8c_launcher: pulse_source_m8 "$pulse_source_m8"
		echo m8c_launcher: pulse_sink_m8 "$pulse_sink_m8"

		# make config.pulse.pa
		echo load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 > "$pulse_config_file"
		echo set-default-source "$pulse_source" >> "$pulse_config_file"
		echo set-default-sink "$pulse_sink" >> "$pulse_config_file"
		echo load-module module-loopback source="$pulse_source_m8" sink="$pulse_sink" >> "$pulse_config_file"
		echo load-module module-loopback source="$pulse_source" sink="$pulse_sink_m8" >> "$pulse_config_file"

		# kills pulseaudio
		pulseaudio -k

		# start pulse
		pulseaudio --start --file="$pulse_config_file"
		# start m8c
		$(dirname -- "$0")/_m8c/m8c &

		# if m8c process stops, kill everything
		# if pulseaudio crash while m8c is running, restart pulseaudio
		while :
		do 
			m8c_process=$(ps aux|grep [m]8c)
			if [ -z "$m8c_process" ] 
			then
				# kill_everything
				break
			fi
			# check if pulse is alive, restart 
			pulse_process=$(ps aux|grep [p]ulseaudio)
			if [ -z "$pulse_process" ] 
			then
				pulseaudio --start --file="$pulse_config_file"
				echo m8c_launcher: ... restarting pulse ...
			fi
			sleep 1
		done
	fi

	##############################################
	# ALSA
	##############################################
	# if audioserver is alsa, 
	# 	get alsa names for sink, source & m8
	#	run m8c
	# 	start alsa server
	if [[ "$audioserver" == "alsa" ]]; then
		alsa_sink=""
		alsa_source=""
		alsa_m8_card=""
		if [[ "$sink" == "Default" ]]; then
			alsa_sink="default"
		else
			alsa_sink_index=$(aplay -l | grep -e "$sink" | cut -d":" -f1 | cut -d' ' -f2)
			alsa_sink=plughw:$(($alsa_sink_index)),0
		fi
		alsa_source_index=$(arecord -l | grep -e "$source" | cut -d":" -f1 | cut -d' ' -f2)
		alsa_source=plughw:$(($alsa_source_index)),0
		alsa_m8_card_index=$(arecord -l | grep -e "$m8_card" | cut -d":" -f1 | cut -d' ' -f2)
		alsa_m8_card=hw:$(($alsa_m8_card_index)),0

		echo m8c_launcher: alsa_source $alsa_source
		echo m8c_launcher: alsa_sink $alsa_sink
		echo m8c_launcher: alsa_m8_card $alsa_m8_card

   		alsaloop -C $alsa_m8_card -P $alsa_sink  -t 200000 -A 5 --rate 44100 --sync=0 -T -1 -d
   		alsaloop -C $alsa_source -P $alsa_m8_card  -t 200000 -A 5 --rate 44100 --sync=0 -T -1 -d

		# start m8c
		$(dirname -- "$0")/_m8c/m8c &

		# if m8c process stops, kill everything
		# if alsaloop while and m8c is running, restart alsaloop
		while :
		do 
			m8c_process=$(ps aux|grep [m]8c)
			if [ -z "$m8c_process" ] 
			then
				# kill_everything
				break
			fi
			# check if 2 processes of alsaloop are alive
			alsa_process=$(ps -ef | grep alsaloop | grep -v grep | wc -l) # thanks chatGPT...
			if [[ $alsa_process < 2 ]] 
			then
				alsaloop -C $alsa_m8_card -P $alsa_sink  -t 200000 -A 5 --rate 44100 --sync=0 -T -1 -d
				alsaloop -C $alsa_source -P $alsa_m8_card  -t 200000 -A 5 --rate 44100 --sync=0 -T -1 -d
				echo m8c_launcher: ... restarting alsa ...
			fi
			sleep 1
		done
	fi
}


###################################################
# MAIN
###################################################

force_variables_to_default
check_M8
get_alsa_cards_name
get_alsa_card0_name
load_config_file
menu_main
kill_everything


