import os
import zipfile
import zlib

def inspect_svga(filepath):
    try:
        with open(filepath, 'rb') as f:
            data = f.read()
    except Exception as e:
        return f"Error reading: {e}"

    # SVGA files can be a ZIP archive (version 1.x or version 2.0 with ZIP)
    if data[:4] == b'PK\x03\x04':
        try:
            with zipfile.ZipFile(filepath, 'r') as z:
                files = z.namelist()
                audio_files = [x for x in files if x.lower().endswith(('.mp3', '.wav', '.ogg', '.aac', '.m4a'))]
                movie_spec = "movie.spec" in files
                movie_bin = "movie.binary" in files
                bin_has_audio = False
                if movie_bin:
                    bin_data = z.read("movie.binary")
                    if b"audioKey" in bin_data or b"audios" in bin_data:
                        bin_has_audio = True
                return f"[ZIP] audio_files={audio_files}, movie_spec={movie_spec}, movie_bin={movie_bin}, bin_audio={bin_has_audio}"
        except Exception as e:
            return f"[ZIP ERROR] {e}"

    # Or it can be Zlib compressed protobuf (SVGA 2.0 standard)
    try:
        inflated = zlib.decompress(data)
        # Check protobuf fields or audio signatures
        has_audio_field = b"audioKey" in inflated or b"audios" in inflated
        # Check for MP3 ID3 header or sync word
        has_id3 = b"ID3" in inflated
        has_riff = b"RIFF" in inflated
        has_ogg = b"OggS" in inflated
        return f"[ZLIB protobuf] len={len(inflated)}, has_audio_field={has_audio_field}, has_id3={has_id3}, has_riff={has_riff}, has_ogg={has_ogg}"
    except Exception as e:
        return f"[UNKNOWN/UNCOMPRESSED] len={len(data)}, err={e}"

targets = [
    'assets/svga',
    'assets/animations/gifts',
    'assets/SVIP Kit',
    'assets/VIP',
    'assets/Helo chat',
]

for target in targets:
    if not os.path.exists(target):
        continue
    for root, dirs, files in os.walk(target):
        for f in files:
            if f.endswith('.svga'):
                full_path = os.path.join(root, f)
                info = inspect_svga(full_path)
                print(f"{full_path}: {info}")
