#!/bin/bash
#############################
#
# OCSP Cache Updater v0.2.1
#   by Yufei
#
# ---------------------------
#
# Usage:
#   % update_ssl_ocsp "example.com" "/etc/letsencrypt/live/ios/fullchain.pem" "TrustAsia"
#
# ---------------------------
#############################

if [ -z $1 ]; then
    echo -e "No domain is specified!" >&2
    exit 1
fi

if [ -z $2 ]; then
    echo -e "local cert? like /etc/letsencrypt/live/ios/fullchain.pem" >&2
    exit 1
fi

if [ -z $3 ]; then
    echo -e "Which certificate type, Let's_Encrypt or TrustAsia ?" >&2
    echo -e "default Let's_Encrypt " >&2
else
    cer_type=$3
fi

############################
# CONFIGS
############################
#LE_DIR="/usr/local/etc/nginx/ssl"

LE_DIR="/data/html/ssl/"
GEN_NUM="x3"
#域名
DOMAIN=$1   
#工作目录 
CERT_DIR="${LE_DIR}/${DOMAIN}"  
if [ ! -d $CERT_DIR ]; then
  mkdir $CERT_DIR
fi

############################
# DEFAULTS
############################
#本地证书
CHAINED_CERT="${CERT_DIR}/fullchain.pem"  
if [ ! -f $CHAINED_CERT ] ;then
    CHAINED_CERT=$2
fi
#中间证书 和根证书
ISSUER_CERT="${LE_DIR}/Lets_Encrypt_Authority_X3.cer"
Root_CERT="${LE_DIR}/DST_ROOT_CA_X3.cer"
if [[ $cer_type = "Let's_Encrypt_R3" ]];then
    ISSUER_CERT="${LE_DIR}/R3.cer"
    Root_CERT="${LE_DIR}/DST_ROOT_CA_X3.cer"
fi  

if [[ $cer_type = "TrustAsia" ]];then
    ISSUER_CERT="${LE_DIR}/TrustAsia_TLS_RSA_CA.cer"
    Root_CERT="${LE_DIR}/DigiCert_Global_Root_CA.cer"
fi  

if [[ $cer_type = "Geotrust" ]];then
    ISSUER_CERT="${LE_DIR}/GeoTrust.cer"
    Root_CERT="${LE_DIR}/DigiCert.cer"
fi

#ocsp验证证书  本地证书+中间证书+根证书
CA_FILE="${CERT_DIR}/ca-bundle.pem"
cat $ISSUER_CERT > $CA_FILE
cat $Root_CERT >> $CA_FILE
cp $CA_FILE ${CERT_DIR}/checkid.pem

#oscp证书 #oscp返回数据
OCSP_RESP_FILE="${CERT_DIR}/ocsp.resp"  
OCSP_REPLY_FILE="${CERT_DIR}/ocsp.reply"    

############################
# MAIN
############################
# Functions
existence_pattern_check(){
    [ -n "$1" ] && [ -e "$1" ] && ( [ "${2:-file}" = "file" ] && ( [ -f "$1" ] || [ -L "$1" ] ) || [ -d "$1" ] ) && [ -r "$1" ]
}

# Params Validation
if ! existence_pattern_check "${LE_DIR}" "dir"; then
    echo -e "mkdir ssl folder" >&2
    mkdir ${LE_DIR} -p
elif ! existence_pattern_check "${CERT_DIR}" "dir"; then
    echo -e "mkdir cert folder" >&2
    mkdir ${CERT_DIR} -p
echo $CHAINED_CERT $ISSUER_CERT $CA_FILE
elif ! existence_pattern_check "${CHAINED_CERT}" || ! existence_pattern_check "${ISSUER_CERT}" || ! existence_pattern_check "${CA_FILE}"; then
echo $CHAINED_CERT $ISSUER_CERT $CA_FILE
    echo -e "Required certs file is missing!" >&2
    exit 1
fi

# Get OCSP URI & HOST
OCSP_URL=$(openssl x509 -in "${CHAINED_CERT}"  -text | grep "OCSP - URI:" | cut -d: -f2,3)
if [ ! OCSP_URL ];then
    OCSP_URL=$(openssl x509 -in "${CHAINED_CERT}" -noout -ocsp_uri)
fi
OCSP_HOST=$(echo "${OCSP_URL}" | awk -F/ '{print $3}')

# Output OCSP response
openssl ocsp -no_nonce \
             -respout "${OCSP_RESP_FILE}.new" \
             -issuer "${ISSUER_CERT}" \
             -cert "${CHAINED_CERT}" \
             -CAfile "${CA_FILE}" \
             -VAfile "${CA_FILE}" \
             -url "${OCSP_URL}" \
	     -header HOST "${OCSP_HOST}"  > "${OCSP_REPLY_FILE}" 2>&1

# Check if it's all okay?
if  grep -q "Response verify OK" "${OCSP_REPLY_FILE}" && grep -q "${CHAINED_CERT}: good" "${OCSP_REPLY_FILE}" ; then
    if  cmp -s "${OCSP_RESP_FILE}.new" "${OCSP_RESP_FILE}" ; then
        # No news is good news
        rm -rf "${OCSP_RESP_FILE}.new"
        echo -e "OCSP cache is up-to-date!"
    else
        # Update the cache file
        #mv "${OCSP_RESP_FILE}" "${OCSP_RESP_FILE}.old"
        mv "${OCSP_RESP_FILE}.new" "${OCSP_RESP_FILE}"

        # reload nginx's config
        /usr/bin/nginx -s reload

        echo -e "OCSP cache is updated!"
    fi
else
    # Bad things happen all the time
    cat "${OCSP_REPLY_FILE}" >&2

    echo -e "Failed to update OCSP cache!" >&2
fi

# Make a backup
mv "${OCSP_REPLY_FILE}" "${OCSP_REPLY_FILE}.old"
echo -e "Detailed log located at ${OCSP_REPLY_FILE}.old"
