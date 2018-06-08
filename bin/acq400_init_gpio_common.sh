
# acq400_init_gpio_common : function lib for acqXXXX_init_gpio

export_gpio() {
	echo $1 > export
}

getchip() {
	addr=$1
	ls -l gpiochip* | grep $addr | awk '{ print $9 }'
	# force exit code ..
	ls -l gpiochip* | grep -q $addr
}

setHI() {
	echo 1 > $1
}

setLO() {
	echo 0 > $1
}

setO() {
	echo out >$1/direction
}
setAL() {
	echo 1 >$1/active_low
	if [ "$(cat $1/direction)" = "out" ]; then
		echo 0 >$1/value
	fi
}
mkln() {
	gpn=$1
	ln -s $PWD/$gpn/value /dev/gpio/$2
	shift;shift;
	while [ "x$1" != "x" ]; do
		case $1 in
		AL)
			setAL $gpn;;
		IN)
			echo in > $gpn/direction;;
		OUT)
			echo out > $gpn/direction;;
		esac
		shift
	done
}
mklnrm() {
	rm -f /dev/gpio/$2
	mkln $*	
}

lnAL() {
	setAL $1;ln -s $1/value $2	
}

lnALO() {
	setAL $1; echo 0 >$1/value; ln -s $1/value $2	
}

lnAH() {
	ln -s $1/value $2	
}


i2c_reset() {
	setHI /dev/gpio/I2C_RESET
	sleep 0.1
	setLO /dev/gpio/I2C_RESET
	echo +++ I2C_RESET done
}

common_begin() {
	echo ++ acq400_init_gpio_common begin

	mkdir -p /dev/gpio
	cd /sys/class/gpio

# Zynq GPIO
	export_gpio  0; setO gpio0
	mkln gpio0 LED_ACT
	nice daemon /usr/local/bin/heartbeat


# I2C_RESET : use with care, will confuse the ps7 i2c driver
	export_gpio 9; setO gpio9
	mkln gpio9 I2C_RESET	AL

	export_gpio 47;	
	mkln gpio47 EXT_WP AL
}


clear_leds() {	
	for LED in /dev/gpio/LED/*
	do
		setLO $LED
	done
}
	
test_leds() {
	for LED in /dev/gpio/LED/*
	do
		setHI $LED
		sleep 0.2
		setLO $LED
	done
}

	
gpioLED() {
	let lgp=$1+$2
	echo gpio$lgp
}


common_end() {
	echo ++ acq400_init_gpio_common end 01		
	clear_leds
	echo "++ lamp test 01"
	test_leds
	echo "++ lamp test 99"	
	clear_leds
	echo "++ leds all clear now "
		
# OK, this isn't gpio, but it's handy to put it here:
	
	mkdir -p /dev/hwmon
	
	for hwmon in /sys/class/hwmon/hwmon*
	do
		S=${hwmon##*n}	
		SRC=$hwmon/device
		if [ -e ${SRC}/temp ]; then
			ID=Z
		elif [ -e ${SRC}/temp1_input ]; then
			ID=$S	
		else
			continue;
		fi
		DST=/dev/hwmon/${ID}
		mkdir $DST
		
		case ${ID} in
		Z)
			for xx in temp v v_mode vccaux vccbram vccint
			do
				ln -s ${SRC}/${xx} ${DST}/${xx}
			done;;			
		0)
			ln -s ${SRC}/temp1_input ${DST}/temp
			ln -s ${SRC}/in1_input	 ${DST}/15VA_N
			ln -s ${SRC}/in2_input	 ${DST}/15VA_P
			ln -s ${SRC}/in3_input	 ${DST}/5V_P
			ln -s ${SRC}/in4_input	 ${DST}/VADJ;;
		*)
			ln -s ${SRC}/temp1_input ${DST}/temp
			for xx in in1_input in2_input in3_input in4_input
			do
				ln -s ${SRC}/${xx} ${DST}/${xx%*_input}
			done;;
		esac					
	done
	
	zmon=/sys/bus/platform/devices/f8007100.ps7-xadc/iio:device0
	if [ -e $zmon ]; then
				ln -s $zmon /dev/hwmon/Z
	fi
	echo ++ acq400_init_gpio_common end 99
}
