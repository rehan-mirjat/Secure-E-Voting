import subprocess
import os

svg_file = 'assets/icon/app_icon.svg'
png_file = 'assets/icon/app_icon.png'

# Using rsvg-convert if available (common on Linux)
try:
    subprocess.run(['rsvg-convert', '-h', '512', svg_file, '-o', png_file], check=True)
    print("Successfully created PNG icon")
except Exception as e:
    print(f"Failed: {e}")
