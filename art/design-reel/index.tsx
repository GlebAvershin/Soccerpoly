import React, {CSSProperties} from "react";
import {AbsoluteFill, Composition, Img, Sequence, registerRoot, staticFile, useCurrentFrame, useVideoConfig} from "remotion";
import {gsap} from "gsap";

const editions = {
  depot: {
    bg: "#172829", paper: "#f1e8ce", accent: "#edaa50", tint: "#78cec0",
    mast: "DEPOT   /   07",
  },
  cup: {
    bg: "#f0e6cd", paper: "#183f37", accent: "#ac4734", tint: "#306552",
    mast: "CONTINENTAL   /   CUP",
  },
};
const mono = '"Courier New", monospace';
const position = (left: number, top: number): CSSProperties => ({position: "absolute", left, top});
const small: CSSProperties = {fontFamily: mono, fontWeight: 700, fontSize: 19, letterSpacing: 2};

function GameFrames({kind}: {kind: keyof typeof editions}) {
  const p = editions[kind];
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const depot = kind === "depot";
  const shots = depot
    ? [{file:"drone", caption:"Sentinel в патруле", width:635}, {file:"receiver", caption:"Приёмник шлюза",width:538}]
    : [{file:"board",caption:"Поле Continental Cup",width:786},{file:"club",caption:"Досье клуба",width:387}];
  return <AbsoluteFill style={{background:p.bg,color:p.paper,fontFamily:"Helvetica Neue, Arial, sans-serif"}}>
    <div style={{...position(42,30),width:1196,borderBottom:"2px solid "+p.accent,paddingBottom:13,
      display:"flex",justifyContent:"space-between",...small}}><span>{p.mast}</span><span>ROBLOX STUDIO</span></div>
    <div style={{...position(42,89),fontSize:38,fontWeight:800}}>{depot?"Blackout Freight":"Soccerpoly"}</div>
    <div style={{...position(42,159),display:"flex",gap:23,alignItems:"center",height:481}}>
      {shots.map((shot,i)=>{
        const progress=Math.max(0,Math.min(1,(frame/fps-i*.10)/.38));
        return <div key={shot.file} style={{width:shot.width,opacity:progress,translate:"0 "+((1-progress)*12)+"px"}}>
          <Img src={staticFile(shot.file+".jpg")} style={{width:"100%",height:depot?401:467,objectFit:"contain",display:"block"}}/>
        </div>;
      })}
    </div>
    <div style={{...position(42,655),display:"flex",gap:23}}>
      {shots.map(shot=><div key={shot.file} style={{width:shot.width,paddingTop:9,borderTop:"2px solid "+p.accent,...small,letterSpacing:1}}>{shot.caption}</div>)}
    </div>
  </AbsoluteFill>;
}

function Sculpture({kind}: {kind: keyof typeof editions}) {
  const p = editions[kind];
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const cup = kind === "cup";
  const t = Math.min(1, frame / (fps * .72));
  const enter = gsap.parseEase("power2.out")(t);
  return <AbsoluteFill style={{background:p.bg,color:p.paper,fontFamily:"Helvetica Neue, Arial, sans-serif"}}>
    <div style={{...position(42,29),width:1196,borderBottom:"2px solid "+p.accent,paddingBottom:13,
      display:"flex",justifyContent:"space-between",...small}}><span>{cup?"SOCCERPOLY":"BLACKOUT FREIGHT"}</span><span>BLENDER</span></div>
    <div style={{...position(42,82),fontSize:46,fontWeight:800}}>{cup?"Сборные на поле":"Патруль Депо 07"}</div>
    <div style={{...position(42,153),width:1196,height:467,overflow:"hidden",display:"flex",alignItems:"center",justifyContent:"center",background:cup?"#101915":"#1c292b"}}>
      <Img src={staticFile(cup?"players.jpg":"sentinel.jpg")} style={{width:"100%",height:"100%",objectFit:"contain",opacity:enter,transform:"scale("+(1.018-.018*enter)+")"}}/>
    </div>
    <div style={{...position(42,650),width:1196,borderTop:"2px solid "+p.accent,paddingTop:13,...small}}>
      {cup?"Шесть фигурок в форме национальных сборных":"Sentinel · сдвоенный ротор и поворотная оптика"}
    </div>
  </AbsoluteFill>;
}
function Film(){const {fps}=useVideoConfig();return <AbsoluteFill>
  <Sequence durationInFrames={4*fps} name="Сборные"><Sculpture kind="cup"/></Sequence>
  <Sequence from={4*fps} durationInFrames={4*fps} name="Поле в Studio"><GameFrames kind="cup"/></Sequence>
  <Sequence from={8*fps} durationInFrames={4*fps} name="Sentinel"><Sculpture kind="depot"/></Sequence>
  <Sequence from={12*fps} durationInFrames={4*fps} name="Депо в Studio"><GameFrames kind="depot"/></Sequence>
</AbsoluteFill>}
registerRoot(()=> <Composition id="GameEditions" component={Film} width={1280} height={720} fps={30} durationInFrames={480}/>);
