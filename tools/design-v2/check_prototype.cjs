// Local, disposable headless renderer. Never connects to the user's browser profile.
const { chromium } = require('C:/Users/windssea/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const root = path.resolve(__dirname,'../..');
const out = path.join(root,'build/design-v2');
fs.mkdirSync(out,{recursive:true});
(async()=>{
  const browser = await chromium.launch({channel:'msedge',headless:true});
  const page = await browser.newPage({viewport:{width:1440,height:1000},reducedMotion:'reduce'});
  const errors=[],checks=[];
  page.on('pageerror',e=>errors.push(e.message));
  const check=async(name,fn)=>{await fn();checks.push(name)};
  const assert=(value,detail)=>{if(!value)throw new Error(detail)};
  const shot=async name=>page.screenshot({path:path.join(out,name+'.png'),fullPage:true,animations:'disabled'});
  await page.goto(pathToFileURL(path.join(root,'docs/design-v2/index.html')).href);
  await page.locator('[data-action="continue"]').first().waitFor();
  await page.waitForFunction(()=>document.activeElement?.matches('[data-initial]'));
  await check('hall: initial focus, five portals, real art loaded',async()=>{
    assert(await page.locator('.world-card').count()===5,'five worlds');
    assert(await page.locator('.game-tile').count()===2,'two royal games');
    const ok=await page.evaluate(async()=>{const i=new Image();i.src='../../assets/design-v2/five-world-benchmark.png';await i.decode();return i.naturalWidth>1000});assert(ok,'art must decode');
  });
  await shot('01-hall');
  await check('keyboard: continue course, modal focus loop, cancel restores entry',async()=>{
    await page.keyboard.press('Enter');
    await page.locator('[data-action="intro:castle"]').focus();
    await page.keyboard.press('Enter');
    await page.getByRole('dialog').waitFor();
    for(let i=0;i<8;i++)await page.keyboard.press('Tab');
    assert(await page.evaluate(()=>!!document.activeElement.closest('[role=dialog]')),'modal contains focus');
    await page.keyboard.press('Shift+Tab');
    assert(await page.evaluate(()=>!!document.activeElement.closest('[role=dialog]')),'modal contains reverse focus');
    await page.keyboard.press('Escape');
    assert(await page.evaluate(()=>document.activeElement.dataset.action==='intro:castle'),'entry focus restored');
  });
  await check('all ten games and challenge subset',async()=>{
    await page.locator('[data-action="toggleAll"]').click();
    assert(await page.locator('.game-tile').count()===10,'ten games');
    await page.locator('nav [data-page="challenges"]').click();
    assert(await page.locator('.game-tile').count()===8,'eight challenges');
    await page.locator('nav [data-page="lessons"]').click();
    assert(await page.locator('[data-lesson]').count()===10,'ten lesson nodes');
  });
  await shot('02-lessons');
  await check('five skins preserve course layout and semantic states',async()=>{
    await page.locator('footer [data-page="components"]').click();
    for(const id of ['royal_fantasy','sci_fi','modern','ancient','fairytale']){
      await page.locator(`button[data-world="${id}"]`).click();
      assert(await page.locator('.status-sample').count()===6,'six states remain');
      assert(await page.locator('body').getAttribute('data-world')===id,'theme applied');
      await shot('skin-'+id);
    }
  });
  await check('castle: select pad, build, upgrade, repair, begin, type',async()=>{
    await page.locator('nav [data-page="hall"]').click();
    await page.locator('button[data-world="royal_fantasy"]').click();
    await page.locator('[data-action="intro:castle"]').click();
    await page.keyboard.press('Enter');
    await page.locator('.stage').waitFor();
    for(const [width,height] of [[1280,800],[1440,900],[1024,768]]){
      await page.setViewportSize({width,height});
      await page.evaluate(()=>scrollTo(0,0));
      const strip=await page.locator('.target-strip').boundingBox();
      assert(strip.y+strip.height<=height,'critical typing strip below viewport '+width+': '+(strip.y+strip.height));
    }
    await page.setViewportSize({width:1440,height:1000});
    await page.keyboard.press('2');await page.keyboard.press('q');
    assert((await page.locator('.p2').getAttribute('aria-label')).includes('火焰塔'),'keyboard built tower');
    assert(await page.locator('#gold').innerText()==='180','charged once');
    await page.keyboard.press('u');await page.keyboard.press('r');
    assert(await page.locator('#gold').innerText()==='95','upgrade repair');
    await shot('03-castle-build');
    await page.keyboard.press('n');
    assert(await page.locator('.threat').count()===3,'combat state');
    await page.keyboard.press('f');
    assert((await page.locator('#input-status').innerText()).includes('命中 1'),'actual typed key');
    await shot('04-castle-combat');
  });
  await check('guide: keyboard and Shift, pause stack preserved',async()=>{
    await page.keyboard.press('Escape');
    await page.locator('#overlay [data-action="guide"]').click();
    await page.keyboard.press('?');
    assert((await page.locator('#guide-live').innerText()).includes('?'),'guide previews symbol');
    assert((await page.locator('#guide-live .keycap.active').count())>=2,'base and opposite Shift');
    await shot('05-guide');
    await page.keyboard.press('Escape');
    assert((await page.locator('#dialog-title').innerText()).includes('休息'),'returns to pause');
    await page.keyboard.press('Escape');
    assert(await page.getByRole('dialog').count()===0,'resume without extra modal');
  });
  await check('settings: updates do not trap close in repeated modal',async()=>{
    await page.locator('[data-action="settings"]').click();
    await page.locator('[data-action="reduced"]').click();
    await page.locator('#overlay [data-action="sound"]').click();
    await page.keyboard.press('Escape');
    assert(await page.getByRole('dialog').count()===0,'settings closed');
  });
  await check('result: safe return to collection, coherent page',async()=>{
    await page.locator('[data-action="result"]').click();
    await shot('06-result');
    await page.locator('[data-action="leave-confirm"]').click();
    await page.locator('.game-tile').first().waitFor();
  });
  await check('responsive widths and 150% typography: no horizontal page overflow',async()=>{
    await page.locator('nav [data-page="hall"]').click();
    for(const [width,height] of [[1280,800],[1440,900],[1920,1080],[1024,768],[720,1000]]){
      await page.setViewportSize({width,height});
      const sizes=await page.evaluate(()=>[document.documentElement.scrollWidth,innerWidth]);
      assert(sizes[0]<=sizes[1]+1,'horizontal overflow '+width+': '+sizes);
      if(width===1280||width===1024)await shot('hall-'+width);
    }
    await page.setViewportSize({width:1280,height:800});
    await page.locator('[data-action="settings"]').click();
    await page.locator('[data-action="textscale"]').click();await page.locator('[data-action="textscale"]').click();
    await page.keyboard.press('Escape');
    const sizes=await page.evaluate(()=>[document.documentElement.scrollWidth,innerWidth]);
    assert(sizes[0]<=sizes[1]+1,'150 percent page overflow');
    await shot('hall-text150');
  });
  assert(errors.length===0,errors.join('\n'));
  await check('entire primary flow with physical Tab/Enter, including focused modal return',async()=>{
    await page.evaluate(()=>localStorage.removeItem('keybound.designV2'));
    await page.reload();
    const tabTo=async selector=>{
      for(let i=0;i<80;i++){
        if(await page.evaluate(sel=>document.activeElement?.matches(sel),selector))return;
        await page.keyboard.press('Tab');
      }
      throw new Error('keyboard cannot reach '+selector);
    };
    await page.waitForFunction(()=>document.activeElement?.matches('[data-initial]'));
    await page.keyboard.press('Enter');
    await tabTo('[data-action="intro:castle"]');await page.keyboard.press('Enter');
    await page.keyboard.press('Enter');
    await page.locator('.stage').waitFor();
    await page.keyboard.press('q');await page.keyboard.press('n');
    await page.keyboard.press('f');await page.keyboard.press('F1');
    await page.keyboard.press('Escape');await page.keyboard.press('Escape');
    await tabTo('#overlay [data-action="leave"]');await page.keyboard.press('Enter');
    await tabTo('#overlay [data-action="leave-confirm"]');await page.keyboard.press('Enter');
    assert(await page.locator('.game-tile').count()===2,'keyboard-only route returned to collection');
  });
  fs.writeFileSync(path.join(out,'verification.json'),JSON.stringify({date:'2026-10-19',renderer:'headless Microsoft Edge, disposable context',checks,errors},null,2));
  await browser.close();
  console.log(JSON.stringify({checks:checks.length,errors,output:out}));
})().catch(e=>{console.error(e);process.exit(1)});
