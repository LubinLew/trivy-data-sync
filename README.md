# trivy-data-sync

cache trivy data to local, support local registry

| Resource                                                                                    | Description      |
|---------------------------------------------------------------------------------------------|------------------|
| [trivy](https://github.com/aquasecurity/trivy/releases)                                     | rpm/deb packages |
| [trivy-db](https://github.com/aquasecurity/trivy-db/pkgs/container/trivy-db)                | db               |
| [trivy-java-db](https://github.com/aquasecurity/trivy-java-db/pkgs/container/trivy-java-db) | java-db          |

-----

## ENV

Linux Commands: `jq`, [`oras`](https://github.com/oras-project/oras/releases/), `sha256sum`

## Usage

**Crontab**

```bash
cat > /etc/cron.d/tricy_sync.cron <<EOF
0 */12 * * * root nohup flock -xn /var/run/trivysync.lock /path/trivy_sync.sh &>> /var/log/trivysync.log &
EOF
```

-----

## Dirs

```bash
./trivy_sync.sh

./trivy
./trivy/v0.37.2
./trivy/v0.37.2/trivy_0.37.2_Linux-64bit.rpm
./trivy/v0.37.2/trivy_0.37.2_Linux-64bit.deb

./trivy-db
./trivy-db/20230710_140203.tar.gz
./trivy-db/latest.tar.gz

./trivy-java-db
./trivy-java-db/20234810_080243.tar.gz
./trivy-java-db/latest.tar.gz
```

