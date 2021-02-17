# sync docker hub library repo images to registry

TODO:

## Usage:

1. fork [docker-library/official-images](https://github.com/docker-library/official-images) repo to your GitHub account

2. fork this repo [https://github.com/muzi502/sync-library-images](https://github.com/muzi502/sync-library-images) repo to your GitHub account

3. config Actions secrets on your sync-library-images repo `Settings > Secrets`, set this Repository secrets:

- `REGISTRY_DOMAIN`: image registry domain, this domain must with TLS/SSL certificate.
- `REGISTRY_USER`: registry user which have the push privilege to library repo/project.
- `REGISTRY_PASSWORD`: registry user password.
- `TOKEN_GITHUB`: github token for rebase upstream and push new repo tag to yourself repo.
