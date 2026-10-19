"""Install only official Web template ZIP entries using HTTP ranges and ZIP CRC checks."""
import io
import json
import os
import urllib.request
import zipfile
from pathlib import Path

VERSION = '4.7.2'
URL = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz'

class RemoteArchive(io.RawIOBase):
    def __init__(self):
        with urllib.request.urlopen(urllib.request.Request(URL,method='HEAD'),timeout=45) as head:
            self.size=int(head.headers['Content-Length'])
            self.url=head.url
        request = urllib.request.Request(self.url,headers={'Range':f'bytes={self.size-65536}-{self.size-1}','User-Agent':'Keybound-template-installer'})
        with urllib.request.urlopen(request,timeout=45) as response:
            if response.status!=206:
                raise RuntimeError('Server does not support partial downloads')
            self.url=response.url
            self.size=int(response.headers['Content-Range'].split('/')[-1])
            self.tail=response.read()
        self.pos=0

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self,offset,whence=0):
        self.pos=offset if whence==0 else (self.pos+offset if whence==1 else self.size+offset)
        return self.pos
    def read(self,size=-1):
        size=min(self.size-self.pos,size if size>=0 else self.size-self.pos)
        if size<=0:return b''
        if self.pos>=self.size-len(self.tail):
            result=self.tail[self.pos-(self.size-len(self.tail)):self.pos-(self.size-len(self.tail))+size]
        else:
            request=urllib.request.Request(self.url,headers={'Range':f'bytes={self.pos}-{self.pos+size-1}','User-Agent':'Keybound-template-installer'})
            with urllib.request.urlopen(request,timeout=90) as response:
                if response.status!=206:raise RuntimeError('Range download was not honored')
                result=response.read(size+1)
            if len(result)!=size:raise RuntimeError('Unexpected range length')
        self.pos+=len(result)
        return result

target=Path(os.environ['APPDATA'])/'Godot/export_templates'/f'{VERSION}.stable'
target.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(RemoteArchive()) as archive:
    entries=[info for info in archive.infolist() if Path(info.filename).name.startswith('web') and info.filename.endswith('.zip') or Path(info.filename).name in ['version.txt','icudt_godot.dat']]
    print(json.dumps({'status':'downloading','entries':[i.filename for i in entries],'target':str(target)}),flush=True)
    for info in entries:
        name=Path(info.filename).name
        output=target/name
        if output.exists() and output.stat().st_size==info.file_size:
            continue
        data=archive.read(info) # ZipFile validates each entry CRC before returning.
        if name=='version.txt' and VERSION not in data.decode():raise RuntimeError('Version mismatch')
        temporary=output.with_suffix(output.suffix+'.part')
        temporary.write_bytes(data)
        temporary.replace(output)
        print(json.dumps({'installed':name,'bytes':len(data),'crc_verified':True}),flush=True)
