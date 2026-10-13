import zlib
import os

files = [
    'assets/animations/gifts/Love You.svga',
    'assets/animations/gifts/138.svga',
    'assets/svga/235.svga',
    'assets/svga/100_optimized.svga',
    'assets/svga/mystic_rings.svga',
    'assets/svga/cat_gift.svga',
]

for f in files:
    if os.path.exists(f):
        print(f"=== {f} ===")
        with open(f, 'rb') as fp:
            data = fp.read()
        try:
            decomp = zlib.decompress(data)
            print(f"  Decompressed size: {len(decomp)} bytes")
            # Look for magic bytes or audio signatures
            # Check for mp3 / m4a / ogg / wav magic bytes
            # MP3 sync: 0xFF 0xFB, 0xFF 0xF3, 0xFF 0xF2 or ID3
            # AAC: 0xFF 0xF1 or 0xFF 0xF9
            # OGG: OggS
            # RIFF: RIFF....WAVE
            if b'ID3' in decomp:
                print("  Contains 'ID3'")
            if b'OggS' in decomp:
                print("  Contains 'OggS'")
            if b'RIFF' in decomp:
                print("  Contains 'RIFF'")
            # Look for mp3, m4a, audio strings in protobuf
            import re
            strings = re.findall(rb'[a-zA-Z0-9_\-\.]{4,}', decomp)
            audio_strings = [s.decode(errors='ignore') for s in strings if any(x in s.lower() for x in [b'audio', b'mp3', b'sound', b'm4a', b'wav', b'aac'])]
            print(f"  Audio-related strings: {audio_strings[:10]}")
        except Exception as e:
            print(f"  Error: {e}")
