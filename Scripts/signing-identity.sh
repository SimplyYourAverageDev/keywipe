#!/bin/zsh
# Prints the SHA-1 of the certificate that signs local builds, creating it on first use.
#
# macOS ties the keyboard permission to the app's code signature. An ad hoc signature is
# different for every build, so the permission would have to be granted again after each
# one. Signing every build with the same self-signed certificate keeps it in place.
#
# The certificate and its key live in a keychain file inside the project (.signing/),
# which is not added to the user's keychain search list. Deleting that folder creates a
# new identity on the next build, and the permission then has to be granted once more.

set -euo pipefail

cd "${0:A:h}/.."

name="Keywipe Local Signing"
dir="$PWD/.signing"
keychain="$dir/keywipe.keychain-db"
password_file="$dir/password"

if [[ ! -f "$keychain" ]]; then
    umask 077
    mkdir -p "$dir"
    work="$(mktemp -d "$dir/tmp.XXXXXX")"
    # A half-made keychain would be mistaken for a finished one on the next run.
    trap 'rm -rf "$work" "$keychain" "$password_file"' ZERR INT TERM

    /usr/bin/openssl rand -hex 24 > "$password_file"
    password="$(<"$password_file")"

    cat > "$work/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $name
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF
    /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -config "$work/cert.cnf" \
        -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null

    security create-keychain -p "$password" "$keychain"
    # No arguments means the keychain does not lock itself after a timeout.
    security set-keychain-settings "$keychain"
    security unlock-keychain -p "$password" "$keychain"
    security import "$work/key.pem" -k "$keychain" -T /usr/bin/codesign >/dev/null
    security import "$work/cert.pem" -k "$keychain" >/dev/null
    # Lets codesign use the key without a confirmation dialog on every build.
    security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain" >/dev/null

    rm -rf "$work"
    trap - ZERR INT TERM
    echo "Created signing identity \"$name\" in .signing/" >&2
fi

security unlock-keychain -p "$(<"$password_file")" "$keychain"

hash="$(security find-certificate -c "$name" -Z "$keychain" | awk '/SHA-1/ { print $NF }')"
if [[ -z "$hash" ]]; then
    echo "No \"$name\" certificate in $keychain. Delete .signing/ and build again." >&2
    exit 1
fi
echo "$hash"
