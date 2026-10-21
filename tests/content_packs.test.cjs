/* Exercise the real downloader against isolated network/cache/engine adapters. */
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const {webcrypto}=require('node:crypto');
const code=fs.readFileSync('web/content-packs.js','utf8');
async function fixture(options={}){
 const payloads={learning:new Uint8Array([1,2,3]),dojo:new Uint8Array([4,5]),castle:new Uint8Array([6,7,8])};
 const packs={};
 for(const [id,bytes] of Object.entries(payloads))packs[id]={url:'https://assets.test/'+id,bytes:bytes.length,sha256:Buffer.from(await webcrypto.subtle.digest('SHA-256',bytes)).toString('hex')};
 const stored=new Map(),requests=[],copies=[],events=[],deleted=[];
 const cache={match:async url=>stored.get(url)?.clone(),put:async(url,response)=>stored.set(url,response),delete:async url=>{deleted.push(url);return stored.delete(url);}};
 const context={window:{keyboundContentManifest:{modes:{dojo:['learning','dojo'],castle:['castle']},packs}},crypto:webcrypto,Response,Uint8Array,Map,DOMException,AbortController,performance,
  caches:{open:async()=>{if(options.noCache)throw Error('quota');return cache;}},
  fetch:async(url,{signal})=>{requests.push(url);if(options.fetch)return options.fetch(url,signal,payloads);if(options.fail)throw Error('offline');return new Response(payloads[url.split('/').pop()]);},
  engine:{copyToFS:(path,bytes)=>copies.push({path,bytes:Array.from(bytes)})}};
 if(options.versionMismatch){context.window.keyboundContentManifest.bootstrap_sha256='new-build';context.window.keyboundBootstrapSHA='old-build';}
 vm.runInNewContext(code,context);
 const api=context.window.keyboundPacks;api.listen((...args)=>events.push(args));
 return {api,packs,payloads,stored,requests,copies,events,deleted,options};
}
test('loads only selected game and shared pack, reuses session bytes',async()=>{
 const f=await fixture();await f.api.request('dojo');
 assert.deepEqual(f.requests.sort(),[f.packs.dojo.url,f.packs.learning.url].sort());
 assert.equal(f.copies.length,2);assert.equal(f.events.at(-1)[2],'ready');
 await f.api.request('dojo');assert.equal(f.requests.length,2);assert.equal(f.copies.length,2);
 await f.api.request('castle');assert.equal(f.requests.length,3);assert.equal(f.copies.length,3);
});

test('mixed bootstrap and manifest versions cannot mount incompatible assets',async()=>{
 const f=await fixture({versionMismatch:true});await f.api.request('castle');
 assert.equal(f.requests.length,0);assert.equal(f.copies.length,0);assert.equal(f.events.at(-1)[2],'error');
});
test('uses verified cache without downloading or retaining gzip headers',async()=>{
 const f=await fixture();for(const id of ['learning','dojo'])f.stored.set(f.packs[id].url,new Response(f.payloads[id]));
 await f.api.request('dojo');assert.equal(f.requests.length,0);assert.equal(f.events.at(-1)[2],'ready');
 assert.equal(f.stored.get(f.packs.dojo.url).headers.get('Content-Encoding'),null);
});
test('repairs corrupt cached bytes and validates network checksum',async()=>{
 const f=await fixture();f.stored.set(f.packs.castle.url,new Response(new Uint8Array([9,9,9])));
 await f.api.request('castle');assert.deepEqual(f.deleted,[f.packs.castle.url]);assert.equal(f.requests.length,1);assert.equal(f.events.at(-1)[2],'ready');
 const bad=await fixture({fetch:async()=>new Response(new Uint8Array([0,0,0]))});
 await bad.api.request('castle');assert.equal(bad.copies.length,0);assert.equal(bad.events.at(-1)[2],'error');
});
test('offline retry succeeds and unavailable cache does not block play',async()=>{
 const f=await fixture({fail:true,noCache:true});await f.api.request('castle');assert.equal(f.events.at(-1)[2],'error');
 f.options.fail=false;await f.api.request('castle');assert.equal(f.events.at(-1)[2],'ready');
});
test('cancel aborts download, emits no late ready and permits new request',async()=>{
 let started;const begun=new Promise(resolve=>started=resolve);
 const f=await fixture({fetch:async(url,signal,payloads)=>{
  if(url.endsWith('/castle')){started();return new Promise((resolve,reject)=>signal.addEventListener('abort',()=>reject(new DOMException('cancelled','AbortError'))));}
  return new Response(payloads[url.split('/').pop()]);
 }});
 const pending=f.api.request('castle');await begun;f.api.cancel();await pending;
 assert.equal(f.events.some(event=>event[2]==='ready'),false);
 await f.api.request('dojo');assert.equal(f.events.at(-1)[0],'dojo');assert.equal(f.events.at(-1)[2],'ready');
});
