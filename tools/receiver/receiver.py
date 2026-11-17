# CarMedia PoC receiver (Windows-friendly alternative to receiver.sh).
# Pure Python: listens on :5555 and prints stream stats; with --out writes
# stream.h264 which VLC can open live ("VLC stream.h264").
#
#   python receiver.py --out stream.h264
import argparse, socket, sys, time

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=5555)
    ap.add_argument("--out", default=None, help="write Annex-B stream to file")
    a = ap.parse_args()
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", a.port))
    s.listen(1)
    print(f"listening :{a.port} — start the broadcast in CarMedia", flush=True)
    c, addr = s.accept()
    print("connected from", addr, flush=True)
    total, last, t0 = 0, time.time(), time.time()
    f = open(a.out, "wb") if a.out else None
    while True:
        d = c.recv(65536)
        if not d:
            break
        total += len(d)
        if f:
            f.write(d)
        if time.time() - last > 2:
            print(f"{total/1e6:6.1f} MB  {total/1e6/(time.time()-t0):5.2f} Mbit/s", flush=True)
            last = time.time()
    print("stream ended", flush=True)

if __name__ == "__main__":
    main()
