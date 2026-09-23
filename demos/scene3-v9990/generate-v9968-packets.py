"""Generate V9968 R32..R46 packets without modifying shared assets.

Each record is count16 + 15-byte commands, padded to 4096 bytes.
The DY high byte (offset 7) is replaced with the display page at runtime.
Bank 54: identity. Banks 64..127: 256 wave phases. Bank 127 tail: S3WP.
"""
import struct

def generate(source):
    if len(source) != 1048576:
        raise ValueError('Expected the existing 1 MiB shared ROM')
    out = bytearray(source.ljust(2097152, b'\0'))
    counts = []

    def water(old):
        records = []
        y = 0
        for i in range(old[0]):
            sx, dx, width, sy, height = old[1+5*i:6+5*i]
            width = width or 256
            if not (height and y+height <= 192 and sy+height <= 192):
                raise ValueError('Band outside visible source/destination')
            if sx+width > 256 or dx+width > 256 or (sx | dx | width) & 1:
                raise ValueError('HMMM requires even X/width in this 4bpp scene')
            if (sx,dx,width) not in [(0,0,256),(0,2,254),(2,0,254)]:
                raise ValueError('Unsupported edge geometry')
            records.append(struct.pack('<6H3B', sx, 512+sy, dx, y, width, height, 0, 0, 0xd0))
            if sx or dx:
                edge = 0 if dx else 255
                for n in range(2):
                    records.append(struct.pack('<6H3B', edge, 512+sy, n if dx else 254+n, y, 1, height, 0, 0, 0x90))
            y += height
        if y != 192:
            raise ValueError('Bands must cover exactly 192 rows')
        packet = struct.pack('<H', len(records)) + b''.join(records)
        if len(packet) > 4096-16:
            raise ValueError('Packet overlaps record limit / mapper marker')
        return packet.ljust(4096,b'\0'), len(records)

    for phase in range(256):
        start=46*16384+phase*512
        packet,n=water(source[start:start+512])
        dest=64*16384+phase*4096
        out[dest:dest+4096]=packet
        counts.append(n)
    packet,identity_count=water(source[54*16384:54*16384+512])
    out[54*16384:54*16384+4096]=packet
    out[127*16384+0x3ff0:127*16384+0x3ff4]=b'S3WP'
    return bytes(out[16384:]), {'rom_bytes':len(out),'record_bytes':4096,
        'command_bytes':15,'water_commands_min':min(counts),'water_commands_max':max(counts),
        'water_commands_mean':sum(counts)/256,'identity_commands':identity_count,
        'reserved_wave_bytes':1048576,'used_wave_bytes':sum(2+15*n for n in counts)}
