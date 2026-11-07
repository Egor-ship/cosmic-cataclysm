// Cosmic Cataclysm. Original procedural imagery; appended to Horizon's post prelude.
// p0: target.xyz / timeline seconds. p1: planet / cinematic / terrain / quality.
const CC_PI: f32 = 3.14159265;
fn cc_hash(p: vec3<f32>) -> f32 { return fract(sin(dot(p, vec3<f32>(127.1,311.7,74.7))) * 43758.5453); }
fn cc_noise(p: vec3<f32>) -> f32 {
    let i=floor(p); let f=fract(p); let u=f*f*(3.0-2.0*f);
    return mix(mix(mix(cc_hash(i),cc_hash(i+vec3<f32>(1,0,0)),u.x),mix(cc_hash(i+vec3<f32>(0,1,0)),cc_hash(i+vec3<f32>(1,1,0)),u.x),u.y),mix(mix(cc_hash(i+vec3<f32>(0,0,1)),cc_hash(i+vec3<f32>(1,0,1)),u.x),mix(cc_hash(i+vec3<f32>(0,1,1)),cc_hash(i+vec3<f32>(1,1,1)),u.x),u.y),u.z);
}
fn cc_fbm(p: vec3<f32>) -> f32 { return cc_noise(p)*0.57+cc_noise(p*2.03)*0.28+cc_noise(p*4.09)*0.15; }
fn cc_color(id: f32) -> vec3<f32> {
    if(id<0.5){return vec3<f32>(1.0,0.48,0.12);} if(id<1.5){return vec3<f32>(0.72,1.0,0.16);}
    if(id<2.5){return vec3<f32>(1.0,0.19,0.055);} if(id<3.5){return vec3<f32>(0.55,0.69,1.0);}
    if(id<4.5){return vec3<f32>(1.0,0.77,0.36);} return vec3<f32>(0.13,0.48,1.0);
}
fn cc_sphere(ro: vec3<f32>,rd: vec3<f32>,center: vec3<f32>,r:f32)->vec2<f32>{
    let oc=ro-center; let b=dot(oc,rd); let h=b*b-dot(oc,oc)+r*r;
    if(h<0.0){return vec2<f32>(-1.0);} let q=sqrt(h); return vec2<f32>(-b-q,-b+q);
}
fn cc_ray(ro: vec3<f32>,at: vec3<f32>,uv:vec2<f32>,fov:f32)->vec3<f32>{
    let f=normalize(at-ro); let r=normalize(cross(f,vec3<f32>(0,1,0))); let u=cross(r,f);
    let p=(uv*2.0-1.0)*vec2<f32>(frame.resolution.x/frame.resolution.y,-1.0);
    return normalize(f+r*p.x*fov+u*p.y*fov);
}
fn cc_planet(ro:vec3<f32>,rd:vec3<f32>,center:vec3<f32>,radius:f32,id:f32,time:f32,back:vec3<f32>)->vec3<f32>{
    var col=back; let hit=cc_sphere(ro,rd,center,radius);
    let glow=cc_sphere(ro,rd,center,radius*1.07);
    let tint=cc_color(id);
    if(glow.y>0.0){let nearest=max(0.0,-dot(ro-center,rd));let d=length(ro+rd*nearest-center)/radius; col+=tint*exp(-abs(d-1.0)*24.0)*0.28;}
    if(hit.x>0.0){
        let n=normalize(ro+rd*hit.x-center); let p=vec3<f32>(n.x*cos(time*0.035)+n.z*sin(time*0.035),n.y,n.z*cos(time*0.035)-n.x*sin(time*0.035));
        let grain=cc_fbm(p*13.0); var surface=mix(tint*0.14,tint,grain);
        if(id<0.5){surface=mix(vec3<f32>(0.11,0.085,0.07),vec3<f32>(0.64,0.53,0.41),grain);surface+=tint*pow(max(0.0,1.0-abs(cc_noise(p*28.0)-0.49)*36.0),3.0)*0.4;}
        else if(id<1.5){surface=mix(vec3<f32>(0.19,0.12,0.015),vec3<f32>(0.93,0.67,0.22),cc_fbm(p*6.0+vec3<f32>(0,time*0.08,0)));}
        else if(id<2.5){surface=mix(vec3<f32>(0.20,0.035,0.012),vec3<f32>(0.82,0.29,0.11),grain);surface+=vec3<f32>(0.23,0.13,0.08)*smoothstep(0.75,0.96,abs(p.y));}
        else if(id<4.5){let bands=sin(p.y*38.0+cc_noise(p*5.0)*7.0);surface=mix(vec3<f32>(0.20,0.105,0.065),vec3<f32>(0.94,0.76,0.49),bands*0.5+0.5); let eye=exp(-length((p.xy-vec2<f32>(0.26,-0.2))*vec2<f32>(7,13)));surface=mix(surface,vec3<f32>(0.63,0.17,0.08),eye);}
        else if(id<5.5){surface=mix(vec3<f32>(0.006,0.035,0.21),vec3<f32>(0.13,0.43,0.92),0.5+0.5*sin(p.y*28.0+grain*8.0));}
        else {let land=cc_fbm(p*4.0);surface=mix(vec3<f32>(0.012,0.08,0.24),vec3<f32>(0.09,0.28,0.13),smoothstep(0.49,0.55,land));surface=mix(surface,vec3<f32>(0.82,0.88,0.92),smoothstep(0.61,0.75,cc_fbm(p*9.0+vec3<f32>(time*0.015))));}
        let sunlight=max(0.0,dot(n,normalize(vec3<f32>(-0.6,0.4,0.7))));
        col=surface*(0.045+sunlight*1.16)+tint*pow(1.0-max(0.0,dot(n,-rd)),4.0)*0.22;
    }
    if(id>3.5 && id<4.5){
        let normal=normalize(vec3<f32>(0.2,1.0,0.35));let den=dot(rd,normal);
        if(abs(den)>0.0001){let t=dot(center-ro,normal)/den;let r=length(ro+rd*t-center)/radius;
            if(t>0.0 && r>1.28 && r<2.25 && (hit.x<0.0 || t<hit.x)){let lines=0.5+0.5*sin(r*190.0);let opacity=(0.38+lines*0.33)*(1.0-smoothstep(2.1,2.25,r)); col=mix(col,vec3<f32>(0.83,0.69,0.44)*(0.42+lines*0.4),opacity);}
        }
    }
    return col;
}
fn cc_space(uv:vec2<f32>,t:f32,id:f32)->vec3<f32>{
    let travel=smoothstep(8.0,15.0,t);let launch=smoothstep(4.0,8.0,t);
    var ro=vec3<f32>(sin(t*0.12)*1.4,0.6,7.0);
    var at=vec3<f32>(0.0);
    let core=mix(vec3<f32>(-0.6,0.2,2.4),vec3<f32>(14.0,-2.0,-25.0),travel);
    let direction=normalize(vec3<f32>(14.6,-2.2,-27.4));
    if(t>8.0){ro=core-direction*5.0+vec3<f32>(1.4,0.8,0);at=core+direction*3.0;}
    let rd=cc_ray(ro,at,uv,0.53);
    let cells=floor(rd*1200.0);let stars=pow(cc_hash(cells),190.0);
    var col=vec3<f32>(0.002,0.003,0.012)+vec3<f32>(0.7,0.8,1.0)*stars;
    col+=vec3<f32>(0.035,0.018,0.07)*pow(cc_fbm(rd*4.0),3.0);
    col=cc_planet(ro,rd,vec3<f32>(14,-2,-30),4.2,6.0,t,col);
    col=cc_planet(ro,rd,vec3<f32>(0),2.15,id,t,col);
    let tint=cc_color(id);let near=max(0.0,dot(core-ro,rd));let d=length(ro+rd*near-core);
    if(t>4.0){col+=tint*exp(-d*d*35.0)*(0.5+launch*3.0)+vec3<f32>(1)*exp(-d*d*340.0)*launch*3.0;}
    if(t>8.0){
        for(var i=0u;i<20u;i++){let k=f32(i)/19.0;let tail=core-direction*k*5.5+vec3<f32>(sin(k*14.0+t*4.0)*0.16*k,cos(k*15.0+t*3.0)*0.13*k,0);let along=max(0.0,dot(tail-ro,rd));let dist=length(ro+rd*along-tail);col+=tint*exp(-dist*dist/(0.012+k*0.08))*(1.0-k)*0.30;}
        // Different projectile silhouettes, not just a palette swap.
        for(var j=0u;j<16u;j++){
            let k=f32(j)/16.0;let angle=k*6.2831853+t*3.0;
            var orbit=vec3<f32>(cos(angle)*0.42,sin(angle)*0.42,0);
            if(id<0.5){orbit=vec3<f32>((k-0.5)*0.8,sin(angle)*0.1,(k-0.5)*0.6);}
            else if(id<1.5){orbit=vec3<f32>(cos(angle)*0.7,sin(angle)*0.35,(k-0.5)*1.7);}
            else if(id<2.5){orbit=vec3<f32>(cos(angle)*0.95,sin(angle)*0.65,sin(angle*3.0)*0.2);}
            else if(id<3.5){orbit=vec3<f32>((k-0.5)*2.2,sin(k*35.0+t*13.0)*0.4,0);}
            else if(id<4.5){orbit=vec3<f32>(cos(angle)*1.2,sin(angle)*0.28,sin(angle)*0.7);}
            else {orbit=vec3<f32>(cos(angle)*0.65,sin(angle)*0.08,sin(angle)*0.65);}
            let bead=core+orbit;let a=max(0.0,dot(bead-ro,rd));let d2=dot(ro+rd*a-bead,ro+rd*a-bead);
            let width=select(0.008,0.025,id>0.5 && id<2.5);
            col+=tint*exp(-d2/width)*0.75;
        }
        if(id>4.5){let cp=ro+rd*near-core;let singularity=exp(-dot(cp,cp)*100.0);col=mix(col,vec3<f32>(0.001),singularity*0.98);}
    }
    let vignette=1.0-smoothstep(0.3,0.85,length(uv-0.5))*0.4;
    return col*vignette;
}
fn cc_box(ro:vec3<f32>,rd:vec3<f32>,center:vec3<f32>,size:vec3<f32>)->f32{
    let safe=select(vec3<f32>(0.00001),rd,abs(rd)>vec3<f32>(0.00001));let inv=1.0/safe;
    let a=(center-size-ro)*inv;let b=(center+size-ro)*inv;let lo=min(a,b);let hi=max(a,b);
    let near=max(lo.x,max(lo.y,lo.z));let far=min(hi.x,min(hi.y,hi.z));return select(-1.0,max(near,0.0),far>max(near,0.0));
}
fn cc_ground(uv:vec2<f32>,base:vec3<f32>,t:f32,id:f32)->vec3<f32>{
    let impact_origin=frame.mod_params[0].xyz;let ro=frame.camera_position.xyz-impact_origin;
    let rd=normalize(world_offset(uv,0.00001));let depth=depth_at(uv);
    var limit=10000.0;if(depth>0.0){limit=length(world_offset(uv,depth));}
    let tint=cc_color(id);var col=base;let age=t-17.0;
    if(age<0.0){
        if(t<15.0){return col;}
        let projectile=vec3<f32>(0,max(1.0,(17.0-t)*(17.0-t)*140.0),0);
        let along=max(0.0,dot(projectile-ro,rd));let d=length(ro+rd*along-projectile);
        if(along<limit){col+=tint*exp(-d*d/30.0)*4.0;col+=vec3<f32>(1)*exp(-d*d/3.0)*3.0;}
        return col;
    }
    let flash=exp(-age*7.0);col=mix(col,vec3<f32>(1.0,0.91,0.75),flash*0.82);
    let center=vec3<f32>(0,min(32.0,age*10.0),0);let radius=min(112.0,8.0+age*32.0);
    let bounds=cc_sphere(ro,rd,center,radius);let begin=max(0.0,bounds.x);let end=min(limit,bounds.y);
    if(end>begin){
        let steps=select(20u,36u,frame.mod_params[1].w>0.5);let step=(end-begin)/f32(steps);var transmission=1.0;var light=vec3<f32>(0);
        for(var i=0u;i<36u;i++){if(i>=steps){break;}let dist=begin+(f32(i)+0.5)*step;let p=ro+rd*dist-center;
            let n=cc_fbm(p*0.065+vec3<f32>(0,-age*0.7,0));
            var shape=length(p*vec3<f32>(1.0,1.05,1.0))/radius;
            if(id>0.5 && id<1.5){shape=length(p*vec3<f32>(0.8,1.6,0.8))/radius;}
            if(id>3.5 && id<4.5){shape=length(p*vec3<f32>(0.85,2.4,0.85))/radius;}
            if(id>4.5){shape=length(p*vec3<f32>(1.3,0.8,1.3))/radius;}
            let density=max(0.0,(1.0-shape)*1.6+n*0.7-0.35)*exp(-age*0.12);
            let a=1.0-exp(-density*step*0.065);
            let heat=exp(-age*0.18)*smoothstep(0.18,0.65,n);
            light+=transmission*a*mix(vec3<f32>(0.10,0.075,0.065),tint*6.0+vec3<f32>(1.4)*heat,heat);
            transmission*=1.0-a;
        }
        col=col*transmission+light;
    }
    // Tangible looking ballistic rock plates, with visible planar faces, never point sprites.
    let count=select(24u,48u,frame.mod_params[1].w>0.5);var closest=limit;
    for(var i=0u;i<48u;i++){if(i>=count){break;}let seed=f32(i);let h=cc_hash(vec3<f32>(seed,5,2));let angle=seed*2.399963;
        let flight=max(0.0,age-cc_hash(vec3<f32>(seed,1,7))*0.9);let speed=12.0+h*20.0;
        let radial=vec2<f32>(cos(angle),sin(angle));let center2=vec3<f32>(radial.x*(8.0+flight*speed),max(-12.0,(22.0+h*28.0)*flight-5.5*flight*flight),radial.y*(8.0+flight*speed));
        let half=vec3<f32>(1.0+h*2.9,0.7+h*1.3,1.0+h*2.5);let hit=cc_box(ro,rd,center2,half);
        if(hit>=0.0 && hit<closest && flight>0.01 && flight<8.5){closest=hit;let q=(ro+rd*hit-center2)/half;let face=max(abs(q.x),max(abs(q.y),abs(q.z)));var shade=0.5;if(abs(q.y)>face-0.01){shade=0.9;}else if(abs(q.x)>face-0.01){shade=0.65;}
            let rock=vec3<f32>(0.20,0.16,0.13)*(0.7+cc_noise((ro+rd*hit)*1.4)*0.6);col=rock*shade+tint*exp(-flight*0.7)*0.32;
        }
    }
    if(depth>0.0){let p=world_offset(uv,depth)+ro;let distance=length(p.xz);let ring=abs(distance-age*36.0);let ground=exp(-abs(p.y)*0.025);col+=tint*exp(-ring*0.25)*ground*exp(-age*0.10)*1.6;
        if(id>1.5 && id<2.5){let ridges=pow(0.5+0.5*sin(distance*0.33-age*7.0),12.0);col+=tint*ridges*ground*exp(-age*0.25-distance*0.009)*0.8;}
        if(id>3.5 && id<4.5){for(var j=0u;j<3u;j++){let r=age*(20.0+f32(j)*12.0);col+=tint*exp(-abs(distance-r)*0.42)*ground*exp(-age*0.17);}}
    }
    // Six silhouettes: radial melt, toxic veil, tectonic rings, lightning, rings of ice, gravity distortion.
    if(id>2.5 && id<3.5 && age<6.0){let bolt=pow(max(0.0,1.0-abs(sin(uv.x*54.0+cc_noise(vec3<f32>(uv.y*40.0,floor(age*9.0),0))*5.0))*65.0),2.0);col+=tint*bolt*exp(-age*0.35)*0.7;}
    if(id>4.5){col+=tint*exp(-length(uv-0.5)*7.0)*exp(-age*0.3)*0.22;}
    return col;
}
@fragment fn fs_main(v:StageIn)->@location(0) vec4<f32>{
    let t=frame.mod_params[0].w+frame.time.w/20.0;let id=frame.mod_params[1].x;let uv=v.uv;
    let base=textureSampleLevel(scene_color,linear_sampler,uv,0.0).rgb;
    var col=cc_ground(uv,base,t,id);
    if(frame.mod_params[1].y>0.5 && t<17.0){let blend=smoothstep(0.0,2.8,t)*(1.0-smoothstep(14.8,16.5,t));col=mix(col,cc_space(uv,t,id),blend);
        let bars=smoothstep(0.0,1.5,t)*(1.0-smoothstep(15.0,16.4,t));if(uv.y<0.075*bars || uv.y>1.0-0.075*bars){col=vec3<f32>(0.002);}
    }
    col=vec3<f32>(1.0)-exp(-max(col,vec3<f32>(0))*1.05);
    // Fade back to the unmodified game at the end of the aftermath.
    col=mix(col,base,smoothstep(31.0,35.0,t));return vec4<f32>(col,1.0);
}


