#!/bin/bash

# Server details
SERVER="edp-skai2.westeurope.cloudapp.azure.com"
PORT=443

# Function to extract public key hash (Android)
extract_android() {
    echo "🔍 Extracting Public Key Hash for Android..."
    ANDROID_SHA256_HASH=$(openssl s_client -connect $SERVER:$PORT -servername $SERVER < /dev/null 2>/dev/null |
    openssl x509 -pubkey -noout |
    openssl pkey -pubin -outform der |
    openssl dgst -sha256 -binary |
    base64)
    echo "🔹 Android - SHA256 Public Key Hash: $ANDROID_SHA256_HASH"
}

# Function to extract and process public key (iOS)
extract_ios() {
    echo "🔍 Extracting Public Key from $SERVER:$PORT ..."
    
    # Step 1: Get the server's public key (PEM format)
    openssl s_client -connect $SERVER:$PORT -servername $SERVER < /dev/null 2>/dev/null |
    openssl x509 -pubkey -noout > public_key.pem
    echo "✅ Public Key Extracted in PEM format"
    
    # Step 2: Convert PEM to DER format
    openssl pkey -pubin -inform PEM -in public_key.pem -outform DER -out public_key.der
    echo "✅ Public Key Converted to DER format"
    
    # Step 3: Check ASN.1 structure
    echo "🔍 ASN.1 Structure of Extracted Key:"
    openssl asn1parse -in public_key.der -inform DER
    
    # Step 4: Strip ASN.1 metadata if needed (skip first 24 bytes)
    dd if=public_key.der bs=1 skip=24 of=public_key_stripped.der 2>/dev/null
    echo "✅ ASN.1 Metadata Stripped"
    
    # Step 5: Generate Base64 Output
    BASE64_KEY=$(base64 < public_key_stripped.der)
    
    # Step 6: Generate Hex Dump Output
    HEX_DUMP=$(xxd -p public_key_stripped.der | tr -d '\n')
    
    # Step 7: Compute SHA256 Hash
    SHA256_HASH=$(openssl dgst -sha256 -binary public_key_stripped.der | base64)
    
    # Step 8: Print Results
    echo "🔹 IOS - Extracted Public Key (Base64): $BASE64_KEY"
    echo "🔹 IOS - Extracted Public Key (Hex): $HEX_DUMP"
    echo "🔹 IOS - SHA256 Public Key Hash: $SHA256_HASH"
}

# Execute both extractions
extract_ios
extract_android
