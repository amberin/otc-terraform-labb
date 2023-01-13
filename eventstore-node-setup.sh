#!/bin/bash

set -ex

# Add authorized SSH public keys
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCXU4hFdhzHIKiCXrHcbnPwweYIbed6TPOAj7C71yl0oETyicpivxMBYFOJLbMiEBqURChvYx645nezzd2B0eY+o+hW+A5I99tjkW3MJKBzRM3b+yi+uDHV1ovpkGXcMBF3r/FLhHeSEiURJcVJxnpbUXZ+IoCd8rdaUPaIj3NvyIZuKeHkiEv9pNJaLLa8uTPYNAS0E9TADiWwf55eGsZAJnaxEXixx18JOtQ9aJfdWn6tl97DSDToDTZPbhMMpSnUKQjDSHCbygiY3qRtLn8E+//DNOuzAxCS6S9nUarLP7/MwnZfFPn7Nrs4BcRauhhk9OM+p3C6JjYmYa9d+YVWXNBFA7mBs0gt5Vc58E3J58rCO0uDIFRRzEp/+g6bnfDi37CgEWMMDRXpnyDoLTE0qTEqRdlKEvW1+ZlMG7HSo9qJBYocEYS3oLfdgiucdhBEcEL/uIZTwudwFWkWRnUkDD4cRafAPUXVgOIH+vPbHWqZv8SE/r3lZd4orswyGlhVozSsAac9yMAlu9aAzSYjPyN78QcMILF/xyR/WvsczArh75ntoNbbYVWySXkJVfVK4r9WPt043J+UpvKSICIkhIONZeHTeXaCTnO/Iz3UTbzmz0Us5UmwV8G6RwGywlLdhgwZDEHxo+BWmi0ICgskx1MG8gcslj/tD0fJrGrxKQ== victors' >> ~ubuntu/.ssh/authorized_keys

if ! command -v eventstored &> /dev/null
then
    if ! findmnt /data/esdb &> /dev/null; then
        mkdir -p /data/esdb
        : 'Examine /dev/vdb disk'
        test -b /dev/vdb
        if ! blkid /dev/vdb | grep -q ext4; then
            # The disk /dev/vdb is new, let's format it
            : 'Format /dev/vdb as ext4 filesystem'
            mkfs.ext4 /dev/vdb
        fi
        : 'Mount /dev/vdb on /data/esdb'
        echo '/dev/vdb /data/esdb ext4 defaults 0 2' >> /etc/fstab
        mount -a
        test -d /data/esdb/index || mkdir -p /data/esdb/index
    fi
    : 'Install EventStore'
    apt-get update
    apt-get install -y vim curl
    curl -s https://packagecloud.io/install/repositories/EventStore/EventStore-OSS/script.deb.sh | bash
    apt-get install -y eventstore-oss=${eventstore_version}
    chown -R eventstore:eventstore /data/esdb
fi

: 'Create S3 API client config'
cat << EOF > ~/.s3cfg
[default]
access_key = ${otc_access_key}
host_base = obs.eu-de.otc.t-systems.com
host_bucket = y
secret_key = ${otc_secret_key}
EOF

: 'Fetch EventStore node certificate'
mkdir /etc/eventstore/certs
s3cmd get -v s3://binosight-secrets-${otc_env}/eventstore-certs/node-wildcard/node.crt /etc/eventstore/certs/
: 'Fetch EventStore node key'
s3cmd get -v s3://binosight-secrets-${otc_env}/eventstore-certs/node-wildcard/node.key /etc/eventstore/certs/
: 'Fetch EventStore cluster CA certificate'
mkdir /etc/eventstore/certs/ca
s3cmd get -v s3://binosight-secrets-${otc_env}/eventstore-certs/ca/ca.crt /etc/eventstore/certs/ca/
chown eventstore:eventstore -R /etc/eventstore/certs
chmod 0600 /etc/eventstore/certs/node.key

: 'Configure EventStore'

cd /etc/eventstore/
rm eventstore.conf

cat << EOF >> eventstore.conf

# Paths
Db: /data/esdb
Index: /data/esdb/index
Log: /var/log/eventstore

# Certificates configuration
CertificateFile: /etc/eventstore/certs/node.crt
CertificatePrivateKeyFile: /etc/eventstore/certs/node.key
TrustedRootCertificatesPath: /etc/eventstore/certs/ca

# Network configuration
IntIp: $(hostname -I)
ExtIp: $(hostname -I)
HttpPort: 2113
IntTcpPort: 1112
ExtTcpPort: 1113
EnableExternalTcp: true
EnableAtomPubOverHTTP: true
AdvertiseHostToClientAs: $(hostname -s).eventstore.${otc_env}.binosight.com
# IntTcpHeartbeat values suggested in
# https://github.com/EventStore/EventStore/issues/2624#issuecomment-670493762
IntTcpHeartbeatTimeout: 2500
IntTcpHeartbeatInterval: 1000
# ExtTcpHeartbeat values suggested in
# https://www.dinuzzo.co.uk/2019/02/11/settings-for-an-healthy-event-store-cluster/
ExtTcpHeartbeatInterval: 3000
ExtTcpHeartbeatTimeout: 6000

# Cluster gossip
ClusterSize: ${cluster_size}
DiscoverViaDns: true
ClusterDns: ${cluster_dns}

# Projections configuration
RunProjections: All
StartStandardProjections: true

EOF

# Use the local top level domain "private." for resolving peers in OTC VPCs
echo 'Domains=private' >> /etc/systemd/resolved.conf
systemctl restart systemd-resolved.service

cat /etc/eventstore/eventstore.conf
: 'Start EventStore'
systemctl enable --now eventstore

if ! grep -q "$(hostname -I) es" /etc/hosts; then
    echo "$(hostname -I)" es >> /etc/hosts; 
fi

: 'Pin the eventstore-oss package to the current version'
apt-mark hold eventstore-oss
: 'Upgrade Ubuntu packages'
unattended-upgrade -v
