// ImageGen supplies the shadow shapes. Transfer only their lighting to source RGB.
// Original alpha, ink, silhouettes, texture locations and details are never copied
// from a generated image. Run with NODE_PATH pointing at bundled dependencies.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { PNG } = require('pngjs');
const here = __dirname;
const root = path.resolve(here, '../..');
const read = p => PNG.sync.read(fs.readFileSync(p));
const save = (p, im) => fs.writeFileSync(p, PNG.sync.write(im));
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const files = [
  ['gen_imago_cap.png', 'assets/units/generalist', 'reference', [[0, 0, 512, 512]]],
  ['gen_imago_body.png', 'assets/units/generalist', 'reference', [[0, 0, 512, 512]]],
  ['gen_child_cap.png', 'assets/units/generalist', 'child_cap', [[0, 0, 512, 512]]],
  ['gen_child_body.png', 'assets/units/generalist', 'child_body', [[0, 0, 512, 512]]],
  ['gen_child_walk.png', 'assets/units/generalist', 'child_walk', [[154,125,392,392],[729,125,392,392],[154,719,392,392],[729,719,392,392]]],
  ['gen_imago_walk.png', 'assets/units/generalist', 'imago_walk', [[122,84,464,488],[677,89,464,488],[122,693,464,488],[677,684,464,488]]],
  ['flag.png', 'assets/combat/flag_bearer', 'flag_idle', [[122,669,269,323]]],
  ['flag_bearer_walk.png', 'assets/combat/flag_bearer', 'flag_walk', [[124,71,420,495],[713,71,420,495],[124,689,420,495],[713,689,420,495]]],
  ['spring_unit.png', 'assets/units/spring', 'spring', [[0,0,512,512]]],
];

function crop(im, [x,y,w,h]) {
  const out = new PNG({width:w,height:h});
  PNG.bitblt(im,out,x,y,w,h,0,0);
  return out;
}

function bounds(im, mask) {
  let x0=im.width,y0=im.height,x1=0,y1=0;
  for(let y=0;y<im.height;y++) for(let x=0;x<im.width;x++) {
    const p=y*im.width+x;
    if(mask ? mask[p] : im.data[p*4+3]>128) {
      x0=Math.min(x0,x); y0=Math.min(y0,y); x1=Math.max(x1,x+1); y1=Math.max(y1,y+1);
    }
  }
  if(x1<=x0||y1<=y0) throw Error('Empty image bounds');
  return [x0,y0,x1-x0,y1-y0];
}

// Flood the exterior up to the dark outline. This ignores any baked checkerboard
// in intermediate generations; no background pixels can become final pixels.
function silhouette(im) {
  const w=im.width,h=im.height,n=w*h,seen=new Uint8Array(n),q=new Int32Array(n);
  let head=0,tail=0;
  const ink=p=>Math.max(...im.data.subarray(p*4,p*4+3))<65 && im.data[p*4+3]>100;
  function add(p) { if(!seen[p]&&!ink(p)) { seen[p]=1;q[tail++]=p; } }
  for(let x=0;x<w;x++){add(x);add((h-1)*w+x);}
  for(let y=0;y<h;y++){add(y*w);add(y*w+w-1);}
  while(head<tail){let p=q[head++],x=p%w,y=Math.floor(p/w);if(x>0)add(p-1);if(x<w-1)add(p+1);if(y>0)add(p-w);if(y<h-1)add(p+w);}
  const mask=Uint8Array.from(seen,v=>1-v);
  // Retain only the largest connected outlined object in this frame.
  seen.fill(0);let largest=[];
  for(let p=0;p<n;p++) if(mask[p]&&!seen[p]) {
    head=0;tail=0;q[tail++]=p;seen[p]=1;const group=[];
    while(head<tail){const a=q[head++];group.push(a);const x=a%w,y=Math.floor(a/w);
      for(const b of [x>0?a-1:-1,x<w-1?a+1:-1,y>0?a-w:-1,y<h-1?a+w:-1])if(b>=0&&mask[b]&&!seen[b]){seen[b]=1;q[tail++]=b;}
    }
    if(group.length>largest.length)largest=group;
  }
  mask.fill(0);for(const p of largest)mask[p]=1;
  return mask;
}

function material(r,g,b,source=false) {
  if(source) {
    // Include antialiased fill/ink mixtures to avoid a pale fringe at shadows.
    // Solid ink stays byte-identical, as do the original alpha coverage values.
    if(Math.min(r,g,b)>25 && Math.max(r,g,b)-Math.min(r,g,b)<10)return 'white';
    if(r>35&&g>20&&b>15&&r>1.6*g&&r>1.8*b)return 'red';
    if(r>35&&g>28&&b>18&&r>1.06*g&&r<1.4*g&&b<r*.88)return 'tan';
    if(r>105&&r<160&&g>100&&g<155&&b>80&&b<135&&Math.abs(r-g)<10)return 'rib';
    return null;
  }
  if(Math.min(r,g,b)>95&&Math.max(r,g,b)-Math.min(r,g,b)<22)return 'white';
  if(r>65&&g>25&&b>15&&r>1.5*g&&r>1.75*b)return 'red';
  if(r>100&&g>75&&b>40&&r>1.025*g&&r<1.55*g&&b<r*.89)return 'tan';
  return null;
}

// Extend generated fill shades under its ink using the nearest fill sample.
// The final source ink is locked, so this only avoids gaps along fill edges.
function shadeField(im, mask, kind, darkRim) {
  const w=im.width,h=im.height,n=w*h;
  const nearest=new Int32Array(n).fill(-1),q=new Int32Array(n),values=[],valid=new Uint8Array(n);
  let head=0,tail=0;
  for(let p=0;p<n;p++) {
    const [r,g,b]=im.data.subarray(p*4,p*4+3),k=material(r,g,b);
    if(mask[p] && (kind==='rib' ? Math.abs(r-g)<18 && b<r && r>75 && r<185 : k===kind))valid[p]=1;
  }
  // Ignore generated antialiasing against ink; its gray pixels aren't shadows.
  const margin=4;
  for(let y=margin;y<h-margin;y++) for(let x=margin;x<w-margin;x++) {
    const p=y*w+x;
    if(!valid[p])continue;
    let interior=true;
    for(let dy=-margin;dy<=margin&&interior;dy++)for(let dx=-margin;dx<=margin;dx++)if(!valid[p+dy*w+dx]){interior=false;break;}
    if(interior) {
      const [r,g,b]=im.data.subarray(p*4,p*4+3);
      nearest[p]=p;q[tail++]=p;values.push((r+g+b)/3);
    }
  }
  if(!tail)return null;
  values.sort((a,b)=>a-b);const base=values[Math.floor(values.length*.80)];
  while(head<tail){const p=q[head++],x=p%w,y=Math.floor(p/w);
    for(const a of [x>0?p-1:-1,x<w-1?p+1:-1,y>0?p-w:-1,y<h-1?p+w:-1])if(a>=0&&nearest[a]<0){nearest[a]=nearest[p];q[tail++]=a;}
  }
  const field=new Float32Array(n);
  for(let p=0;p<n;p++) {
    const j=nearest[p]*4,v=(im.data[j]+im.data[j+1]+im.data[j+2])/3,ratio=v/base;
    field[p]=darkRim&&ratio<.61 ? 117/255 : ratio<.89 ? 167/255 : 1;
  }
  return field;
}

function sample(field,w,h,x,y) {
  x=Math.max(0,Math.min(w-1.001,x));y=Math.max(0,Math.min(h-1.001,y));
  const x0=Math.floor(x),y0=Math.floor(y),fx=x-x0,fy=y-y0;
  return field[y0*w+x0]*(1-fx)*(1-fy)+field[y0*w+x0+1]*fx*(1-fy)+field[(y0+1)*w+x0]*(1-fx)*fy+field[(y0+1)*w+x0+1]*fx*fy;
}

function flagCapBounds(im, generated=false, silhouetteMask=null) {
  const mask=new Uint8Array(im.width*im.height);
  for(let p=0;p<mask.length;p++) {
    if(Math.floor(p/im.width)>=im.height*.55)continue;
    const i=p*4,[r,g,b]=im.data.subarray(i,i+3);
    mask[p]=generated
      ? silhouetteMask[p]&&material(r,g,b)==='red'
      : im.data[i+3]>200&&r>110&&r>1.6*g&&r>1.8*b;
  }
  // Ignore isolated reddish antialias pixels on the cream body. The cap is
  // the largest continuous band of red rows in the upper part of the frame.
  let bestStart=0,bestEnd=0,start=-1;
  for(let y=0;y<=im.height;y++) {
    let count=0;
    if(y<im.height)for(let x=0;x<im.width;x++)count+=mask[y*im.width+x];
    if(count>=3) {if(start<0)start=y;}
    else if(start>=0){if(y-start>bestEnd-bestStart){bestStart=start;bestEnd=y;}start=-1;}
  }
  for(let p=0;p<mask.length;p++)if(p<bestStart*im.width||p>=bestEnd*im.width)mask[p]=0;
  return bounds(im,mask);
}

// Every flag-bearer pose samples the SAME ImageGen shadow field. Register to
// the stationary cap, not the whole silhouette whose bounds vary with the feet.
function transferFlag(original, generated, region) {
  const gen=crop(generated,[0,0,Math.floor(generated.width/2),Math.floor(generated.height/2)]);
  const mask=silhouette(gen),gb=flagCapBounds(gen,true,mask);
  const src=crop(original,region),sb=flagCapBounds(src);
  const fields={red:shadeField(gen,mask,'red',false),tan:shadeField(gen,mask,'tan',false)};
  const [rx,ry,rw,rh]=region;
  for(let y=0;y<rh;y++)for(let x=0;x<rw;x++) {
    const i=((ry+y)*original.width+rx+x)*4;
    if(original.data[i+3]===0)continue;
    const field=fields[material(...original.data.subarray(i,i+3),true)];
    if(!field)continue;
    const gx=gb[0]+(x-sb[0])*(gb[2]-1)/(sb[2]-1);
    const gy=gb[1]+(y-sb[1])*(gb[3]-1)/(sb[3]-1);
    const multiplier=sample(field,gen.width,gen.height,gx,gy);
    for(let c=0;c<3;c++)original.data[i+c]=Math.round(original.data[i+c]*multiplier);
  }
  return {sourceCapBounds:sb,generatedCapBounds:gb,shadowSource:'flag_walk.png frame 0'};
}

function transfer(original, generated, region, genRegion, key) {
  const src=crop(original,region),gen=crop(generated,genRegion),mask=silhouette(gen);
  const sb=bounds(src),gb=bounds(gen,mask),fields={};
  for(const kind of ['white','red','tan','rib'])fields[kind]=shadeField(gen,mask,kind,key==='child_cap');
  const [rx,ry,rw,rh]=region;
  for(let y=0;y<rh;y++) for(let x=0;x<rw;x++){
    const i=((ry+y)*original.width+rx+x)*4;
    if(original.data[i+3]===0)continue;
    const kind=material(...original.data.subarray(i,i+3),true),field=fields[kind];
    if(['child_cap','child_body','child_walk','imago_walk'].includes(key)&&kind!=='white')continue;
    if(['flag_idle','flag_walk'].includes(key)&&!['red','tan'].includes(kind))continue;
    if(kind==='rib'&&key!=='spring')continue;
    if(key==='spring'&&rx+x>170&&rx+x<343&&ry+y<230)continue;
    if(!field)continue;
    const gx=gb[0]+((x-sb[0]+.5)/sb[2])*gb[2]-.5,gy=gb[1]+((y-sb[1]+.5)/sb[3])*gb[3]-.5;
    const multiplier=sample(field,gen.width,gen.height,gx,gy);
    for(let c=0;c<3;c++)original.data[i+c]=Math.round(original.data[i+c]*multiplier);
  }
  return {sourceBounds:sb,generatedBounds:gb};
}

async function main() {
  const previous=JSON.parse(fs.readFileSync(path.join(here,'validation.json'),'utf8'));
  const flagOnly=process.argv.includes('--flag-only');
  const report=flagOnly?previous.filter(r=>!r.asset.startsWith('assets/combat/flag_bearer/')):[];
  fs.mkdirSync(path.join(here,'after'),{recursive:true});
  for(const [name,folder,key,regions] of files) {
    if(flagOnly&&!['flag_idle','flag_walk'].includes(key))continue;
    const before=read(path.join(here,'before',name)),out=read(path.join(here,'before',name));
    const registration=[];
    if(key==='reference') {
      const ref=read(path.join(here,'reference.png'));
      for(let p=0;p<out.width*out.height;p++){
        const i=p*4;if(out.data[i+3]===0||material(...out.data.subarray(i,i+3),true)!=='white')continue;
        const [r,g,b]=ref.data.subarray(i,i+3);
        if(Math.max(r,g,b)-Math.min(r,g,b)>2||r<25||r>=254)continue;
        for(let c=0;c<3;c++)out.data[i+c]=Math.min(out.data[i+c],ref.data[i+c]);
      }
    } else if(['flag_idle','flag_walk'].includes(key)) {
      const gen=read(path.join(here,'generated','flag_walk.png'));
      for(const region of regions)registration.push(transferFlag(out,gen,region));
    } else {
      const gen=read(path.join(here,'generated',key+'.png'));
      for(let f=0;f<regions.length;f++){
        let gr;
        if(regions.length===4){const hw=Math.floor(gen.width/2),hh=Math.floor(gen.height/2);gr=[f%2*hw,Math.floor(f/2)*hh,hw,hh];}
        else if(key==='flag_idle'){const top=Math.round(gen.height*669/993);gr=[0,top,gen.width,gen.height-top];}
        else gr=[0,0,gen.width,gen.height];
        registration.push(transfer(out,gen,regions[f],gr,key));
      }
    }
    let changed=0,alphaChanged=0,inkChanged=0,lightened=0,outsideChanged=0;
    for(let p=0;p<out.width*out.height;p++){
      const i=p*4,x=p%out.width,y=Math.floor(p/out.width),rgbChanged=[0,1,2].some(c=>out.data[i+c]!==before.data[i+c]);
      if(out.data[i+3]!==before.data[i+3])alphaChanged++;
      if(!rgbChanged)continue;changed++;
      if(Math.max(...before.data.subarray(i,i+3))<=25)inkChanged++;
      if([0,1,2].some(c=>out.data[i+c]>before.data[i+c]))lightened++;
      if(!regions.some(([rx,ry,rw,rh])=>x>=rx&&x<rx+rw&&y>=ry&&y<ry+rh)||before.data[i+3]===0)outsideChanged++;
    }
    if(alphaChanged||inkChanged||lightened||outsideChanged||changed===0)throw Error('Invariant failed: '+name);
    const output=path.join(here,'after',name);save(output,out);
    report.push({asset:folder+'/'+name,width:out.width,height:out.height,changedPixels:changed,alphaChanged,inkChanged,lightened,outsideChanged,sourceHash:hash(before.data),resultHash:hash(out.data),registration});
    if(process.argv.includes('--apply')) {
      const target=path.join(root,folder,name),current=read(target);
      const accepted=previous.find(r=>r.asset===folder+'/'+name)?.resultHash;
      const correctionBaseline=path.join(here,'flag-consistency-before',name);
      const correctionHash=folder==='assets/combat/flag_bearer'&&fs.existsSync(correctionBaseline)?hash(read(correctionBaseline).data):null;
      if(![hash(before.data),hash(out.data),accepted,correctionHash].includes(hash(current.data)))throw Error('Asset changed during shading pass: '+name);
      fs.copyFileSync(output,target);
    }
  }
  fs.writeFileSync(path.join(here,'validation.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report.map(({asset,changedPixels,alphaChanged,inkChanged,outsideChanged})=>({asset,changedPixels,alphaChanged,inkChanged,outsideChanged})),null,2));
}
module.exports={crop,bounds,silhouette,material,shadeField,sample};
if(require.main===module)main().catch(e=>{console.error(e);process.exit(1)});
