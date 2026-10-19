// Runs the exported Godot/Wasm game in a disposable Edge profile.
// The optional QA bridge observes state only. All actions are real browser inputs.
const fs=require('node:fs'), path=require('node:path'), os=require('node:os');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE||path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'));
const out=path.resolve(__dirname,'../build/runtime-qa');
fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true,args:['--enable-unsafe-swiftshader','--use-angle=swiftshader']});
 const context=await browser.newContext({viewport:{width:1440,height:900}});
 const page=await context.newPage(), errors=[], checks=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.keyboundGame);
 const wait=async(fn)=>page.waitForFunction(fn,null,{timeout:20000});
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);console.log('PASS '+label);};
 const shot=name=>page.screenshot({path:path.join(out,name+'.png')});
 const click=async(text,index=0)=>{
  const s=await state(), b=s.buttons.filter(x=>x.text===text&&!x.disabled)[index];
  if(!b)throw Error('Missing button '+text+'; '+s.buttons.map(x=>x.text).join(' | '));
  if(text==='用本课内容开始'||text==='开始挑战  →'){
   for(let i=0;i<50&&(await state()).focus_name!==b.name;i++){
    await page.keyboard.press('Tab');await page.waitForTimeout(105);
   }
   if((await state()).focus_name!==b.name)throw Error('Unreachable keyboard focus '+b.name);
   await page.keyboard.press('Enter');await page.waitForTimeout(180);return;
  }
  const c=await page.locator('#canvas').boundingBox();
  await page.mouse.click(c.x+(b.rect[0]+b.rect[2]/2)*c.width/s.viewport[0],c.y+(b.rect[1]+b.rect[3]/2)*c.height/s.viewport[1]);
  await page.waitForTimeout(180);
 };
 const hit=async()=>{
  await wait(()=>window.keyboundGame?.run?.targets.length>0);
  const s=await state(), t=s.run.targets[0], before=s.run.correct;
  await page.keyboard.type(t.word.slice(t.typed),{delay:45});
  await page.waitForFunction(n=>window.keyboundGame.run.correct>n,before,{timeout:5000});
  await page.waitForTimeout(100);
 };
 const complete=async label=>{
  for(let i=0;i<45&&!(await state()).run.done;i++)await hit();
  check((await state()).run.done&&(await state()).run.won,label+' completes through keyboard gameplay');
 };
 const home=async()=>{
  let s=await state();
  if(s.run&&!s.run.done&&!s.overlay){await page.keyboard.press('Escape');await page.waitForTimeout(160);}
  s=await state();
  if(s.overlay)await click('返回大厅');
  else if(s.page!=='home')await click('游戏集合');
  await wait(()=>window.keyboundGame.page==='home');
 };
 const start=async(mode,challenge=false)=>{
  await home();
  if(challenge){await click('打字挑战');await click('开始挑战  →',mode);}
  else {
   await click('全部十款游戏');
   await click('用本课内容开始',mode);
  }
  await wait(()=>!!window.keyboundGame.run);
 };
 try{
  await page.goto('http://127.0.0.1:8765/build/web/index.html?qa=1');
  await page.waitForFunction(()=>window.keyboundGame?.page==='home',null,{timeout:120000});
  console.log('BOOT '+JSON.stringify(await state()));
  check((await state()).buttons.filter(x=>x.name.startsWith('WorldPortal')).length===5,'Wasm game boots with five world portals');
  await shot('01-hall');
  await page.keyboard.press('Enter');await page.waitForTimeout(200);
  check((await state()).page==='training_games','Enter opens actual training game selection');
  await click('用本课内容开始',0);
  await wait(()=>window.keyboundGame.run?.mode==='dojo');
  await page.keyboard.press('x');await page.waitForTimeout(160);
  check((await state()).run.attempts===1&&(await state()).run.correct===0,'wrong key records an actual mistake');
  await hit();
  check((await state()).run.kills===1,'correct key defeats practice target');
  await page.keyboard.press('Escape');await page.waitForTimeout(160);
  const pauseTime=(await state()).run.elapsed;
  await page.waitForTimeout(400);
  check((await state()).run.paused&&Math.abs((await state()).run.elapsed-pauseTime)<0.05,'pause stops gameplay clock');
  await page.keyboard.press('F1');await page.waitForTimeout(180);
  const attempts=(await state()).run.attempts;
  await page.keyboard.press('f');await page.waitForTimeout(160);
  check((await state()).run.attempts===attempts,'finger guide blocks battle typing');
  await shot('02-finger-guide');
  await page.keyboard.press('Escape');await page.waitForTimeout(160);
  check((await state()).run.paused&&(await state()).overlay,'guide returns to previous pause menu');
  await page.keyboard.press('Escape');await page.waitForTimeout(160);
  for(let i=0;i<30&&!(await state()).run.done;i++)await hit();
  check((await state()).run.done&&(await state()).run.won,'typing completes and wins a real practice round');
  await shot('03-practice-win');
  const saved=(await state()).profile.xp;
  await page.waitForTimeout(1200);
  await page.reload();await page.waitForFunction(()=>window.keyboundGame?.page==='home',null,{timeout:120000});
  check(saved>0&&(await state()).profile.xp===saved,'IndexedDB progress survives browser reload');
  console.log('SAVED '+JSON.stringify((await state()).profile));
  await start(5);await hit();check((await state()).run.mode==='balloons'&&(await state()).run.kills===1,'balloon pops from typed input');await shot('04-balloons');await complete('balloons');
  await start(6);await hit();await hit();await hit();check((await state()).run.shield===52,'alien combat combo recharges shield');await shot('05-aliens');await complete('aliens');
  await start(7);await hit();check((await state()).run.kills===1,'mole is hit by its letter');await shot('06-moles');await complete('moles');
  await start(8);await hit();check((await state()).run.distance>0,'typing moves racing car');await shot('07-racing');await complete('racing');
  await start(9);await hit();check((await state()).run.enemy_hp===75,'typing lands fighter damage');await shot('08-fighter');await complete('fighter');
  await start(1);await complete('bubbles');
  await start(2);await wait(()=>window.keyboundGame.run.targets.length>0);
  const y=(await state()).run.targets[0].position[1];await page.waitForTimeout(650);
  check((await state()).run.targets[0].position[1]>y,'falling letters move with the real game clock');await hit();
  await start(3);await hit();check((await state()).run.mode==='sprint'&&(await state()).run.correct>0,'timed sprint accepts real typed letters');
  await start(4);
  await page.keyboard.press('q');await page.waitForTimeout(180);
  check((await state()).run.towers===1&&(await state()).run.gold===50,'castle keyboard builds tower and deducts gold');
  await page.keyboard.press('2');await page.keyboard.press('w');await page.waitForTimeout(180);
  check((await state()).run.towers===1&&(await state()).run.gold===50,'castle refuses unaffordable tower');
  await page.keyboard.press('n');await page.waitForTimeout(180);
  check((await state()).run.phase==='assault','castle starts a real enemy wave');
  await hit();check((await state()).run.words_completed>0,'castle spell damages moving enemy from typed word');
  await wait(()=>window.keyboundGame.run.targets.length>0);
  await shot('09-castle-combat');
  const waveDeadline=Date.now()+45000;
  while((await state()).run.phase==='assault'&&Date.now()<waveDeadline){
   if((await state()).run.targets.length)await hit();else await page.waitForTimeout(200);
  }
  check((await state()).run.phase==='build'&&(await state()).run.wave===2,'castle clears first wave and returns to construction');
  const beforeUpgrade=(await state()).run.gold;
  await page.keyboard.press('1');await page.keyboard.press('u');await page.waitForTimeout(180);
  check((await state()).run.gold===beforeUpgrade-65,'earned gold buys a real tower upgrade between waves');
  await shot('10-castle-upgrade');
  await start(7,true);
  await page.waitForFunction(()=>window.keyboundGame.run.done,null,{timeout:45000});
  check(!(await state()).run.won&&(await state()).run.hp===0,'missing attacks loses a real fighter challenge');await shot('11-challenge-loss');
  await home();
  await click('学习档案');
  const downloading=page.waitForEvent('download');await click('导出存档备份');
  const download=await downloading;const downloaded=JSON.parse(fs.readFileSync(await download.path(),'utf8'));
  check(downloaded.version===1&&downloaded.xp===(await state()).profile.xp,'browser downloads a valid save backup');
  await home();
  check(errors.length===0,'browser has no runtime errors');
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({checks,errors,savedProfile:(await state()).profile},null,2));
 }catch(e){await shot('failure');fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:String(e),state:await state(),errors,checks},null,2));throw e;}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
