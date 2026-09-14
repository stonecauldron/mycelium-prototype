// Compare actual texture lighting against original fill colors in registered caps.
const fs=require('fs'),path=require('path'),{PNG}=require('pngjs');
const here=__dirname,root=path.resolve(here,'../..');
const read=p=>PNG.sync.read(fs.readFileSync(p));
const name='flag_bearer_walk.png';
const original=read(path.join(here,'before',name));
const current=read(path.join(process.argv[2]||path.join(root,'assets/combat/flag_bearer'),name));
const regions=[[124,71,420,495],[713,71,420,495],[124,689,420,495],[713,689,420,495]];
const red=i=>original.data[i+3]>200&&original.data[i]>110&&original.data[i]>1.6*original.data[i+1]&&original.data[i]>1.8*original.data[i+2];
const contours=regions.map(([rx,ry,rw,rh])=>{
  let x0=Infinity,y0=Infinity,x1=0,y1=0;
  for(let y=ry;y<ry+rh;y++)for(let x=rx;x<rx+rw;x++){const i=(y*original.width+x)*4;if(red(i)){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);}}
  const samples=[];
  for(const v of [.2,.3,.4,.5,.6,.7,.8]){
    const y=Math.round(y0+(y1-y0)*v);let boundary=null;
    for(let x=x0;x<x0+(x1-x0)*.55;x++){const i=(y*original.width+x)*4;if(red(i)&&current.data[i]/original.data[i]<.83)boundary=(x-x0)/(x1-x0);}
    samples.push(boundary);
  }
  return {bounds:[x0,y0,x1-x0+1,y1-y0+1],samples};
});
let maxSpread=0;
for(let j=0;j<7;j++){const row=contours.map(c=>c.samples[j]);if(row.some(v=>v===null))throw Error('Missing shadow');maxSpread=Math.max(maxSpread,Math.max(...row)-Math.min(...row));}
// Check both cap and body lighting across idle and walking. Compare attenuation
// relative to each original texture, so original color differences are excluded.
const idleOriginal=read(path.join(here,'before','flag.png'));
const idleCurrent=read(path.join(process.argv[2]||path.join(root,'assets/combat/flag_bearer'),'flag.png'));
const poses=contours.map(c=>[original,current,c.bounds]);
poses.push([idleOriginal,idleCurrent,[136,682,242,133]]);
const agreement={cap:{samples:0,different:0},body:{samples:0,different:0}};
for(let iy=5;iy<225;iy++)for(let ix=5;ix<95;ix++) {
  const ratios=[],kinds=[];
  for(const [o,a,[x,y,w,h]]of poses) {
    const px=Math.round(x+ix/100*(w-1)),py=Math.round(y+iy/100*(h-1)),i=(py*o.width+px)*4;
    const [r,g,b,alpha]=o.data.subarray(i,i+4);
    const kind=alpha>200&&r>120&&r>1.6*g&&r>1.8*b?'cap'
      :alpha>200&&r>180&&g>150&&b>100&&r<1.4*g&&r>1.05*g&&b<r*.88?'body':null;
    kinds.push(kind);ratios.push(a.data[i]/r);
  }
  if(!kinds[0]||!kinds.every(k=>k===kinds[0]))continue;
  const result=agreement[kinds[0]];result.samples++;
  if(Math.max(...ratios)-Math.min(...ratios)>.08)result.different++;
}
// A small border tolerance accounts for the different idle/walk resolutions.
const lightingPass=Object.values(agreement).every(r=>r.samples>1000&&r.different/r.samples<.015);
const pass=maxSpread<=.006&&lightingPass;
console.log(JSON.stringify({contours,maxShadowBoundaryDriftPercent:+(maxSpread*100).toFixed(3),allowedPercent:.6,idleAndWalkAgreement:agreement,pass},null,2));
if(!pass)process.exitCode=1;
