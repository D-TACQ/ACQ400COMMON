
# acq400_init_gpio_common : function lib for acqXXXX_init_gpio

export_gpio() {
	echo $1 > export
}

getchip() {
	addr=$1
	ls -l gpiochip* | grep $addr | awk '{ print $9 }'
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
	ln -s $PWD/$1/value /dev/gpio/$2
	if [ "x$3" = "xAL" ]; then
		setAL $1
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
		echo 0 > $LED
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
	
# LP3943ISQ
	
	LEDSCHIP=$(getchip 1-0060)
	if [ $? -ne 0 ]; then
		echo +++ ERROR: LEDSCHIP NOT FOUND
	else
		echo +++ LEDSCHIP FOUND $LEDSCHIP
	fi
	let LED0=${LEDSCHIP#gpiochip*}
# LED0 : PWM NOT GPIO 
	let LED01=$LED0+1
	let LED1=$LED0+14

	
	for pin in $(seq $LED01 $LED1)
	do
		export_gpio $pin
		setO gpio${pin}
	done
	
# inversed control dropped from released driver
#set.sys /sys/class/pwm/pwmchip0/pwm0/polarity inversed
	set.sys /sys/class/pwm/pwmchip0/pwm0/period 100000
	set.sys /sys/class/pwm/pwmchip0/pwm0/duty_cycle 50000
	set.sys /sys/class/pwm/pwmchip0/pwm0/enable 1
	
cat - >/usr/local/bin/set.fanspeed <<EOF
#!/bin/sh
# set fanspeed acq2006 style
FSPERCENT=\${1:-50}
if [ \$FSPERCENT -gt 100 ]; then 
	let FSPERCENT=100
elif [ \$FSPERCENT -lt 0 ]; then
	let FSPERCENT=0
fi
# inverse ratio
let DC="(100-\$FSPERCENT)*1000"
set.sys /sys/class/pwm/pwmchip0/pwm0/duty_cycle \$DC
EOF
	chmod a+rx /usr/local/bin/set.fanspeed
	echo /usr/local/bin/set.fanspeed created
	
	mkln $(gpioLED $LED0 1)  LED/FMC1_G 	AL
	mkln $(gpioLED $LED0 2)  LED/FMC2_G 	AL
	mkln $(gpioLED $LED0 3)  LED/FMC3_G	AL
	mkln $(gpioLED $LED0 4)  LED/FMC4_G 	AL
	mkln $(gpioLED $LED0 5)  LED/FMC5_G 	AL
	mkln $(gpioLED $LED0 6)  LED/FMC6_G 	AL
	mkln $(gpioLED $LED0 7)  LED/FMC1_R 	AL
	mkln $(gpioLED $LED0 8)  LED/FMC2_R 	AL
	mkln $(gpioLED $LED0 9)  LED/FMC3_R 	AL
	mkln $(gpioLED $LED0 10) LED/FMC4_R 	AL
	mkln $(gpioLED $LED0 11) LED/FMC5_R 	AL
	mkln $(gpioLED $LED0 12) LED/FMC6_R 	AL
	mkln $(gpioLED $LED0 13) LED/ACT_G  	AL
	mkln $(gpioLED $LED0 14) LED/ACT_R  	AL
		
	clear_leds
	echo "++ lamp test 01"
	test_leds
	echo "++ lamp test 99"
	
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
