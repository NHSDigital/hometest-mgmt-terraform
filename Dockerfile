FROM fedora:43

RUN dnf update -y \
    && dnf install -y dnf-plugins-core \
    && dnf config-manager addrepo --from-repofile=https://mise.jdx.dev/rpm/mise.repo \
    && dnf install -y mise git gcc libatomic \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# GCC and libatomic required for markdownlint_cli installation

RUN git config --global --add safe.directory '*'

# git config --global --add safe.directory '/repo'
