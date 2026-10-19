// Disposable browser regression. State observation is read-only; all input uses keyboard.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'));
const out=path.resolve(__dirname,'../build/web-v08-qa');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-unsafe-swiftshader','--use-angle=swiftshader']});
 const page=await browser.newPage({viewport:{width:1440,height:900}}),checks=[],errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const state=()=>page.evaluate(()=>JSON.parse(document.documentElement.getAttribute('data-keybound-state')||'null'));
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);console.log('PASS '+label)};
 const activate=async name=>{
  for(let i=0;i<45&&(await state()).focus_name!==name;i++){await page.keyboard.press('Tab');await page.waitForTimeout(110)}
  check((await state()).focus_name===name,'keyboard reaches '+name);
  await page.keyboard.press('Enter');await page.waitForTimeout(180);
 };
 const hit=async()=>{
  await page.waitForFunction(()=>window.keyboundGame?.run?.targets.length>0);
  const s=await state(),t=s.run.targets.find(t=>t.id===s.run.recommended);
  await page.keyboard.type(t.word.slice(t.typed),{delay:25});
  await page.waitForFunction(n=>window.keyboundGame.run.correct>n,s.run.correct);
 };
 const home=async()=>{
  let s=await state();
  if(s.run&&!s.run.done&&!s.overlay){await page.keyboard.press('Escape');await page.waitForTimeout(160)}
  s=await state();
  if(s.run?.done){await page.keyboard.press('Escape');await page.waitForTimeout(160)}
  else if(s.overlay)await activate(s.buttons.find(b=>b.text==='返回训练与挑战').name);
 };
 try{
  const base=process.env.KEYBOUND_URL||'http://127.0.0.1:8765/build/web/index.html';
  await page.goto(base+(base.includes('?')?'&':'?')+'qa=1&qa_profile=1');
  await page.waitForFunction(()=>window.keyboundGame?.page==='home',null,{timeout:120000});
  const s=await state();
  check(s.buttons.some(b=>b.name==='StartTraining')&&s.buttons.some(b=>b.name==='StartChallenge'),'two clear entry paths');
  check(!s.buttons.some(b=>/游戏集合|玩法图鉴|全部十款/.test(b.text)),'no gallery or encyclopedia');
  for(const [width,height] of [[1440,900],[1024,768],[1280,720],[1920,1080]]){
   await page.setViewportSize({width,height});await page.waitForTimeout(300);
   check((await state()).viewport.join('x')==='1440x900','stable reference canvas '+width+'x'+height);
   await page.screenshot({path:path.join(out,`home-${width}x${height}.png`)});
  }
  await page.setViewportSize({width:1440,height:900});
  if(!process.env.KEYBOUND_LAYOUT_ONLY){
   await activate('StartTraining');
   check((await state()).run.mode==='moles'&&(await state()).run.goal===18,'direct short first mission');
   for(let i=0;i<3;i++)await hit();
   check((await state()).run.skill_charge===3,'real words charge ability');
   await page.keyboard.press('F3');await page.waitForTimeout(180);
   check((await state()).run.skill_uses===1&&(await state()).run.skill_time>0,'browser F3 activates earned focus');
   while(!(await state()).run.done)await hit();
   check((await state()).run.won&&(await state()).profile.completed.home_index,'actual input earns mastery');
   const xp=(await state()).profile.xp;
   await page.waitForTimeout(1300);await page.reload();
   await page.waitForFunction(()=>window.keyboundGame?.page==='home',null,{timeout:120000});
   check((await state()).profile.xp===xp&&xp>0,'save survives reload');
   for(const mode of ['aliens','racing','fighter','balloons']){
    await home();await activate('ChallengeNav');await activate('Mission_'+mode);
    for(let i=0;i<3;i++)await hit();
    await page.keyboard.press('F3');await page.waitForTimeout(180);
    check((await state()).run.skill_uses===1,'actual keyboard ability: '+mode);
    await page.screenshot({path:path.join(out,mode+'.png')});
   }
  }
  check(errors.length===0,'no runtime errors');
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({checks,errors},null,2));
 }catch(e){await page.screenshot({path:path.join(out,'failure.png')});throw e}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
