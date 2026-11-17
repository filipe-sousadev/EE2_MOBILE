"""Fetch only the Android pieces needed to export the APK, into app/.android-build/.
- android_release.apk / android_debug.apk from the Godot 4.4.1 export templates (read by HTTP range, no full 1 GB download)
- apksigner.jar from Google's Android build-tools (to sign the APK with a local key)."""
import io, sys, os, urllib.request, zipfile

OUT = sys.argv[1]
TPZ = "https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz"
BT = "https://dl.google.com/android/repository/build-tools_r34-linux.zip"
UA = {"User-Agent": "godot-export-helper"}


class RangeFile(io.RawIOBase):
    def __init__(self, url):
        req = urllib.request.Request(url, method="HEAD", headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r:
            self.url = r.geturl()
            self.size = int(r.headers["Content-Length"])
        self.pos = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else (self.pos + off if whence == 1 else self.size + off)
        return self.pos
    def read(self, n=-1):
        if n is None or n < 0: n = self.size - self.pos
        if n == 0 or self.pos >= self.size: return b""
        end = min(self.size, self.pos + n) - 1
        req = urllib.request.Request(self.url, headers={**UA, "Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req, timeout=300) as r:
            data = r.read()
        self.pos += len(data)
        return data
    def readinto(self, b):
        d = self.read(len(b)); b[:len(d)] = d; return len(d)


def pull(url, wanted):
    zf = zipfile.ZipFile(io.BufferedReader(RangeFile(url), buffer_size=1 << 20))
    names = zf.namelist()
    for w in wanted:
        match = [n for n in names if n.endswith(w)]
        if not match:
            sys.exit(f"{w} not found in {url}")
        dest = os.path.join(OUT, os.path.basename(w))
        if os.path.exists(dest):
            print("have", dest); continue
        with zf.open(match[0]) as src, open(dest, "wb") as dst:
            while True:
                chunk = src.read(4 << 20)
                if not chunk: break
                dst.write(chunk)
        print("got", dest, os.path.getsize(dest))

os.makedirs(OUT, exist_ok=True)
pull(TPZ, ["templates/android_release.apk", "templates/android_debug.apk", "templates/version.txt"])
pull(BT, ["lib/apksigner.jar"])
