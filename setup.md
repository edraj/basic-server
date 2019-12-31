

## Configuration

### Configure parameters

```bash
cp config.sample.yml config.yml
# Edit cofig.yml to your liking
```

## Install Crystal-lang on Fedora/Redhat/Centos

```bash
# As root

rpm --import https://dist.crystal-lang.org/rpm/RPM-GPG-KEY

cat > /etc/yum.repos.d/crystal.repo <<END
[crystal]
name = Crystal
baseurl = https://dist.crystal-lang.org/rpm/
END

dnf install -y crystal redis gmp-static libyaml-devel openssl-devel
```

## Tests

```bash
# Run tests
KEMAL_ENV=test crystal spec
```

## Steps to run

```bash
# Build sentry
crystal build --release ./contrib/sentry/sentry_cli.cr -o ./bin/sentry

# Download dependencies
shards

# Syntax linting and formatting
./check.sh

# Build and run edraj binary
./run.sh [arguments]
```

