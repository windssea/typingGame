(() => {
 'use strict';
 const publicTitle='指尖挑战 · 打字训练与冒险';
 const title=document.querySelector('title');
 if(title) new MutationObserver(()=>{if(document.title!==publicTitle)document.title=publicTitle;}).observe(title,{childList:true,subtree:true,characterData:true});
 const root=document.getElementById('status');
 if(!root)return;
 const progress=document.getElementById('status-progress');
 const caption=document.getElementById('loading-caption');
 const percent=document.getElementById('loading-percent');
 const notice=document.getElementById('status-notice');
 const retry=document.getElementById('loading-retry');
 const motion=matchMedia('(prefers-reduced-motion: reduce)');
 const actors=[...root.querySelectorAll('.loading-actor')];
 const clips=actors.map(actor=>({actor,sprite:actor.querySelector('.actor-sprite'),name:actor.classList.contains('loading-robot')?'robot':'knight',frames:actor.classList.contains('loading-robot')?36:48,rows:actor.classList.contains('loading-robot')?5:6,frame:-1,ready:false,requested:false}));
 let lastNotice='',frameRequest=0,animationStart=performance.now();
 function text(element,value){if(element.textContent!==value)element.textContent=value;}
 function update(){
  if(notice.style.display==='block'&&notice.textContent.trim()){
   const raw=notice.textContent.trim();
   root.dataset.state='error';text(caption,'加载遇到问题');text(percent,'');retry.hidden=false;
   if(raw!==lastNotice){
    const message=/fetch|network|download|connection/i.test(raw)?'资源连接中断，请检查网络后重试。':/missing|support|webgl|feature/i.test(raw)?'当前浏览器缺少游戏所需功能，请更新浏览器后重试。':'游戏暂时未能启动，请重新加载。';
    lastNotice=message;if(raw!==message)notice.textContent=message;
    retry.focus({preventScroll:true});
   }
   return;
  }
  root.dataset.state='loading';
  if(progress.hasAttribute('value')&&progress.max>0){
   const value=Math.min(100,Math.max(0,Math.floor(progress.value/progress.max*100)));
   text(percent,`${value}%`);text(caption,value===100?'正在启动游戏…':'正在加载冒险…');
  }else{text(percent,'…');text(caption,'正在连接冒险世界…');}
 }
 const observer=new MutationObserver(update);
 observer.observe(progress,{attributes:true,attributeFilter:['value','max','style']});
 observer.observe(notice,{attributes:true,attributeFilter:['style'],childList:true,subtree:true,characterData:true});
 update();
 function animate(now){
  if(!root.isConnected){observer.disconnect();document.removeEventListener('keydown',onKey);return;}
  if(motion.matches||document.hidden){frameRequest=0;return;}
  const tick=Math.floor((now-animationStart)*24/1000);
  clips.forEach(clip=>{
   if(!clip.ready)return;
   const frame=tick%clip.frames;
   if(frame!==clip.frame){clip.sprite.style.backgroundPosition=`${(frame%8)*100/7}% ${Math.floor(frame/8)*100/(clip.rows-1)}%`;clip.frame=frame;}
  });
  frameRequest=requestAnimationFrame(animate);
 }
 function resume(){
  if(motion.matches){cancelAnimationFrame(frameRequest);frameRequest=0;clips.forEach(clip=>{clip.actor.classList.remove('has-motion');clip.sprite.style.backgroundPosition='0% 0%';clip.frame=-1;});}
  else if(root.isConnected&&!document.hidden){
   clips.forEach(clip=>{
    if(clip.ready)clip.actor.classList.add('has-motion');
    if(clip.requested)return;
    clip.requested=true;
    const image=new Image();
    image.onload=()=>{clip.ready=true;clip.frame=-1;if(root.isConnected&&!motion.matches)clip.actor.classList.add('has-motion');};
    image.src=`loading-${clip.name}-v191.webp`;
   });
   if(!frameRequest){animationStart=performance.now();frameRequest=requestAnimationFrame(animate);}
  }
 }
 function greet(actor){
  if(motion.matches)return;
  actor.classList.remove('is-greeting');void actor.offsetWidth;actor.classList.add('is-greeting');
 }
 actors.forEach(actor=>{actor.addEventListener('click',()=>greet(actor));actor.addEventListener('animationend',()=>actor.classList.remove('is-greeting'));});
 retry.addEventListener('click',()=>location.reload());
 function onKey(event){
  if(!root.isConnected){document.removeEventListener('keydown',onKey);return;}
  if(root.dataset.state==='error'&&event.key==='Enter'){event.preventDefault();location.reload();return;}
  if(!event.repeat&&['f','j'].includes(event.key.toLowerCase()))greet(actors[event.key.toLowerCase()==='f'?0:1]);
 }
 document.addEventListener('keydown',onKey);
 document.addEventListener('visibilitychange',resume);
 motion.addEventListener('change',resume);
 const removal=new MutationObserver(()=>{
  if(root.isConnected)return;
  cancelAnimationFrame(frameRequest);observer.disconnect();removal.disconnect();
  document.removeEventListener('keydown',onKey);document.removeEventListener('visibilitychange',resume);motion.removeEventListener('change',resume);
 });
 removal.observe(root.parentNode,{childList:true});
 // Preserve gameplay keyboard shortcuts once the loading scene has gone away.
 addEventListener('keydown',event=>{if(document.activeElement?.id==='canvas'&&['F1','F2','F3','Tab',' '].includes(event.key))event.preventDefault();});
 resume();
})();
