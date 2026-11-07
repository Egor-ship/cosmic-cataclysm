// Six authored aftermaths: geometry, timing, weather and materials differ by planet.
fn im_rotate(p:vec3<f32>,a:f32,b:f32)->vec3<f32>{
    let q=vec3<f32>(p.x*cos(a)-p.z*sin(a),p.y,p.x*sin(a)+p.z*cos(a));
    return vec3<f32>(q.x,q.y*cos(b)-q.z*sin(b),q.y*sin(b)+q.z*cos(b));
}
fn im_rayline(ro:vec3<f32>,rd:vec3<f32>,a:vec3<f32>,b:vec3<f32>)->vec2<f32>{
    let v=b-a;let w=ro-a;let vv=dot(v,v);let rv=dot(rd,v);let rw=dot(rd,w);let vw=dot(v,w);
    let u=clamp((vw-rv*rw)/max(0.0001,vv-rv*rv),0.0,1.0);
    let at=a+v*u;let d=max(0.0,dot(at-ro,rd));return vec2<f32>(length(ro+rd*d-at),d);
}
fn cc_sky(rd:vec3<f32>,t:f32,id:f32,base:vec3<f32>)->vec3<f32>{
    let strength=smoothstep(14.6,16.4,t)*(1.0-smoothstep(40.0,45.0,t));
    if(strength<=0.001){return base;}
    let delta=frame.mod_params[0].xyz-frame.camera_position.xyz;
    let towards=normalize(vec3<f32>(delta.x,max(60.0,length(delta.xz)*0.58),delta.z));
    let side=normalize(cross(towards,vec3<f32>(0,1,0)));let up=cross(side,towards);
    let forward=dot(rd,towards);let p=vec2<f32>(dot(rd,side),dot(rd,up))/max(0.12,forward);
    let n=cc_fbm(rd*8.0+vec3<f32>(0,t*0.026,0));
    let fine=cc_noise(rd*74.0+vec3<f32>(t*0.008));
    let stars=pow(cc_hash(floor(rd*1700.0)),170.0);
    var sky=vec3<f32>(0.003,0.006,0.016)+vec3<f32>(0.6,0.74,1.0)*stars;
    let horizon=exp(-abs(rd.y)*5.0);
    if(id<0.5){
        // An eclipsing iron world occupies the sky. Jagged solar prominences protrude from its limb.
        let radius=length(p);let angle=atan2(p.y,p.x);
        let corrugation=0.012*sin(angle*19.0+t*0.2)+0.008*sin(angle*43.0);
        let corona=exp(-abs(radius-0.31-corrugation)*31.0);
        sky+=vec3<f32>(1.9,0.43,0.055)*corona*select(0.0,1.0,forward>0.0);
        let rays=pow(0.5+0.5*sin(angle*31.0+cc_noise(vec3<f32>(angle*12.0,t*.08,0))*6.0),7.0);
        sky+=vec3<f32>(1.0,.24,.025)*rays*exp(-abs(radius-.37)*13.0)*step(.31,radius)*step(0.0,forward);
        if(forward>0.0 && radius<.307){sky=vec3<f32>(.005,.003,.004)+vec3<f32>(.055,.021,.01)*cc_fbm(vec3<f32>(p*45.0,t*.01));}
        let meteor=pow(max(0.0,sin(rd.x*83.0+rd.z*41.0+t*.6)),110.0)*pow(fine,5.0);
        sky+=vec3<f32>(1.0,.34,.05)*meteor*1.8+vec3<f32>(.22,.045,.006)*horizon;
    }else if(id<1.5){
        // Dense cloud strata curl around a sulfur eye; the cloud is an environment, not a tint.
        let radius=length(p);let angle=atan2(p.y,p.x);
        let spiral=cc_fbm(vec3<f32>(angle*1.6+radius*4.0-t*.16,radius*6.0,t*.035));
        let bands=.5+.5*sin(radius*18.0-angle*3.0+t*.6+n*7.0);
        sky=mix(vec3<f32>(.027,.034,.009),vec3<f32>(.44,.35,.075),smoothstep(.2,.9,spiral*.65+bands*.35));
        sky*=.45+min(1.0,radius*2.0);sky+=vec3<f32>(.65,.68,.14)*exp(-abs(radius-.42)*14.0);
        sky+=vec3<f32>(.18,.21,.025)*pow(fine,7.0)*(.3+.7*sin(t*3.0)*sin(t*3.0));
    }else if(id<2.5){
        // A sweeping asteroid belt with tall curtains of windblown dust.
        sky=vec3<f32>(.018,.007,.008)+vec3<f32>(.28,.052,.014)*horizon+vec3<f32>(.7,.55,.4)*stars;
        let belt=abs(p.y*.88+p.x*.23-.15);
        let field=cc_hash(floor(vec3<f32>(p*155.0,1.0)));
        let rocks=step(.972,field)*exp(-belt*8.0)*(.5+.5*cc_noise(rd*300.0));
        sky+=vec3<f32>(.37,.21,.11)*rocks;
        let curtains=pow(cc_fbm(vec3<f32>(rd.x*18.0+t*.04,rd.y*3.0,rd.z*18.0)),3.0);
        sky+=vec3<f32>(.62,.15,.035)*curtains*exp(-max(rd.y,0.0)*2.6);
        sky+=vec3<f32>(.9,.3,.07)*exp(-belt*35.0)*.18;
    }else if(id<3.5){
        // Looking up into a physically anchored cyclone's eye and branching electrical cloud veins.
        let radial=length(p);let angle=atan2(p.y,p.x);let curl=angle+radial*3.0-t*.2;
        let clouds=cc_fbm(vec3<f32>(cos(curl)*radial*5.0,sin(curl)*radial*5.0,t*.06));
        let rings=.5+.5*sin(radial*23.0-angle*2.0+clouds*8.0);
        sky=mix(vec3<f32>(.009,.018,.039),vec3<f32>(.19,.23,.32),clouds*.65+rings*.35);
        let eye=1.0-smoothstep(.1,.32,radial);sky=mix(sky,vec3<f32>(.003,.009,.028)+stars*.4,eye);
        let bolt=pow(max(0.0,1.0-abs(sin(angle*7.0+radial*6.0+cc_noise(vec3<f32>(radial*20.0,floor(t*5.0),0))*3.0))*36.0),2.0);
        let pulse=pow(max(0.0,sin(t*9.7)+.15),8.0);
        sky+=vec3<f32>(.42,.66,1.5)*bolt*pulse*smoothstep(.17,.35,radial);
    }else if(id<4.5){
        // An immense tilted system of icy rings crosses the entire sky, with a visible dark gap.
        let q=vec2<f32>(p.x*.7+p.y*.35,-p.x*.35+p.y*.7);
        let radius=length(q*vec2<f32>(.55,2.4));
        let ring=step(.35,radius)*(1.0-smoothstep(1.7,1.85,radius))*step(0.0,forward);
        let gap=smoothstep(.83,.855,radius)*(1.0-smoothstep(.91,.935,radius));
        let bands=.45+.3*sin(radius*280.0)+.15*cc_noise(vec3<f32>(q*65.0,t*.01));
        sky=mix(sky,vec3<f32>(.52,.46,.3)*bands+vec3<f32>(.2,.31,.4)*pow(bands,3.0),ring*(1.0-gap*.95));
        let small=pow(cc_hash(floor(rd*950.0)),110.0)*exp(-abs(radius-1.3)*2.0);
        sky+=vec3<f32>(.7,.86,1.0)*small*2.0;
        sky+=vec3<f32>(.095,.12,.17)*horizon;
    }else{
        // Aurora curtains and a dark gravitational lens bending a luminous stellar halo.
        let lon=atan2(rd.z,rd.x);let elevation=asin(clamp(rd.y,-1.0,1.0));
        let wave=.36+.10*sin(lon*4.0+t*.08)+.06*sin(lon*11.0-t*.12);
        let curtain=exp(-abs(elevation-wave)*12.0)*pow(.5+.5*sin(lon*72.0+cc_noise(rd*15.0)*4.0),2.0);
        let high=exp(-abs(elevation-wave-.12)*15.0);
        sky+=mix(vec3<f32>(.015,.67,.63),vec3<f32>(.29,.06,.72),high)*curtain*1.6;
        let radius=length(p);let halo=exp(-abs(radius-.25)*65.0)*step(0.0,forward);
        sky+=vec3<f32>(.15,.55,1.6)*halo;
        if(forward>0.0 && radius<.235){sky=vec3<f32>(.001,.003,.009);}
        sky+=vec3<f32>(.01,.055,.12)*horizon;
    }
    return mix(base,sky,strength);
}

// Density / heat / illumination. Each branch has its own spatial structure and time envelope.
fn im_field(p:vec3<f32>,age:f32,id:f32)->vec3<f32>{
    let r=length(p.xz);let theta=atan2(p.z,p.x);let n=cc_fbm(p*.045+vec3<f32>(0,-age*.36,age*.08));
    var density=0.0;var heat=0.0;var electric=0.0;
    if(id<.5){
        let height=min(170.0,age*67.0);let width=7.0+max(p.y,0.0)*.075+n*9.0;
        let stalk=(1.0-smoothstep(width,width+7.0,r))*smoothstep(-4.0,8.0,p.y)*(1.0-smoothstep(height-15.0,height,p.y));
        let splash=exp(-abs(r-min(95.0,age*24.0))*.12)*exp(-abs(p.y-5.0)*.11);
        density=(stalk*(.5+n)+splash*.7)*exp(-age*.13);heat=stalk*exp(-age*.22)+splash*.6;
    }else if(id<1.5){
        let major=min(90.0,16.0+age*14.0);let height=17.0+11.0*sin(theta*4.0+age*.8)+n*14.0;
        let torus=length(vec2<f32>((r-major)*.78,p.y-height));
        let veil=exp(-torus*.035)*(1.0-smoothstep(16.0,42.0,abs(p.y-height)));
        let spiral=pow(.5+.5*sin(theta*4.0-r*.08+age*1.4+n*5.0),3.0);
        density=(veil*(.6+n)+exp(-r*.018)*exp(-abs(p.y-5.0)*.14)*.45)*exp(-age*.055);
        heat=veil*(.48+spiral*.42)*exp(-age*.055);
    }else if(id<2.5){
        let wall=min(155.0,age*27.0);let height=28.0+n*35.0;
        let dust=exp(-abs(r-wall)*.085)*(1.0-smoothstep(height*.6,height,p.y))*smoothstep(-2.0,4.0,p.y);
        let jet=exp(-r*.065)*exp(-abs(p.y-age*18.0)*.045);
        density=(dust*(.5+n)+jet*.6)*exp(-age*.075);heat=jet*.7*exp(-age*.7)+dust*.12;
    }else if(id<3.5){
        let y=max(0.0,p.y);let width=8.0+y*.20+sin(y*.06-age*2.0)*5.0;
        let funnel=exp(-abs(r-width)*.14)*smoothstep(-3.0,8.0,p.y)*(1.0-smoothstep(155.0,190.0,p.y));
        let band=.5+.5*sin(theta*5.0+p.y*.11-age*5.0+n*4.0);
        density=funnel*(.28+n*.7)*smoothstep(0.0,.8,age)*exp(-age*.035);
        heat=band*.12;
        electric=pow(max(0.0,1.0-abs(sin(theta*5.0+p.y*.07+cc_noise(vec3<f32>(p.y*.18,floor(age*7.0),2))*2.0))*22.0),3.0)*funnel;
    }else if(id<4.5){
        // A low expanding frost disk; its thin rings remain crisp above this mist.
        let radius=min(165.0,age*36.0);let disk=exp(-abs(r-radius)*.09)*exp(-abs(p.y-6.0)*.18);
        let shard=exp(-r*.10)*smoothstep(-1.0,3.0,p.y)*(1.0-smoothstep(65.0,90.0,p.y));
        density=(disk*.55+shard*.18)*exp(-age*.12);heat=.25+disk*.25;
    }else{
        let release=smoothstep(1.5,3.0,age);let height=release*140.0;
        let width=8.0+max(p.y,0.0)*.06;
        let jet=exp(-r/width)*smoothstep(-2.0,8.0,p.y)*(1.0-smoothstep(height-20.0,max(2.0,height),p.y));
        let inward=exp(-abs(r-max(5.0,90.0-age*40.0))*.13)*exp(-abs(p.y-10.0)*.15)*(1.0-release);
        let crown=exp(-length(vec2<f32>(r-release*50.0,(p.y-release*42.0)*.9))*.06)*release;
        density=(jet*.85+crown*.7+inward*.8)*exp(-age*.075);heat=jet*.7+crown*.6;electric=inward*.7;
    }
    return vec3<f32>(max(0.0,density),clamp(heat,0.0,1.0),electric);
}

fn im_sd_box(p:vec3<f32>,b:vec3<f32>)->f32{
    let q=abs(p)-b;return length(max(q,vec3<f32>(0)))+min(max(q.x,max(q.y,q.z)),0.0);
}
fn im_crystal(p:vec3<f32>,height:f32,width:f32)->f32{
    let taper=width*(1.0-clamp(p.y/height,0.0,1.0));
    let hex=max(abs(p.x),max(abs(p.x*.5+p.z*.866025),abs(p.x*.5-p.z*.866025)))-taper;
    return max(hex,max(-p.y,p.y-height));
}
// Opaque sculptural cores provide readable silhouettes within the softer volume layers.
// These are authored storm/ice/ground-wave forms, never substituted block debris.
fn im_sculpt(p:vec3<f32>,age:f32,id:f32)->f32{
    let r=length(p.xz);let theta=atan2(p.z,p.x);
    if(id<.5){
        let h=min(150.0,age*80.0);let q=p-vec3<f32>(sin(p.y*.04+age)*3.0,0,cos(p.y*.05-age)*3.0);
        let width=10.0+max(p.y,0.0)*.055;
        let fissure=cc_fbm(q*.12+vec3<f32>(0,-age*.6,0));
        let lance=max(length(q.xz)-width-(fissure-.5)*8.0,max(-p.y,p.y-h));
        let foot=length(vec2<f32>(r-24.0,p.y-7.0))-8.0;
        return min(lance,foot);
    }
    if(id<1.5){
        let n=cc_fbm(p*.075+vec3<f32>(sin(age*.2)*2.0,-age*.18,0));
        let major=min(80.0,20.0+age*13.0);
        let torus=length(vec2<f32>(r-major,p.y-27.0-6.0*sin(theta*5.0+age*.6)))-18.0-(n-.5)*15.0;
        let h=min(115.0,age*44.0);let turn=p.y*.065-age*1.7;
        let q=p.xz-vec2<f32>(cos(turn),sin(turn))*min(12.0,p.y*.13);
        let stem=max(length(q)-(10.0+p.y*.035)-(n-.5)*8.0,max(-p.y,p.y-h));
        let cap_center=vec3<f32>(cos(h*.065-age*1.7)*12.0,h-4.0,sin(h*.065-age*1.7)*12.0);
        let cap=(length((p-cap_center)/vec3<f32>(19,13,19))-1.0)*13.0-(n-.5)*5.0;
        return min(torus,min(stem,cap));
    }
    if(id<2.5){
        // Nine connected wedges hinge upwards from a cracked ring of crust.
        // The inside stays rooted at ground level; these are not scattered fake cubes.
        let a=round(theta*9.0/6.2831853)*6.2831853/9.0;
        let q=vec2<f32>(p.x*cos(a)+p.z*sin(a),-p.x*sin(a)+p.z*cos(a));
        let outer=45.0+min(35.0,age*5.0);let inner=18.0;
        let lift=10.0+34.0*sin(clamp(age/13.0,0.0,1.0)*3.14159265);
        let hinged=(q.x-inner)/(outer-inner)*lift;
        let radial=max(inner-q.x,q.x-outer);
        let gap=abs(q.y)-max(0.0,q.x)*.325;
        return max(max(radial,gap),max(-p.y,p.y-hinged-3.5))+cc_noise(p*.12)*1.1;
    }
    if(id<3.5){
        let n=cc_fbm(p*.045+vec3<f32>(0,age*.25,0));
        let turn=p.y*.035-age*1.9;
        let q=p.xz-vec2<f32>(cos(turn),sin(turn))*(3.0+p.y*.055);
        let radius=12.0+max(p.y,0.0)*.22+(n-.5)*15.0+sin(p.y*.17-age*2.0)*4.0;
        let stalk=max(length(q)-radius,max(-p.y,p.y-150.0));
        let cap=(length((p-vec3<f32>(0,145,0))/vec3<f32>(75,24,75))-1.0)*24.0-(n-.5)*9.0;
        return min(stalk,cap);
    }
    if(id<4.5){
        let rise=smoothstep(.05,2.0,age);var d=im_crystal(p,130.0*rise+1.0,17.0);
        for(var i=0u;i<7u;i++){
            let a=f32(i)*6.2831853/7.0;
            let center=vec3<f32>(cos(a)*43.0,0,sin(a)*43.0);
            let q=im_rotate(p-center,a,0.15*sin(a));
            d=min(d,im_crystal(q,(54.0+18.0*sin(a*2.0))*rise+1.0,9.0));
        }
        return d;
    }
    let collapse=1.0-smoothstep(.2,4.0,age);
    var d=1000.0;
    if(age<4.0){d=length(p-vec3<f32>(0,37,0))-(8.0+collapse*53.0);}
    let rise=smoothstep(2.2,4.4,age);
    if(rise>0.0){
        for(var i=0u;i<6u;i++){
            let a=f32(i)*6.2831853/6.0+.2618;
            let center=vec3<f32>(cos(a)*42.0,0,sin(a)*42.0);
            let q=im_rotate(p-center,a,.12);
            d=min(d,im_crystal(q,(92.0+24.0*sin(a*3.0))*rise+1.0,11.0));
        }
        let fountain=max(length(p.xz)-(7.0+cc_noise(p*.11)*7.0),max(-p.y,p.y-150.0*rise));
        d=min(d,fountain);
    }
    return d;
}
fn im_surface(ro:vec3<f32>,rd:vec3<f32>,age:f32,id:f32,limit:f32)->vec4<f32>{
    if(age>20.0){return vec4<f32>(0,0,0,-1);}
    let bounds=cc_sphere(ro,rd,vec3<f32>(0,65,0),205.0);var travel=max(0.0,bounds.x);let end=min(limit,bounds.y);
    var hit=false;
    for(var i=0u;i<64u;i++){
        if(travel>=end){break;}
        let d=im_sculpt(ro+rd*travel,age,id);
        if(d<.58){hit=true;break;}
        travel+=max(.6,d*.58);
    }
    if(!hit){return vec4<f32>(0,0,0,-1);}
    let p=ro+rd*travel;let e=.6;
    let normal=normalize(vec3<f32>(im_sculpt(p+vec3<f32>(e,0,0),age,id)-im_sculpt(p-vec3<f32>(e,0,0),age,id),im_sculpt(p+vec3<f32>(0,e,0),age,id)-im_sculpt(p-vec3<f32>(0,e,0),age,id),im_sculpt(p+vec3<f32>(0,0,e),age,id)-im_sculpt(p-vec3<f32>(0,0,e),age,id)));
    let light=max(.0,dot(normal,normalize(vec3<f32>(-.5,.8,.4))));
    let rim=pow(1.0-max(0.0,dot(normal,-rd)),3.0);
    let detail=cc_fbm(p*.16+vec3<f32>(0,-age*.2,0));
    var color=vec3<f32>(0);
    if(id<.5){
        let heat=pow(.25+detail*.75,2.0);
        color=mix(vec3<f32>(.24,.045,.006),vec3<f32>(3.7,1.3,.12),heat)+vec3<f32>(1.5,.24,.01)*rim;
    }else if(id<1.5){
        let clouds=mix(vec3<f32>(.18,.16,.035),vec3<f32>(1.05,.95,.30),detail);
        color=clouds*(.35+.9*light)+vec3<f32>(.4,.55,.055)*rim;
    }else if(id<2.5){
        let grain=cc_noise(p*.8);color=mix(vec3<f32>(.16,.035,.012),vec3<f32>(.55,.21,.065),grain)*(.35+light*.85);
        let vein=pow(1.0-abs(detail-.5)*2.0,25.0);color+=vec3<f32>(1.3,.2,.015)*vein*exp(-age*.10);
    }else if(id<3.5){
        let layer=.5+.5*sin(p.y*.18+atan2(p.z,p.x)*4.0-age*2.0+detail*7.0);
        color=mix(vec3<f32>(.065,.09,.15),vec3<f32>(.38,.44,.57),layer)*(.45+light*.7)+vec3<f32>(.12,.24,.6)*rim;
    }else if(id<4.5){
        let spec=pow(max(0.0,dot(reflect(rd,normal),normalize(vec3<f32>(-.5,.8,.4)))),24.0);
        color=mix(vec3<f32>(.055,.23,.36),vec3<f32>(.58,.91,1.15),light)*(.75+detail*.3)+vec3<f32>(1.6)*spec+vec3<f32>(.18,.55,.85)*rim;
    }else{
        if(age<4.0 && length(p-vec3<f32>(0,37,0))<10.0+(1.0-smoothstep(.2,4.0,age))*53.0){
            color=vec3<f32>(.002,.004,.009)+vec3<f32>(.12,1.1,2.8)*pow(rim,2.0);
        }else{
            let veins=pow(1.0-abs(detail-.5)*2.0,13.0);
            color=mix(vec3<f32>(.025,.14,.27),vec3<f32>(.19,.76,1.15),light)+vec3<f32>(.12,.7,1.8)*veins+vec3<f32>(.13,.65,1.4)*rim;
        }
    }
    let dissolve=1.0-smoothstep(15.0,20.0,age);color*=.55+.45*dissolve;
    return vec4<f32>(color,travel);
}

fn cc_ground(uv:vec2<f32>,base:vec3<f32>,t:f32,id:f32)->vec3<f32>{
    let origin=frame.mod_params[0].xyz;let ro=frame.camera_position.xyz-origin;
    let rd=normalize(world_offset(uv,.00001));let depth=depth_at(uv);
    var limit=20000.0;if(depth>0.0){limit=length(world_offset(uv,depth));}
    var col=base;if(depth<=0.0){col=cc_sky(rd,t,id,base);}
    let age=t-17.0;let tint=cc_color(id);
    if(age<0.0){
        if(t>=14.8){
            let center=vec3<f32>(0,max(3.0,(17.0-t)*(17.0-t)*105.0),0);
            let shot=cc_projectile(ro/7.0,rd,center/7.0,t,id,limit/7.0);
            col=col*(1.0-shot.a)+shot.rgb;
            let trail=im_rayline(ro,rd,center,center+vec3<f32>(0,160,0));
            if(trail.y<limit){col+=tint*exp(-trail.x*.14)*.65;}
        }
        return col;
    }
    if(id>3.5 && id<4.5 && depth>0.0){
        let world_point=world_offset(uv,depth)+ro;
        var refraction=0.0;
        for(var ring=0u;ring<3u;ring++){
            let front=length(world_point.xz)-age*(25.0+f32(ring)*12.0);
            refraction+=exp(-abs(front)*.075)*sin(front*.8)*exp(-age*.11);
        }
        let center_clip=frame.projection*frame.view*vec4<f32>(-ro,1);
        let center_uv=vec2<f32>(center_clip.x/center_clip.w*.5+.5,.5-center_clip.y/center_clip.w*.5);
        let direction=normalize(uv-center_uv+vec2<f32>(.00001));
        let refracted_uv=clamp(uv+direction*refraction*.018,vec2<f32>(.001),vec2<f32>(.999));
        col=mix(col,textureSampleLevel(scene_color,linear_sampler,refracted_uv,0.0).rgb,.8);
    }
    let flash=exp(-age*8.0);col=mix(col,vec3<f32>(1.0,.92,.79),flash*.68);
    let sculpture=im_surface(ro,rd,age,id,limit);
    if(sculpture.w>=0.0){col=sculpture.rgb;limit=sculpture.w;}
    let bounds=cc_sphere(ro,rd,vec3<f32>(0,65,0),205.0);let begin=max(0.0,bounds.x);let end=min(limit,bounds.y);
    if(end>begin && age<22.0){
        let steps=select(28u,48u,frame.mod_params[1].w>.5);let stride=(end-begin)/f32(steps);
        var trans=1.0;var light=vec3<f32>(0);
        let jitter=cc_hash(vec3<f32>(floor(uv*frame.resolution.xy),0));
        for(var i=0u;i<48u;i++){
            if(i>=steps || trans<.025){break;}
            let dist=begin+(f32(i)+jitter)*stride;let p=ro+rd*dist;let f=im_field(p,age,id);
            let alpha=1.0-exp(-f.x*stride*.075);
            var ash=vec3<f32>(.085,.061,.042);var glow=tint*3.2+vec3<f32>(.6,.3,.1);
            if(id>.5 && id<1.5){ash=vec3<f32>(.25,.25,.055);glow=vec3<f32>(1.25,1.5,.23);}
            if(id>1.5 && id<2.5){ash=vec3<f32>(.31,.068,.023);glow=vec3<f32>(1.0,.23,.045);}
            if(id>2.5 && id<3.5){ash=vec3<f32>(.07,.09,.15);glow=vec3<f32>(.18,.36,.7);}
            if(id>3.5 && id<4.5){ash=vec3<f32>(.18,.28,.36);glow=vec3<f32>(.6,.82,.95);}
            if(id>4.5){ash=vec3<f32>(.035,.16,.25);glow=vec3<f32>(.20,1.1,1.8);}
            let sample=mix(ash,glow,f.y)+vec3<f32>(.4,.8,1.8)*f.z*2.0;
            light+=trans*alpha*sample;trans*=1.0-alpha;
        }
        col=col*trans+light;
    }
    // World-space lightning has geometry and depth, rather than flashing stripes attached to the monitor.
    if(id>2.5 && id<3.5 && age<17.0){
        for(var bolt=0u;bolt<7u;bolt++){
            let a=f32(bolt)*2.39996+floor(age*5.0)*.47;
            let root=vec3<f32>(cos(a)*65.0,0,sin(a)*65.0);
            var last=vec3<f32>(0,175,0);
            for(var j=1u;j<7u;j++){
                let f=f32(j)/6.0;let bend=sin(f*17.0+a)*14.0;
                let next=mix(vec3<f32>(0,175,0),root,f)+vec3<f32>(bend,0,cos(f*21.0+a)*9.0);
                let line=im_rayline(ro,rd,last,next);
                if(line.y<limit){col+=vec3<f32>(.25,.5,1.3)*(exp(-line.x*1.6)*1.6+exp(-line.x*.2)*.16)*(.35+.65*pow(max(0.0,sin(age*11.0+a)),4.0));}
                last=next;
            }
        }
    }
    // Saturn sends three separate tilted cutting rings across the landscape.
    if(id>3.5 && id<4.5 && age<12.0){
        for(var i=0u;i<3u;i++){
            let normal=normalize(vec3<f32>(.08+f32(i)*.04,1.0,.12-f32(i)*.07));
            let den=dot(rd,normal);
            if(abs(den)>.001){let d=dot(vec3<f32>(0,4.0+f32(i)*4.0,0)-ro,normal)/den;
                if(d>0.0 && d<limit){let p=ro+rd*d;let radius=length(p.xz);let ring=abs(radius-age*(25.0+f32(i)*12.0));
                    col+=vec3<f32>(.55,.79,1.0)*(exp(-ring*.5)*2.5+exp(-ring*.055)*.38)*exp(-age*.10);
                }
            }
        }
    }
    if(id<.5 && age<10.0){
        // Arcing streams of molten ejecta erupt around the jet and break into jagged waves.
        for(var arc=0u;arc<9u;arc++){
            let a=f32(arc)*2.39996;var last=vec3<f32>(0,4,0);
            for(var j=1u;j<8u;j++){
                let f=f32(j)/7.0;let radius=f*(36.0+age*12.0);let height=sin(f*3.14159265)*(32.0+age*4.0);
                let next=vec3<f32>(cos(a)*radius,height+sin(f*35.0+a)*2.0,sin(a)*radius);
                let line=im_rayline(ro,rd,last,next);
                if(line.y<limit){col+=vec3<f32>(1.9,.52,.035)*(exp(-line.x*.6)*.65+exp(-line.x*.12)*.07)*exp(-age*.12);}
                last=next;
            }
        }
    }
    // The terrain subsystem supplies only blocks actually removed from the world,
    // with their six real atlas faces; no procedural stand-in brown chunks.
    col=cc_debris(ro,rd,age,id,limit,col);
    if(depth>0.0){
        let p=world_offset(uv,depth)+ro;let radius=length(p.xz);let ground=exp(-abs(p.y)*.035);
        if(id<.5){let radial=pow(max(0.0,sin(atan2(p.z,p.x)*13.0+cc_noise(p*.09)*2.0)),12.0);col+=tint*radial*exp(-radius*.018)*ground*exp(-age*.12)*.8;}
        else if(id<1.5){let spiral=pow(.5+.5*sin(atan2(p.z,p.x)*4.0-radius*.13+age*1.2),5.0);col+=vec3<f32>(.28,.48,.045)*spiral*exp(-radius*.018)*ground*.3;}
        else if(id<2.5){let ring=abs(radius-age*26.0);col+=tint*exp(-ring*.16)*ground*exp(-age*.09)*1.3;}
        else if(id>4.5){let pull=abs(radius-max(0.0,90.0-age*40.0));col+=vec3<f32>(.06,.34,.8)*exp(-pull*.18)*ground*(1.0-smoothstep(1.5,2.5,age));}
    }
    return col;
}
