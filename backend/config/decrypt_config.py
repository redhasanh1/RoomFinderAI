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

def decrypt_file(input_file: str, output_file: str, password: str):
    """Decrypt a file with password"""
    # Read encrypted file
    with open(input_file, 'rb') as f:
        salt = f.read(16)  # First 16 bytes are salt
        encrypted_data = f.read()
    
    # Generate key from password
    key = generate_key_from_password(password, salt)
    fernet = Fernet(key)
    
    try:
        # Decrypt data
        decrypted_data = fernet.decrypt(encrypted_data)
        
        # Write decrypted data to output file
        with open(output_file, 'wb') as f:
            f.write(decrypted_data)
        
        print(f"✅ Decrypted {input_file} -> {output_file}")
        
    except Exception as e:
        print(f"❌ Decryption failed: {str(e)}")
        print("Check your password and try again.")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 decrypt_config.py <encrypted_file> <output_file> <password>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    password = sys.argv[3]
    
    if not os.path.exists(input_file):
        print(f"❌ Encrypted file {input_file} does not exist")
        sys.exit(1)
    
    decrypt_file(input_file, output_file, password)