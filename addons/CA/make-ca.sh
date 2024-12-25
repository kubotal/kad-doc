#!/bin/bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# CA name
CA=ca
TF=${MYDIR}/kad-ca

SUBJECT="/C=FR/ST=Paris/L=Paris/O=Kubotal/OU=R&D/CN=ca.kad.kubotal.io"


if [ -f "${TF}/${CA}.crt" ]
then
	echo "---------- CA already existing"
	exit 1
fi

mkdir -p ${TF}

cat << EOF > ${TF}/req.cnf
[ req ]
#default_bits		= 2048
#default_md		= sha256
#default_keyfile 	= privkey.pem
distinguished_name	= req_distinguished_name
attributes		= req_attributes

[ req_distinguished_name ]

[ req_attributes ]
challengePassword		= A challenge password
challengePassword_min		= 4
challengePassword_max		= 20

[ v3_ca ]
basicConstraints = critical,CA:TRUE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always

EOF
	
	
echo "---------- Create CA Root Key"
openssl genrsa -out ${TF}/${CA}.key 4096 2>/dev/null

echo "---------- Create and self sign the Root Certificate"
openssl req -x509 -new -nodes -key ${TF}/${CA}.key -sha256 -days 3650 -out ${TF}/${CA}.crt -extensions v3_ca -config ${TF}/req.cnf -subj ${SUBJECT}

#echo "---------- Convert to PEM"
#openssl x509 -in ${TF}/${CA}.crt -out ${TF}/${CA}.pem -outform PEM

echo "---------- have a look on CA:"
openssl x509 -in ${TF}/${CA}.crt -text -noout | head -n 450

