#!/bin/bash
aws ec2 create-security-group --group-name EC2SecurityGroup --description "Security Group for EC2 instances to allow port 22 and udp 51820" --profile vpn
aws ec2 authorize-security-group-ingress --group-name EC2SecurityGroup --protocol tcp --port 22 --cidr 0.0.0.0/0 --profile vpn
aws ec2 authorize-security-group-ingress --group-name EC2SecurityGroup --protocol udp --port 51820 --cidr 0.0.0.0/0 --profile vpn
aws ec2 describe-security-groups --group-names EC2SecurityGroup --profile vpn

aws ec2 import-key-pair --key-name 'scripted-key-pair' --public-key-material fileb://~/.ssh/id_rsa_NEW.pub --profile vpn

aws ec2 run-instances --image-id ami-0a91cd140a1fc148a --key-name 'scripted-key-pair' --security-groups EC2SecurityGroup --instance-type t2.micro --placement AvailabilityZone=us-east-2a --block-device-mappings DeviceName=/dev/sdh,Ebs={VolumeSize=8} --profile vpn

sleep 60                                                                                                                                                 

myip=`aws ec2 describe-instances --query "Reservations[*].Instances[0].PublicIpAddress" --output=text --profile vpn`

ssh  -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ubuntu@${myip} << EOF
sudo apt-get update
sudo apt-get install wireguard -y
(umask 077 && printf "[Interface]\nPrivateKey = " | sudo tee /etc/wireguard/wg0.conf > /dev/null)
wg genkey | sudo tee -a /etc/wireguard/wg0.conf | wg pubkey | sudo tee /etc/wireguard/publickey
(umask 077 && printf "Address = 10.0.0.1/24\n" | sudo tee -a /etc/wireguard/wg0.conf > /dev/null)
(umask 077 && printf "ListenPort = 51820\n" | sudo tee -a /etc/wireguard/wg0.conf > /dev/null)
(umask 077 && printf "PostUp = iptables -A FORWARD -i %%i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE\n" | sudo tee -a /etc/wireguard/wg0.conf > /dev/null)
(umask 077 && printf "PostDown = iptables -D FORWARD -i %%i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE\n\n\n" | sudo tee -a /etc/wireguard/wg0.conf > /dev/null)
(umask 077 && printf "[Peer]\nPublicKey = sukfsSTswzNG7VtUPxCdbepqgL+Os5d4IJH/9Gxy4Bs=\nAllowedIPs = 10.0.0.2/32\n" | sudo tee -a /etc/wireguard/wg0.conf > /dev/null)

sudo systemctl start wg-quick@wg0

EOF

