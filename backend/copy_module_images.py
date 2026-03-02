import os
import shutil

# Run from backend directory
base = os.path.abspath(os.path.dirname(__file__))
src = os.path.abspath(os.path.join(base, '..', 'mobile', 'modules_gps'))
dst = os.path.join(base, 'static', 'modules')

os.makedirs(dst, exist_ok=True)

if not os.path.exists(src):
    print(f"Source folder not found: {src}")
    print("Make sure the mobile/modules_gps folder exists.")
else:
    copied = 0
    for name in os.listdir(src):
        s = os.path.join(src, name)
        d = os.path.join(dst, name)
        if os.path.isfile(s):
            try:
                shutil.copy2(s, d)
                print(f"Copied: {name}")
                copied += 1
            except Exception as e:
                print(f"Failed to copy {name}: {e}")
    print(f"Done. {copied} files copied to {dst}")
