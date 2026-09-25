import json
import argparse
import os
import re
import shutil
import subprocess
import sys
from contextlib import chdir
from hashlib import sha256
from pathlib import Path

parser = argparse.ArgumentParser(description="Build script.")
parser.add_argument("--z88dk", required=False, help="Path to z88dk")
parser.add_argument("--diagnostic", action="store_true", help="enable diagnostic mode")
parser.add_argument("--cstream", action="store_true", help="cstream mode active")
parser.add_argument("--meshobj", type=str, default="", help="mesh object path")
parser.add_argument("--meshradius", type=float, help="numeric radius for the mesh")
parser.add_argument("--profile-filter", type=str, default="", help="Regex pattern to filter profiles")

args = parser.parse_args()
profiles = [p for p in ["external-0x88", "internal-0x98"]
            if not args.profile_filter or re.search(args.profile_filter, p)]
if not profiles:
    parser.error("No profiles match --profile-filter. Use internal-0x98 or external-0x88.")

ps_script_root = Path(__file__).parent.resolve()

if args.z88dk:
    z88dk_path = Path(args.z88dk).resolve()
    zcc_binary = Path(z88dk_path / "bin" / "zcc")
else:
    zcc_binary = os.environ.get('ZCC') or shutil.which('zcc')
    if not zcc_binary:
        sys.exit(f"Error: unable to determine z88dk zcc location")
    zcc_binary = Path(zcc_binary)
    z88dk_path = Path(zcc_binary).resolve().parents[1]

if not zcc_binary.exists():
    sys.exit(f"Error: z88dk zcc {zcc_binary} not found")

def run_command(cmd_args, error_msg):
    result = subprocess.run(cmd_args)
    if result.returncode != 0:
        sys.exit(f"Error: {error_msg}")

print(f"\n-- Preparing assets ".ljust(80, "-"))

run_command([sys.executable, str(ps_script_root / "generate-fonts.py")], "Font generation failed")
megarom_cmd = [sys.executable, str(ps_script_root / "generate-megarom.py")]
if args.meshradius is not None:
    radius_str = f"{args.meshradius:.6f}".rstrip('0').rstrip('.')
    megarom_cmd.extend(["--mesh-radius", radius_str])
if args.meshobj:
    megarom_cmd.extend(["--mesh-obj", args.meshobj])

run_command(megarom_cmd, "ROM data generation failed")

# Ejecución del nuevo script de verificación de modelo de agua
run_command([sys.executable, str(ps_script_root / "verify-water-model.py")], "Water model verification failed")
run_command([sys.executable, str(ps_script_root / "verify-shallow.py")], "Shallow model verification failed")

out_dirname = "build-c" if args.cstream else "build"
out_dir = ps_script_root / out_dirname
out_dir.mkdir(parents=True, exist_ok=True)

for ext in ("*.c", "*.h"):
    for f in ps_script_root.glob(ext):
        shutil.copy(f, out_dir / f.name)

shutil.copy(ps_script_root / "runtime-math.asm", out_dir / "runtime-math.asm")
shutil.copy(ps_script_root / "assets" / "bank-layout.h", out_dir / "bank-layout.h")

old_path = os.environ.get("PATH", "")
old_zcccfg = os.environ.get("ZCCCFG", "")

try:
    os.environ["PATH"] = f"{z88dk_path}:{z88dk_path}/bin:{old_path}"
    os.environ["ZCCCFG"] = str(z88dk_path / "lib" / "config")

    with chdir(out_dir):

        for profile in profiles:

            extra_args = []
            if args.cstream:
                extra_args.append("-DV9968_SCENE3_C_STREAM")
            if args.diagnostic:
                extra_args.append("-DV9968_DEMO_DIAGNOSTIC")

            if profile == 'external-0x88':
                extra_args.append("-DVDP_BASE=136") # decimal to please asm section
            else:
                extra_args.append("-DVDP_BASE=152")

            name = f"V9968-TECH-DEMO-{profile}"
            if args.diagnostic:
                name = f"{name}-DIAGNOSTIC"

            print(f"\n-- Building profile {profile} ".ljust(80, "-"))

            rom_layout = json.loads((ps_script_root / "assets/bank-layout.json").read_text())
            rom_bytes = rom_layout["summary"]["rom_bytes"]
            extra_args.append(f"-DDEMO_SIGNATURE_BANK={rom_layout['summary']['rom_banks']-1}")
            compilation_cmd = [
                str(zcc_binary), "+msx", "-subtype=rom", "-compiler=sdcc", "-SO3",
                "--max-allocs-per-node20000"
            ] + extra_args + [
                "-create-app", "main.c", "v9968.c", "music.c", "runtime-math.asm",
                "mapper.c", "platform.c", "-o", name, "-m", "--list"
            ]

            res = subprocess.run(compilation_cmd)
            if res.returncode != 0:
                sys.exit("Error: demo compilation failed")

            map_path = Path(f"{name}.map")
            map_text = map_path.read_text(encoding="utf-8", errors="ignore")

            match = re.search(r"__BSS_END_tail\s*=\s*\$([0-9A-Fa-f]+)", map_text)
            if not match:
                sys.exit("Error: BSS bound missing")

            bss_end_val = int(match.group(1), 16)
            if bss_end_val > 0xcf00:
                sys.exit("Error: BSS overlaps reserved memory")

            rom_path = Path(f"{name}.rom")
            fixed_bank = rom_path.read_bytes()
            if len(fixed_bank) > 16384:
                sys.exit("Error: fixed bank exceeds 16 KiB")

            payload_path = ps_script_root / "assets" / "megarom-data.bin"
            payload = payload_path.read_bytes()
            if len(payload) != rom_bytes-16384:
                sys.exit("Error: wrong payload size")

            rom_buffer = bytearray(rom_bytes)
            rom_buffer[0:len(fixed_bank)] = fixed_bank
            rom_buffer[16384:16384 + len(payload)] = payload

            rom_path.write_bytes(rom_buffer)

            if not args.diagnostic and not args.cstream:
                shutil.copy(rom_path, ps_script_root / f"{name}.rom")

            if profile == "internal-0x98":
                compat = "V9968-TECH-DEMO-DIAGNOSTIC" if args.diagnostic else "V9968-TECH-DEMO"
                shutil.copy(rom_path, out_dir / f"{compat}.rom")
                shutil.copy(map_path, out_dir / f"{compat}.map")
                if not args.diagnostic and not args.cstream:
                    shutil.copy(rom_path, ps_script_root / "V9968-TECH-DEMO.rom")

            sha256_hash = sha256(rom_buffer).hexdigest()
            print(f"\nSHA256 hash of {name}.rom: {sha256_hash.upper()}")

finally:
    os.environ["PATH"] = old_path
    if old_zcccfg:
        os.environ["ZCCCFG"] = old_zcccfg
    elif "ZCCCFG" in os.environ:
        del os.environ["ZCCCFG"]

