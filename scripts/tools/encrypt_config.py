#!/usr/bin/env python3

import os
import sys
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64

def generate_key_from_password(password: str, salt: bytes) -> bytes:
    """Generate a key from password using PBKDF2"""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,
    )
    key = base64.urlsafe_b64encode(kdf.derive(password.encode()))
    return key

def encrypt_file(input_file: str, output_file: str, password: str):
    """Encrypt a file with password"""
    # Generate a random salt
    salt = os.urandom(16)
    
    # Generate key from password
    key = generate_key_from_password(password, salt)
    fernet = Fernet(key)
    
    # Read input file
    with open(input_file, 'rb') as f:
        data = f.read()
    
    # Encrypt data
    encrypted_data = fernet.encrypt(data)
    
    # Write salt + encrypted data to output file
    with open(output_file, 'wb') as f:
        f.write(salt)  # First 16 bytes are salt
        f.write(encrypted_data)
    
    print(f"✅ Encrypted {input_file} -> {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 encrypt_config.py <input_file> <output_file> <password>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    password = sys.argv[3]
    
    if not os.path.exists(input_file):
        print(f"❌ Input file {input_file} does not exist")
        sys.exit(1)
    
    encrypt_file(input_file, output_file, password)