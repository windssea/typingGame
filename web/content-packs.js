/* Game packs are fetched on demand, verified, cached independently, then mounted by Godot. */
(() => {
 'use strict';
 const manifest=window.keyboundContentManifest;
 if(!manifest)return;
 const session=new Map();
 let listener=null,controller=null,serial=0;
 const emit=(mode,value,status,payload='')=>listener?.(mode,value,status,payload);
 async function loadPack(id,signal,progress){
  const item=manifest.packs[id];
  if(!item)throw new Error('Unknown pack: '+id);
  if(session.has(id)){progress(item.bytes);return session.get(id);}
  let cache=null,response=null;
  try{cache=await caches.open('keybound-content-v1');response=await cache.match(item.url);}catch{}
  const fromCache=!!response;
  async function readAndVerify(response){
  if(!response.ok)throw new Error('Pack HTTP '+response.status);
  const parts=[];let length=0;
  const reader=response.body.getReader();
  try{
   while(true){
    if(signal.aborted)throw new DOMException('Cancelled','AbortError');
    const chunk=await reader.read();if(chunk.done)break;
    parts.push(chunk.value);length+=chunk.value.length;progress(length);
   }
  }finally{reader.releaseLock();}
  if(length!==item.bytes)throw new Error('Incomplete pack');
  const bytes=new Uint8Array(length);let offset=0;
  for(const part of parts){bytes.set(part,offset);offset+=part.length;}
  parts.length=0;
  const digest=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(v=>v.toString(16).padStart(2,'0')).join('');
  if(digest!==item.sha256)throw new Error('Pack checksum mismatch');
  return bytes;
  }
  let bytes;
  try{bytes=await readAndVerify(response||await fetch(item.url,{signal,mode:'cors',credentials:'omit'}));}
  catch(error){
   if(!fromCache||signal.aborted)throw error;
   // Repair only this game's invalid cached entry; saves and other caches are untouched.
   try{await cache.delete(item.url);}catch{}
   progress(0);
   bytes=await readAndVerify(await fetch(item.url,{signal,mode:'cors',credentials:'omit'}));
  }
  if(signal.aborted)throw new DOMException('Cancelled','AbortError');
  // Cache the decoded bytes, without copying the transport Content-Encoding header.
  if(cache)cache.put(item.url,new Response(bytes,{headers:{'Content-Type':'application/octet-stream'}})).catch(()=>{});
  const path='/keybound-pack-'+item.sha256.slice(0,20)+'.pck';
  engine.copyToFS(path,bytes);
  session.set(id,path);
  return path;
 }
 window.keyboundPacks={
  listen(callback){listener=callback;},
  cancel(){serial++;controller?.abort();controller=null;},
  async request(mode){
   this.cancel();const ticket=serial;controller=new AbortController();const signal=controller.signal;
   const ids=manifest.modes[mode];
   if(!ids){emit(mode,0,'error','Unknown mode');return;}
   const total=ids.reduce((sum,id)=>sum+manifest.packs[id].bytes,0),received=new Map();let lastEmit=0;
   emit(mode,0,'loading');
   try{
    const paths=await Promise.all(ids.map(id=>loadPack(id,signal,count=>{
     if(ticket!==serial)return;
     received.set(id,count);
     const current=[...received.values()].reduce((a,b)=>a+b,0);
     const now=performance.now();
     if(now-lastEmit>=50||current===total){lastEmit=now;emit(mode,Math.min(1,current/total),current===total?'verify':'loading');}
    })));
    if(ticket===serial)emit(mode,1,'ready',JSON.stringify(paths));
   }catch(error){if(ticket===serial&&error.name!=='AbortError'){controller.abort();emit(mode,0,'error',String(error));}}
  }
 };
})();
