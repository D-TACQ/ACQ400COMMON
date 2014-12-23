init_acq2006_leds() {
# LP3943ISQ
	
	LEDSCHIP=$(getchip 1-0060)
	if [ $? -eq 0 ]; then
		echo +++ LEDSCHIP FOUND $LEDSCHIP

		let LED0=${LEDSCHIP#gpiochip*}
# LED0 : PWM NOT GPIO 
		let LED01=$LED0+1
		let LED1=$LED0+14

	
		for pin in $(seq $LED01 $LED1)
		do
			export_gpio $pin
			setO gpio${pin}
		done

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
	fi					
}

create_set_fanspeed() {
		# acq2006 only		 
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
set.sys /sys/class/pwm/pwmchip0/pwm$1/duty_cycle \$DC
EOF
		
	chmod a+rx /usr/local/bin/set.fanspeed$1
	echo /usr/local/bin/set.fanspeed$1 created
}



acq2006_create_pwm() {
	if [ -e /sys/class/pwm/pwmchip0/pwm0 ]; then
# inversed control dropped from released driver
#set.sys /sys/class/pwm/pwmchip0/pwm0/polarity inversed
		set.sys /sys/class/pwm/pwmchip0/pwm0/period 100000
		set.sys /sys/class/pwm/pwmchip0/pwm0/duty_cycle 50000
		set.sys /sys/class/pwm/pwmchip0/pwm0/enable 1
		create_set_fanspeed 0
	fi
	if [ -e /sys/class/pwm/pwmchip0/pwm1 ]; then
# inversed control dropped from released driver
#set.sys /sys/class/pwm/pwmchip0/pwm0/polarity inversed
		set.sys /sys/class/pwm/pwmchip0/pwm1/period 100000
		set.sys /sys/class/pwm/pwmchip0/pwm1/duty_cycle 50000
		set.sys /sys/class/pwm/pwmchip0/pwm0/enable 1
		create_set_fanspeed 1
	fi	
}

init_acq2006_leds
acq2006_create_pwm