# Moto-Gate
Variation of TRBO-NET program by Juan Carlos Pérez KM4NNO / XE1F.

To see the project wiki, go to:

https://wodielite.com/wiki/index.php/Manual_Moto-Gate


# Instalation notes:
## Fix IP route
sudo nano /lib/dhcpcd/dhcpcd-hooks/40-route
## Add the following lines
ip route add 12.0.0.0/8 via 192.168.10.1
ip route add 13.0.0.0/8 via 192.168.10.1

