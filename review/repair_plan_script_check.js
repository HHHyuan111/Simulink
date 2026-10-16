
(() => {
  const root=document.getElementById('pmsm-repair-plan');
  const container=root.querySelector('.pmsm-diagram');
  const detail=root.querySelector('.pmsm-selected');
  const nodes=[
    {id:'command',name:'给定',category:4,detail:'真实速度与 id 给定；母线和负载就近接入对应模块。'},
    {id:'speed',name:'速度环',category:1,detail:'原速度 PI 与换算保留；随后统一电流 A / 转矩 N·m 的输出口径。'},
    {id:'current',name:'电流环',category:1,detail:'d / q 两行对齐，包含原 PI 与前馈；后续核查限幅与解耦。'},
    {id:'ipark',name:'逆Park',category:1,detail:'vd / vq → vα / vβ；电角度 θe 使用清楚的端口连接。'},
    {id:'svpwm',name:'SVPWM',category:1,detail:'原扇区算法与 PWM 比较保留；专项修复超限时的时间归一化。'},
    {id:'bridge',name:'逆变器',category:2,detail:'六路门极与母线 → 三相电压；内部保留现有开关模型。'},
    {id:'motor',name:'PMSM',category:2,detail:'三相电压与负载 → 电流、转速和角度；后续接入实际电机参数。'},
    {id:'feedback',name:'采样反馈',category:3,detail:'集中采样、角度换算和 Clarke / Park，分路返回速度、电流与角度。'},
    {id:'observe',name:'数据观测',category:4,detail:'内部按速度、电流、电压、PWM 分组；主给定与辅助 Chirp 明确区分。'}
  ];
  let selected='current';
  const saved=window.openai?.widgetState?.modelContent?.selected;
  if(nodes.some(n=>n.id===saved))selected=saved;
  function select(id,save){
    selected=id;
    const n=nodes.find(n=>n.id===id);
    detail.textContent=n.name+'：'+n.detail;
    container.querySelectorAll('button[data-node]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.node===id)));
    if(save && window.openai?.setWidgetState)window.openai.setWidgetState({modelContent:{selected:id},privateContent:null}).catch(()=>{});
  }
  function draw(){
    const width=Math.max(280,Math.round(container.getBoundingClientRect().width));
    const wide=width>=650, p={}, head=24, boxH=60;
    let height;
    if(wide){
      const gap=17,boxW=(width-24-6*gap)/7;
      nodes.slice(0,7).forEach((n,i)=>p[n.id]={x:12+i*(boxW+gap),y:head,w:boxW,h:boxH});
      p.feedback={x:width-153,y:149,w:140,h:60};
      p.observe={x:width/2-95,y:316,w:190,h:60};
      height=392;
    }else{
      const boxW=Math.min(180,width-118);
      nodes.slice(0,7).forEach((n,i)=>p[n.id]={x:12,y:12+i*77,w:boxW,h:60});
      p.feedback={x:12,y:12+7*77,w:boxW,h:60};
      p.observe={x:12,y:12+8*77,w:boxW,h:60};
      height=12+9*77;
    }
    const parts=[`<svg class="pmsm-graph" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" role="group" aria-label="给定、速度环、电流环、逆Park、SVPWM、逆变器、PMSM，采样反馈返回控制器，数据观测独立。"><defs><marker id="pmsm-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="var(--foreground)"/></marker></defs>`];
    const path=(d)=>parts.push(`<path d="${d}" fill="none" stroke="var(--foreground)" stroke-width="1.4" marker-end="url(#pmsm-arrow)"/>`);
    const label=(x,y,s,anchor='start')=>parts.push(`<text x="${x}" y="${y}" text-anchor="${anchor}" class="text-small">${s}</text>`);
    for(let i=0;i<6;i++){
      const a=p[nodes[i].id],b=p[nodes[i+1].id];
      if(wide)path(`M${a.x+a.w} ${a.y+a.h/2} H${b.x-2}`);
      else path(`M${a.x+a.w/2} ${a.y+a.h} V${b.y-2}`);
    }
    const motor=p.motor,f=p.feedback;
    if(wide){
      path(`M${motor.x+motor.w/2} ${motor.y+motor.h} V${f.y-2}`);
      const rails=[['ipark',128,'θe',f.x+f.w*.25],['current',237,'id / iq / ωe',f.x-12],['speed',278,'n',f.x-27]];
      rails.forEach(([id,y,text,start])=>{
        const target=p[id],tx=target.x+target.w/2;
        const sx=typeof start==='number'?start:f.x;
        if(y<f.y)path(`M${sx} ${f.y} V${y} H${tx} V${target.y+target.h+2}`);
        else path(`M${f.x} ${f.y+f.h/2} H${sx} V${y} H${tx} V${target.y+target.h+2}`);
        label(tx+12,y-6,text);
      });
      const o=p.observe;
      path(`M${f.x+f.w*.8} ${f.y+f.h} V${o.y+o.h/2} H${o.x+o.w+2}`);
      label(o.x+o.w+14,o.y-9,'诊断信号');
    }else{
      path(`M${motor.x+motor.w/2} ${motor.y+motor.h} V${f.y-2}`);
      [['ipark','θe',width-20],['current','id/iq',width-42],['speed','n',width-64]].forEach(([id,text,x],i)=>{
        const target=p[id],fy=f.y+10+i*19;
        path(`M${f.x+f.w} ${fy} H${x} V${target.y+target.h/2} H${target.x+target.w+2}`);
        label(x-4,target.y+target.h/2-9,text,'end');
      });
      const o=p.observe;
      path(`M${f.x+f.w/2} ${f.y+f.h} V${o.y-2}`);
    }
    nodes.forEach(n=>{
      const b=p[n.id],color=`var(--viz-series-${n.category})`;
      parts.push(`<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" fill="${color}" fill-opacity="0.36"/><rect x="${b.x}" y="${b.y}" width="${b.w}" height="5" fill="${color}"/><foreignObject x="${b.x}" y="${b.y+5}" width="${b.w}" height="${b.h-5}"><div xmlns="http://www.w3.org/1999/xhtml" class="pmsm-node-control"><button type="button" class="btn btn-ghost" data-node="${n.id}" aria-pressed="${n.id===selected}" aria-label="${n.name}：${n.detail}">${n.name}</button></div></foreignObject>`);
    });
    parts.push('</svg>');container.innerHTML=parts.join('');
    container.querySelectorAll('button[data-node]').forEach(b=>b.addEventListener('click',()=>select(b.dataset.node,true)));
    select(selected,false);
  }
  let previousWidth=0;
  new ResizeObserver(()=>{const w=Math.round(container.getBoundingClientRect().width);if(w!==previousWidth){previousWidth=w;draw();}}).observe(container);
  window.addEventListener('openai:set_globals',event=>{const id=event.detail?.globals?.widgetState?.modelContent?.selected;if(nodes.some(n=>n.id===id))select(id,false);});
  draw();
})();
