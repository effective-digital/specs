#!/usr/bin/env python3
import argparse, socket, ssl, base64, hashlib, sys
from cryptography import x509
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from cryptography.hazmat.primitives.asymmetric import rsa, ec, ed25519, ed448

def sha256_b64(data: bytes) -> str:
    return base64.b64encode(hashlib.sha256(data).digest()).decode("ascii")

def get_leaf_cert_der(host: str, port: int, timeout: float, insecure: bool) -> bytes:
    if insecure:
        ctx = ssl._create_unverified_context()
    else:
        ctx = ssl.create_default_context()
    with socket.create_connection((host, port), timeout=timeout) as sock:
        with ctx.wrap_socket(sock, server_hostname=host) as ssock:
            return ssock.getpeercert(binary_form=True)

def export_raw_public_key(cert_der: bytes) -> tuple[bytes, bytes, str]:
    cert = x509.load_der_x509_certificate(cert_der)
    pub = cert.public_key()

    # RAW (matches iOS SecKeyCopyExternalRepresentation):
    # - RSA: PKCS#1 RSAPublicKey (DER)
    # - EC: ANSI X9.63 uncompressed point (0x04 || X || Y)
    # - Ed25519/Ed448: raw 32/57 bytes
    if isinstance(pub, rsa.RSAPublicKey):
        raw = pub.public_bytes(Encoding.DER, PublicFormat.PKCS1)
        ktype = "RSA (PKCS#1 DER)"
    elif isinstance(pub, ec.EllipticCurvePublicKey):
        raw = pub.public_bytes(Encoding.X962, PublicFormat.UncompressedPoint)
        ktype = f"EC {pub.curve.name} (X9.63 uncompressed)"
    elif isinstance(pub, (ed25519.Ed25519PublicKey, ed448.Ed448PublicKey)):
        raw = pub.public_bytes(Encoding.Raw, PublicFormat.Raw)
        ktype = pub.__class__.__name__ + " (raw)"
    else:
        # Fallback: use SPKI if an unknown type shows up
        raw = pub.public_bytes(Encoding.DER, PublicFormat.SubjectPublicKeyInfo)
        ktype = "Unknown type → SPKI fallback"

    # SPKI (reference; handy if you later switch pinning style)
    spki = pub.public_bytes(Encoding.DER, PublicFormat.SubjectPublicKeyInfo)
    return raw, spki, ktype

def main():
    ap = argparse.ArgumentParser(description="Extract public key pin (raw-key SHA256 Base64) compatible with iOS SecKeyCopyExternalRepresentation.")
    ap.add_argument("server", help="Hostname (SNI) e.g. api.example.com")
    ap.add_argument("--port", type=int, default=443, help="Port (default: 443)")
    ap.add_argument("--timeout", type=float, default=5.0, help="Socket timeout seconds (default: 5)")
    ap.add_argument("--insecure", action="store_true", help="Skip TLS verification (not recommended)")
    ap.add_argument("--print-key", action="store_true", help="Also print base64 of the raw public key bytes (sensitive)")
    args = ap.parse_args()

    try:
        cert_der = get_leaf_cert_der(args.server, args.port, args.timeout, args.insecure)
        raw, spki, ktype = export_raw_public_key(cert_der)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Key format (raw export): {ktype}")
    print(f"PIN (RAW key)  SHA256 Base64: {sha256_b64(raw)}   <-- use this KEY")

    if args.print_key:
        print("\nRaw public key (Base64) — sensitive, do not log in prod:")
        print(base64.b64encode(raw).decode("ascii"))

if __name__ == "__main__":
    main()

