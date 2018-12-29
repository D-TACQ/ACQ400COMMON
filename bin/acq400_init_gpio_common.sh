
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

get_gpiochip() 
{
	echo $(basename $(echo /sys/bus/i2c/devices/$1-$2/gpio/gpiochip*))	
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


lnAL() {
	setAL $1;ln -s $1/value $2	
}

lnALO() {
	setAL $1; echo 0 >$1/value; ln -s $1/value $2	
}

lnAH() {
	ln -s $1/value $2	
}


mkln() {
	gpn=$1
	ln -s $PWD/$gpn/value /dev/gpio/$2
	shift;shift;
	while [ "x$1" != "x" ]; do
		case $1 in
		AL)
			setAL $gpn;;
		ALO)
			echo out > $gpn/direction
			echo 1 >$gpn/active_low
			echo 0 >$gpn/value;;
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

i2c_reset() {
	setHI /dev/gpio/I2C_RESET
	sleep 0.1
	setLO /dev/gpio/I2C_RESET
	echo +++ I2C_RESET done
}

get_zynq_gpio0() {
    for file in /sys/class/gpio/gpiochip*; do
        if [ "$(cat $file/label)" = "zynq_gpio" ]; then
            CHIP=$(basename $file)
            echo ${CHIP#gpiochip*}
            return
        fi
    done
    
    echo FAILED TO FIND ZYNQ GPIO
    exit 1   
}
common_begin() {
	echo ++ acq400_init_gpio_common begin

	mkdir -p /dev/gpio
	cd /sys/class/gpio

# Zynq GPIO
    zgpio0=$(get_zynq_gpio0)
    LED_ACT=$(($zgpio0 + 0))
	export_gpio  $LED_ACT; setO gpio$LED_ACT
	mkln gpio$LED_ACT LED_ACT
	nice daemon /usr/local/bin/heartbeat

# I2C_RESET : use with care, will confuse the ps7 i2c driver
    I2C_RESET=$(($zgpio0 + 9))
	export_gpio $I2C_RESET; setO gpio$I2C_RESET
	mkln gpio$I2C_RESET I2C_RESET	AL

    EXT_WP=$(($zgpio0 + 47))
	export_gpio $EXT_WP;	
	mkln gpio$EXT_WP EXT_WP AL
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

hook_hwmon() {
# OK, this isn't gpio, but it's handy to put it here:
	mkdir -p /dev/hwmon
	
	id7417=0
	for hwmon in /sys/class/hwmon/hwmon* /sys/bus/platform/devices/f8007100.adc/iio\:device0
	do
		case $(cat $hwmon/name) in
		ad7417)
			DST=/dev/hwmon/$id7417
			mkdir $DST
			case $id7417 in
			0)
				ln -s ${hwmon}/temp1_input ${DST}/temp
	                        ln -s ${hwmon}/in1_input   ${DST}/15VA_N
        	                ln -s ${hwmon}/in2_input   ${DST}/15VA_P
                	        ln -s ${hwmon}/in3_input   ${DST}/5V_P
                        	ln -s ${hwmon}/in4_input   ${DST}/VADJ;;
			*)
	 	                ln -s ${hwmon}/temp1_input ${DST}/temp
                        	for xx in in1_input in2_input in3_input in4_input
                        	do
                                	ln -s ${hwmon}/${xx} ${DST}/${xx%*_input}
	                        done;;
			esac
			let id7417="$id7417+1";;
		*eth*)
			mkdir /dev/hwmon/E
			ln -s $hwmon/temp1_input /dev/hwmon/E/temp
		xadc)
			ln -s $hwmon /dev/hwmon/Z
			mkdir $DST
			for xx in in_temp v_mode vccaux vccbram vccint
                        do
                                ln -s ${SRC}/${xx} ${DST}/${xx}
                        done;;
		esac
	done	
}
common_end() {
	echo ++ acq400_init_gpio_common end 01		
	clear_leds
	echo "++ lamp test 01"
	test_leds
	echo "++ lamp test 99"	
	clear_leds
	echo "++ leds all clear now "
	hook_hwmon		
	echo ++ acq400_init_gpio_common end 99
}
