const canvas = document.querySelector('#game');
const ctx = canvas.getContext('2d');
const W = canvas.width, H = canvas.height;
const ui = Object.fromEntries(['time', 'level', 'kills', 'healthBar', 'startOverlay', 'upgradeOverlay', 'gameOverOverlay', 'upgradeChoices', 'finalStats'].map(id => [id, document.getElementById(id)]));
const keys = new Set();
let state, last = 0, touch = null;

const upgrades = [
  { name: '急速分裂', text: '発射間隔 -20%', apply: s => s.fireRate *= .8 },
  { name: '強膜', text: '最大HP +30、回復', apply: s => { s.maxHp += 30; s.hp = Math.min(s.maxHp, s.hp + 30); } },
  { name: '多重核', text: '弾丸 +1', apply: s => s.shots++ },
  { name: '浸透圧加速', text: '移動速度 +18%', apply: s => s.speed *= 1.18 },
  { name: '酵素強化', text: '攻撃力 +45%', apply: s => s.damage *= 1.45 },
  { name: '磁性膜', text: '経験値の回収範囲 +55', apply: s => s.magnet += 55 },
];
function reset() { state = { running:false, paused:false, over:false, player:{x:W/2,y:H/2,r:15}, hp:100,maxHp:100, speed:220, damage:12, fireRate:.48, shots:1, magnet:62, elapsed:0, fire:0, spawn:0, level:1, xp:0, nextXp:7, kills:0, enemies:[], bullets:[], gems:[], particles:[] }; updateUi(); }
function updateUi() { const s=state; ui.time.textContent=`${String(Math.floor(s.elapsed/60)).padStart(2,'0')}:${String(Math.floor(s.elapsed%60)).padStart(2,'0')}`; ui.level.textContent=s.level; ui.kills.textContent=s.kills; ui.healthBar.style.width=`${100*s.hp/s.maxHp}%`; }
function nearestEnemy() { return state.enemies.reduce((best,e) => !best || Math.hypot(e.x-state.player.x,e.y-state.player.y)<Math.hypot(best.x-state.player.x,best.y-state.player.y) ? e : best, null); }
function shoot() { const target=nearestEnemy(); if(!target) return; const p=state.player, base=Math.atan2(target.y-p.y,target.x-p.x); for(let i=0;i<state.shots;i++){ const spread=(i-(state.shots-1)/2)*.18, a=base+spread; state.bullets.push({x:p.x,y:p.y,vx:Math.cos(a)*520,vy:Math.sin(a)*520,r:4,life:1.15}); } }
function spawnEnemy() { const edge=Math.floor(Math.random()*4), pad=28; let x,y; if(edge===0){x=-pad;y=Math.random()*H;} if(edge===1){x=W+pad;y=Math.random()*H;} if(edge===2){x=Math.random()*W;y=-pad;} if(edge===3){x=Math.random()*W;y=H+pad;} const elite=Math.random()<Math.min(.24,state.elapsed/600); const hp=(elite?48:18)*(1+state.elapsed/100); state.enemies.push({x,y,r:elite?17:10,hp,maxHp:hp,speed:(elite?38:58)+state.elapsed*.32,elite,hue:elite?328:Math.random()*30+150}); }
function chooseUpgrades() { state.paused=true; ui.upgradeChoices.innerHTML=''; [...upgrades].sort(()=>Math.random()-.5).slice(0,3).forEach(u=>{ const b=document.createElement('button'); b.className='choice'; b.innerHTML=`<b>${u.name}</b><span>${u.text}</span>`; b.onclick=()=>{u.apply(state); state.paused=false; ui.upgradeOverlay.classList.add('hidden');}; ui.upgradeChoices.append(b); }); ui.upgradeOverlay.classList.remove('hidden'); }
function gainXp(gem) { state.xp++; if(state.xp>=state.nextXp){ state.xp-=state.nextXp; state.level++; state.nextXp=Math.ceil(state.nextXp*1.36+2); chooseUpgrades(); } }
function burst(x,y,color,n=10){ for(let i=0;i<n;i++){const a=Math.random()*Math.PI*2, v=25+Math.random()*110;state.particles.push({x,y,vx:Math.cos(a)*v,vy:Math.sin(a)*v,life:.5+Math.random()*.4,color});} }
function tick(dt) { const s=state,p=s.player; s.elapsed+=dt; s.fire-=dt; s.spawn-=dt; if(s.fire<=0){shoot();s.fire=s.fireRate;} if(s.spawn<=0){spawnEnemy();s.spawn=Math.max(.15,.65-s.elapsed*.006);}
  let dx=(keys.has('ArrowRight')||keys.has('d')?1:0)-(keys.has('ArrowLeft')||keys.has('a')?1:0), dy=(keys.has('ArrowDown')||keys.has('s')?1:0)-(keys.has('ArrowUp')||keys.has('w')?1:0); if(touch){dx=touch.x-p.x;dy=touch.y-p.y;} if(dx||dy){const len=Math.hypot(dx,dy);p.x=Math.max(p.r,Math.min(W-p.r,p.x+dx/len*s.speed*dt));p.y=Math.max(p.r,Math.min(H-p.r,p.y+dy/len*s.speed*dt));}
  s.enemies.forEach(e=>{const a=Math.atan2(p.y-e.y,p.x-e.x),d=Math.hypot(p.x-e.x,p.y-e.y); e.x+=Math.cos(a)*e.speed*dt;e.y+=Math.sin(a)*e.speed*dt;if(d<p.r+e.r){s.hp-=e.elite?16*dt:9*dt;}});
  s.bullets.forEach(b=>{b.x+=b.vx*dt;b.y+=b.vy*dt;b.life-=dt; s.enemies.forEach(e=>{if(!b.hit&&Math.hypot(e.x-b.x,e.y-b.y)<e.r+b.r){b.hit=true;e.hp-=s.damage;burst(b.x,b.y,'#8afbd0',3);}});});
  s.enemies=s.enemies.filter(e=>{if(e.hp>0)return true;s.kills++;s.gems.push({x:e.x,y:e.y,r:5});burst(e.x,e.y,e.elite?'#ff85c8':'#6df6b9',e.elite?18:9);return false;}); s.bullets=s.bullets.filter(b=>b.life>0&&!b.hit);
  s.gems=s.gems.filter(g=>{const d=Math.hypot(p.x-g.x,p.y-g.y);if(d<s.magnet){g.x+=(p.x-g.x)*Math.min(1,dt*7);g.y+=(p.y-g.y)*Math.min(1,dt*7);} if(d<p.r+g.r+3){gainXp(g);return false;}return true;}); s.particles.forEach(q=>{q.x+=q.vx*dt;q.y+=q.vy*dt;q.life-=dt;});s.particles=s.particles.filter(q=>q.life>0); if(s.hp<=0){s.hp=0;s.over=true;s.running=false;ui.finalStats.textContent=`生存時間 ${ui.time.textContent} ／ 排除した細胞 ${s.kills}`;ui.gameOverOverlay.classList.remove('hidden');} updateUi(); }
function draw(){ctx.clearRect(0,0,W,H);ctx.fillStyle='#07191d';ctx.fillRect(0,0,W,H);ctx.strokeStyle='#1a4140';ctx.globalAlpha=.32;for(let x=0;x<W;x+=48){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,H);ctx.stroke();}for(let y=0;y<H;y+=48){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(W,y);ctx.stroke();}ctx.globalAlpha=1; const s=state; s.gems.forEach(g=>{ctx.fillStyle='#74ffd2';ctx.beginPath();ctx.arc(g.x,g.y,g.r,0,7);ctx.fill();});s.bullets.forEach(b=>{ctx.fillStyle='#eaff99';ctx.beginPath();ctx.arc(b.x,b.y,b.r,0,7);ctx.fill();});s.enemies.forEach(e=>{ctx.fillStyle=`hsl(${e.hue} 83% 61%)`;ctx.beginPath();ctx.arc(e.x,e.y,e.r,0,7);ctx.fill();ctx.fillStyle='#07191d';ctx.beginPath();ctx.arc(e.x-3,e.y-2,2,0,7);ctx.arc(e.x+3,e.y-2,2,0,7);ctx.fill();if(e.elite){ctx.fillStyle='#30182a';ctx.fillRect(e.x-e.r,e.y-e.r-8,e.r*2,3);ctx.fillStyle='#ff82c4';ctx.fillRect(e.x-e.r,e.y-e.r-8,e.r*2*(e.hp/e.maxHp),3);}});s.particles.forEach(q=>{ctx.globalAlpha=q.life;ctx.fillStyle=q.color;ctx.fillRect(q.x,q.y,3,3);});ctx.globalAlpha=1; const p=s.player;ctx.fillStyle='#b7ffdd';ctx.beginPath();ctx.arc(p.x,p.y,p.r,0,7);ctx.fill();ctx.strokeStyle='#1b7f70';ctx.lineWidth=3;ctx.beginPath();ctx.arc(p.x,p.y,p.r+4,0,7);ctx.stroke();}
function loop(t){const dt=Math.min(.04,(t-last)/1000||0);last=t;if(state.running&&!state.paused)tick(dt);draw();requestAnimationFrame(loop);}
document.addEventListener('keydown',e=>{keys.add(e.key);if(e.key===' '){state.paused=!state.paused;}});document.addEventListener('keyup',e=>keys.delete(e.key));
function updateTouch(event) { const box=canvas.getBoundingClientRect(); touch={x:(event.clientX-box.left)*W/box.width,y:(event.clientY-box.top)*H/box.height}; }
canvas.addEventListener('pointerdown',event=>{ if(state.running&&!state.paused){canvas.setPointerCapture(event.pointerId);updateTouch(event);} });
canvas.addEventListener('pointermove',event=>{ if(touch) updateTouch(event); });
canvas.addEventListener('pointerup',()=>touch=null); canvas.addEventListener('pointercancel',()=>touch=null);
document.querySelector('#startButton').onclick=()=>{ui.startOverlay.classList.add('hidden');state.running=true;};document.querySelector('#restartButton').onclick=()=>{reset();ui.gameOverOverlay.classList.add('hidden');ui.startOverlay.classList.add('hidden');state.running=true;};document.querySelector('#pauseButton').onclick=()=>{if(state.running)state.paused=!state.paused;};
reset();requestAnimationFrame(loop);
