wifi.setmode(wifi.STATIONAP)
wifi.sta.connect()
gpio.mode(0, gpio.OUTPUT)--kontakt1
gpio.mode(5, gpio.OUTPUT) 
gpio.mode(1, gpio.OUTPUT) 
gpio.mode(6, gpio.OUTPUT) 
gpio.mode(7, gpio.INT) --button /reset
-----------------------------------
gpio.write(0, gpio.LOW)
gpio.write(1,gpio.LOW)
gpio.write(5,gpio.HIGH)
gpio.write(6,gpio.LOW)
local target,target_ip,target_port=0,0,0
local host_ip,host_port=0,5683
local cntr,once=0,0
local timer,timer2=0,0
local set,blink=0,0
local state,stat,raw_old=0,0,0
cfg={}
cfg.ssid="SmartLampSwitch"
cfg.pwd="smartthings"
wifi.ap.config(cfg)
function fileRead()
	file.open("target.lua", "r")
	target=file.readline()
	if(target~=nil) then
		g,j=string.find(target,"port=")
		target_ip=string.sub(target, 0, g-2)
		target_port=string.sub(target, j+1, j+4)
	end
	file.close()
end
function fileWrite(a)
	file.open("target.lua", "w+")
	file.writeline(a)
	file.close()
end
function wipe()
	wifi.sta.disconnect()
	wifi.sta.config("", "")
	cntr=0
	Red_led()
	node.restart()
end
function Green_led()           
	gpio.write(6,gpio.LOW)
	gpio.write(5,gpio.LOW)
	gpio.write(1,gpio.HIGH)
end
function Red_led()           
	gpio.write(6,gpio.HIGH)
	gpio.write(5,gpio.LOW) --blue
	gpio.write(1,gpio.LOW)
end
function Blue_led()
	gpio.write(6,gpio.LOW) --red
	gpio.write(5,gpio.HIGH)
	gpio.write(1,gpio.LOW)
end
function onChange ()  
	if state==0 and cntr==0 then
		gpio.write(0, gpio.HIGH)
		state=1
	elseif state==1 and cntr==0 then
		gpio.write(0, gpio.LOW)
		state=0
	end
    if cntr<=12 then
		cntr=cntr+1
		tmr.delay(250000)
	else
		wipe()
	end
end
gpio.trig(7, 'low', onChange)
function UdpStart()
once=1
Blue_led()
fileRead()
host_ip=wifi.sta.getip()
cu=net.createConnection(net.UDP)
cu:connect(target_port,target_ip)
cu:send('{"head":"DV-INFORMATION","type": "LC", "ip":"'..host_ip..'","port":"'..host_port..'"}')
s=net.createServer(net.UDP)
s:on("receive", function(s, c) 
	if (c=="1")and(state==0) then
		gpio.write(0, gpio.HIGH)
		state=1
	elseif(c=="1")and(state==1) then
		gpio.write(0, gpio.LOW)
		state=0
	end	
	end)
s:listen(host_port)
	end
srv=net.createServer(net.TCP)               
srv:listen(80,function(conn)
	conn:on("receive",function(conn,payload)
	           -- conn:send("<h1><center>Hello, I'm SmartLampSwitch-v1.1 ChipID:"..node.chipid().."</center></h1>")
				s=payload;
				a,b=string.find(s, "ssid=")
				c,d=string.find(s, "pass=")
				e,f=string.find(s,"target=")
				g,j=string.find(s,"port=")
				k,l=string.find(s,"end")
				if (b ~=nil)and(d ~=nil)and(f ~=nil)and(j ~=nil) then
					if ((c-b)~=1)and((e-d)~=1)and((g-f)~=1)and((k-j)~=1) then
						ssid=string.sub(s, b+1, c-2)
						pass=string.sub(s, c+5, e-2)
						target=string.sub(s, e+7, k-1)
						target_ip=string.sub(s, e+7, g-2)
						target_port=string.sub(s, g+5, k-1)
						pass_len=string.len(pass)
						--print(ssid,pass,target,target_ip,target_port)
						fileWrite(target)
						if(((pass_len>=8)and(pass_len<=24))or(pass_len==0)) then
							pass_min=0
							wifi.sta.config(ssid, pass,0)
							wifi.sta.connect()
						else
							wipe()
						end
					else
						node.restart()
					end
				end
	end)
conn:on("sent",function(conn) conn:close() end)
    end)
tmr.alarm(0, 500, 1, function()  
raw=adc.read(0)
if once==1 then
	if gpio.read(0)==0 then
		if stat==0 or raw_old~=raw then
			cu:connect(target_port,target_ip)
			cu:send('{"type":"LC","k1":"0","data":"'..raw..'"}')
			raw_old=raw
			stat=1
		end
	else
		if stat==1 or raw_old~=raw then
			cu:connect(target_port,target_ip)
			cu:send('{"type":"LC","k1":"1","data":"'..raw..'"}')
			raw_old=raw
			stat=0
		end
	end
end
if gpio.read(0)==1 then
	Green_led()
elseif wifi.sta.status()==5 and gpio.read(0)==0 then
	Blue_led()
else
    Red_led()
end
--print(wifi.sta.status(),gpio.read(2),timer,timer2,node.heap())
	if gpio.read(7)==1 then
		cntr=0
	end
		if (wifi.sta.status() ==5) and (once==0)  then
			UdpStart()
			timer=0
			timer2=0
		elseif (wifi.sta.status()==1)or(wifi.sta.status()==4)or(wifi.sta.status()==3) then
		    timer=timer+1
			if timer==30 then
			    timer=0
				node.restart()
			end
		elseif (wifi.sta.status()==2) then
		if blink==0 then
        	gpio.write(6,gpio.LOW)
			blink=1
		else
			gpio.write(6,gpio.HIGH)
			blink=0
		end
		timer=0
		timer2=timer2+1
		if timer2==70 then
			timer2=0
			wipe()
		end
		end
end )

