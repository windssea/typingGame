const path=require('node:path'),fs=require('node:fs'),os=require('node:os');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'));
const out=path.resolve(__dirname,'../build/runtime-layout');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-unsafe-swiftshader','--use-angle=swiftshader']});
 const page=await browser.newPage({viewport:{width:1440,height:900}}),checks=[],errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const s=()=>page.evaluate(()=>window.keyboundGame);
 const check=(v,label)=>{if(!v)throw Error(label);checks.push(label);console.log('PASS '+label)};
 try{
  await page.goto('http://127.0.0.1:8765/build/web/index.html?qa=1');
  await page.waitForFunction(()=>window.keyboundGame?.page==='home',null,{timeout:120000});
  for(let i=0;i<5;i++){
   await page.keyboard.press('Tab');await page.keyboard.press('Enter');
   await page.waitForFunction(n=>window.keyboundGame?.focus_name==='WorldPortal'+n,i);
   check((await s()).buttons.filter(b=>b.text==='用本课内容开始').length===2,'world '+i+' filters to two playable games with keyboard');
  }
  await page.keyboard.press('Tab');await page.keyboard.press('Enter');await page.waitForTimeout(220);
  check((await s()).buttons.filter(b=>b.text==='用本课内容开始').length===10,'all games restores ten playable entries');
  for(const [width,height] of [[1440,900],[1024,768],[1280,720],[1920,1080]]){
   await page.setViewportSize({width,height});await page.waitForTimeout(400);
   await page.screenshot({path:path.join(out,`hall-${width}x${height}.png`)});
   check((await s()).viewport.join('x')==='1440x900','reference canvas remains stable at '+width+'x'+height);
  }
  await page.setViewportSize({width:1440,height:900});await page.waitForTimeout(220);
  for(const [index,mode] of [[4,'castle'],[7,'moles'],[8,'racing']]){
   await page.keyboard.press('Enter');await page.waitForTimeout(180);
   const current=await s(), b=current.buttons.filter(b=>b.text==='用本课内容开始')[index];
   for(let i=0;i<45&&(await s()).focus_name!==b.name;i++){await page.keyboard.press('Tab');await page.waitForTimeout(100)}
   await page.keyboard.press('Enter');await page.waitForFunction(m=>window.keyboundGame.run?.mode===m,mode);
   if(mode==='castle'){await page.keyboard.press('q');await page.keyboard.press('n');await page.waitForTimeout(1500)}
   await page.screenshot({path:path.join(out,mode+'.png')});
   await page.keyboard.press('Escape');await page.waitForTimeout(180);await page.keyboard.press('Tab');await page.keyboard.press('Enter');await page.waitForTimeout(180);
   check((await s()).page==='home',mode+' can return to lobby using only keyboard');
  }
  check(errors.length===0,'no runtime errors in final build');
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({checks,errors},null,2));
 }catch(e){await page.screenshot({path:path.join(out,'failure.png')});console.error(await s());throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
