"""Build V9990 C command packets from the unchanged shared ROM.
Mesh: count16 + 10-byte records (R36..43, R48..49), bbox at4092.
Water: count16 + 12-byte records R32..43, DY high patched at runtime.
Banks10..41 replace mesh only in C. Banks64..127 contain water packets.
No source assets or A/B binaries are modified.
"""
import struct

def generate(source):
 out=bytearray(source.ljust(2097152,b"\0"));counts=[];water_counts=[]
 for pose in range(128):
  pos=10*16384+pose*4096;old=source[pos:pos+4096];n=int.from_bytes(old[:2],'little');packet=bytearray(old[:2])
  for i in range(n):
   q=old[2+11*i:13+11*i];x,y,w,h=struct.unpack('<4H',q[:8]);c=q[8]*17
   packet+=struct.pack('<4H2B',x,y+512,w,h,c,c)
  assert len(packet)<=4092;out[pos:pos+4096]=packet.ljust(4092,b"\0")+old[4092:];counts.append(n)
 def water(old):
  records=[];y=0
  for i in range(old[0]):
   sx,dx,w,sy,h=old[1+i*5:6+i*5];w=w or 256
   records.append(struct.pack('<6H',sx,512+sy,dx,y,w,h))
   if sx or dx:
    for edge in range(2):records.append(struct.pack('<6H',0 if dx else 255,512+sy,edge if dx else 254+edge,y,1,h))
   y+=h
  assert y==192
  packet=struct.pack('<H',len(records))+b''.join(records);assert len(packet)<=4096
  return packet.ljust(4096,b"\0"),len(records)
 for phase in range(256):
  packet,n=water(source[46*16384+phase*512:46*16384+(phase+1)*512]);pos=64*16384+phase*4096;out[pos:pos+4096]=packet;water_counts.append(n)
 packet,_=water(source[54*16384:54*16384+512]);out[54*16384:54*16384+4096]=packet
 out[127*16384+0x3ff0:127*16384+0x3ff4]=b'S3CP' # unused padding after phase255
 return bytes(out[16384:]),{'mesh_commands_min':min(counts),'mesh_commands_max':max(counts),'mesh_commands_mean':sum(counts)/128,'water_commands_min':min(water_counts),'water_commands_max':max(water_counts),'water_commands_mean':sum(water_counts)/256,'rom_bytes':len(out),'new_water_packet_bytes':1048576,'mesh_record_bytes':10,'water_record_bytes':12}
