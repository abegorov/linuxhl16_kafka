#!/bin/sh
set -eu

SD=$(dirname "${0}")

NAME=kfk-es-01
CA="${SD}/secrets/certs/kafka/ca.crt"
CAJKS="${SD}/secrets/certs/kafka/ca.jks"
CERT="${SD}/secrets/certs/kafka/${NAME}.crt"
KEY="${SD}/secrets/certs/kafka/${NAME}.key"
P12="${SD}/secrets/certs/kafka/${NAME}.p12"
PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)

rm "${P12}" -f
rm "${CAJKS}" -f
openssl pkcs12 -export -in "${CERT}" -inkey "${KEY}" -name "${NAME}" \
  -out "${P12}" -passout "pass:${PASSWORD}"
chmod 644 "${P12}"
keytool -importcert -file "${CA}" -alias ROOTCA -trustcacerts \
  -keystore "${CAJKS}" -storepass "${PASSWORD}" -noprompt

docker run --rm -it -p 8080:8080 \
  -e DYNAMIC_CONFIG_ENABLED="true" \
  -e KAFKA_CLUSTERS_0_NAME="vagrant" \
  -e KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS="192.168.56.31:9092,192.168.56.32:9092,192.168.56.33:9092" \
  -e KAFKA_CLUSTERS_0_SSL_TRUSTSTORELOCATION="/etc/kafkaui/truststore.jks" \
  -e KAFKA_CLUSTERS_0_SSL_TRUSTSTOREPASSWORD="${PASSWORD}" \
  -e KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL="SSL" \
  -e KAFKA_CLUSTERS_0_PROPERTIES_SSL_KEYSTORE_LOCATION="/etc/kafkaui/keystore.p12" \
  -e KAFKA_CLUSTERS_0_PROPERTIES_SSL_KEYSTORE_PASSWORD="${PASSWORD}" \
  -v "${P12}:/etc/kafkaui/keystore.p12" \
  -v "${CAJKS}:/etc/kafkaui/truststore.jks" \
  ghcr.io/kafbat/kafka-ui:main
