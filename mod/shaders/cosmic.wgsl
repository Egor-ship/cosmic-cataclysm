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
fn cc_box(ro:vec3<f32>,rd:vec3<f32>,center:vec3<f32>,size:vec3<f32>)->f32{
    let safe=select(vec3<f32>(0.00001),rd,abs(rd)>vec3<f32>(0.00001));let inv=1.0/safe;
    let a=(center-size-ro)*inv;let b=(center+size-ro)*inv;let lo=min(a,b);let hi=max(a,b);
    let near=max(lo.x,max(lo.y,lo.z));let far=min(hi.x,min(hi.y,hi.z));return select(-1.0,max(near,0.0),far>max(near,0.0));
}

// Six procedural worlds and solid ray-traced weapons. No vanilla particles.
fn cs_rot(p:vec2<f32>,a:f32)->vec2<f32>{return vec2<f32>(p.x*cos(a)-p.y*sin(a),p.x*sin(a)+p.y*cos(a));}
fn cs_detail(p:vec3<f32>)->f32{return cc_fbm(p)*0.68+cc_noise(p*8.1)*0.22+cc_noise(p*23.7)*0.10;}
fn cs_box(p:vec3<f32>,b:vec3<f32>)->f32{let q=abs(p)-b;return length(max(q,vec3<f32>(0)))+min(max(q.x,max(q.y,q.z)),0.0);}
fn cs_torus(p:vec3<f32>,r:f32,w:f32)->f32{return length(vec2<f32>(length(p.xy)-r,p.z))-w;}
fn cs_craters(uv:vec2<f32>,scale:f32)->vec2<f32>{
    let p=uv*scale;let cell=floor(p);var bowl=0.0;var rim=0.0;
    for(var y=-1;y<=1;y++){for(var x=-1;x<=1;x++){
        let c=cell+vec2<f32>(f32(x),f32(y));let h=cc_hash(vec3<f32>(c,3.1));
        let center=c+vec2<f32>(cc_hash(vec3<f32>(c,1.7)),cc_hash(vec3<f32>(c,7.3)));
        let d=length(p-center)/(0.12+h*0.28);bowl+=max(0.0,1.0-d*d)*0.28;rim+=exp(-pow((d-1.0)*11.0,2.0))*0.16;
    }}return vec2<f32>(bowl,rim);
}
fn cs_surface(n:vec3<f32>,id:f32,time:f32)->vec3<f32>{
    let spin=cs_rot(n.xz,time*0.018);let p=vec3<f32>(spin.x,n.y,spin.y);
    let uv=vec2<f32>(atan2(p.z,p.x)/6.2831853+0.5,asin(clamp(p.y,-0.999,0.999))/3.14159265+0.5);
    let grain=cs_detail(p*9.0);var surface=vec3<f32>(0.2);
    if(id<0.5){
        let craters=cs_craters(uv,26.0)+cs_craters(uv,61.0)*0.45;
        let faults=pow(max(0.0,1.0-abs(cc_fbm(p*12.0)-0.48)*37.0),3.0);
        surface=mix(vec3<f32>(0.12,0.105,0.09),vec3<f32>(0.63,0.52,0.40),grain)*(1.0-craters.x*2.2)+vec3<f32>(craters.y*0.9)+vec3<f32>(1.5,0.3,0.018)*faults*0.26;
    }else if(id<1.5){
        let v=cs_rot(p.xz,2.5*p.y+sin(p.y*8.0)*0.3+time*0.045);let clouds=cc_fbm(vec3<f32>(v.x,p.y,v.y)*9.0);
        surface=mix(vec3<f32>(0.16,0.09,0.012),vec3<f32>(1.1,0.74,0.23),smoothstep(0.22,0.78,clouds));
        surface+=vec3<f32>(0.28,0.32,0.06)*pow(max(0.0,1.0-abs(clouds-0.53)*36.0),2.0);
    }else if(id<2.5){
        let craters=cs_craters(uv,39.0);let canyon=pow(max(0.0,1.0-abs(p.y+sin(p.x*3.0)*0.1)*28.0),2.0);
        surface=mix(vec3<f32>(0.19,0.035,0.016),vec3<f32>(0.83,0.31,0.12),grain)*(1.0-craters.x*1.5-canyon*0.6)+vec3<f32>(craters.y*0.6);
        surface=mix(surface,vec3<f32>(0.75,0.68,0.59),smoothstep(0.82,0.98,abs(p.y)+cc_noise(p*32.0)*0.05));
    }else if(id<3.5){
        let eye=p.xy-vec2<f32>(0.31,-0.17);let swirl=exp(-dot(eye*vec2<f32>(3.2,7.0),eye*vec2<f32>(3.2,7.0)));
        let wind=cc_fbm(p*vec3<f32>(12,28,12)+vec3<f32>(time*0.04,0,0));
        let latitude=p.y*41.0+sin(p.x*8.0+wind*8.0)*0.65+wind*5.0+swirl*sin(atan2(eye.y,eye.x)*4.0+length(eye)*70.0)*2.5;
        surface=mix(vec3<f32>(0.25,0.13,0.065),vec3<f32>(0.94,0.80,0.61),0.5+0.5*sin(latitude));
        surface=mix(surface,mix(vec3<f32>(0.35,0.055,0.018),vec3<f32>(0.92,0.36,0.14),wind),swirl*0.94)*(0.72+grain*0.6);
    }else if(id<4.5){
        let flow=cc_fbm(p*vec3<f32>(7,35,7)+vec3<f32>(time*0.018,0,0));let bands=sin(p.y*70.0+flow*3.2)*0.13+sin(p.y*17.0+flow)*0.27;
        surface=mix(vec3<f32>(0.43,0.31,0.15),vec3<f32>(0.99,0.87,0.60),0.55+bands)*(0.84+grain*0.28);
        surface=mix(surface,vec3<f32>(0.32,0.48,0.42),exp(-length(p.xz)*7.0)*0.65);
    }else if(id<5.5){
        let eye=p.xy-vec2<f32>(-0.28,0.21);let swirl=exp(-dot(eye*vec2<f32>(4.0,7.0),eye*vec2<f32>(4.0,7.0)));
        let vapor=cc_fbm(p*vec3<f32>(8,25,8)+vec3<f32>(time*0.05,0,0));
        surface=mix(vec3<f32>(0.008,0.028,0.19),vec3<f32>(0.06,0.32,0.83),smoothstep(0.25,0.75,vapor));
        surface=mix(surface,vec3<f32>(0.003,0.009,0.06),swirl*0.84);
        surface+=vec3<f32>(0.25,0.58,0.85)*pow(max(0.0,1.0-abs(vapor+swirl*0.13-0.56)*29.0),3.0)*0.4;
    }else{
        let land=smoothstep(0.47,0.52,cc_fbm(p*4.1));surface=mix(vec3<f32>(0.006,0.045,0.14),mix(vec3<f32>(0.06,0.20,0.08),vec3<f32>(0.50,0.39,0.17),cc_fbm(p*14.0)),land);
        surface=mix(surface,vec3<f32>(0.94),smoothstep(0.53,0.69,cc_fbm(p*9.0+vec3<f32>(time*0.008,0,0)))*0.92);
        surface=mix(surface,vec3<f32>(0.83,0.92,0.97),smoothstep(0.84,0.99,abs(p.y)));
    }return surface;
}
fn cc_planet(ro:vec3<f32>,rd:vec3<f32>,center:vec3<f32>,radius:f32,id:f32,time:f32,back:vec3<f32>)->vec3<f32>{
    var col=back;let hit=cc_sphere(ro,rd,center,radius);let tint=select(cc_color(id),vec3<f32>(0.18,0.47,1),id>5.5);
    let nearest=max(0.0,-dot(ro-center,rd));let altitude=length(ro+rd*nearest-center)/radius;
    if(nearest>0.0){col+=tint*exp(-abs(altitude-1.0)*40.0)*0.32;}
    if(hit.x>0.0){
        let n=normalize(ro+rd*hit.x-center);let sun=normalize(vec3<f32>(-0.6,0.38,0.7));let diffuse=max(0.0,dot(n,sun));let rim=pow(1.0-max(0.0,dot(n,-rd)),4.0);
        col=cs_surface(n,id,time)*(0.028+diffuse*1.34)*(0.92+cc_fbm(n*31.0)*0.16)+tint*rim*0.22;
        if(id>5.5){col+=vec3<f32>(0.025,0.09,0.21)*pow(max(0.0,dot(reflect(-sun,n),-rd)),50.0);}
    }
    if(id>3.5 && id<4.5){
        let normal=normalize(vec3<f32>(0.23,1.0,0.30));let den=dot(rd,normal);
        if(abs(den)>0.0001){let distance=dot(center-ro,normal)/den;let pt=ro+rd*distance-center;let r=length(pt)/radius;
            if(distance>0.0 && r>1.25 && r<2.35 && (hit.x<0.0 || distance<hit.x)){
                let lines=sin(r*330.0)*0.13+sin(r*97.0)*0.12+cc_noise(pt*72.0)*0.16;
                let gap=1.0-smoothstep(0.018,0.04,abs(r-1.83));let light=normalize(vec3<f32>(-0.6,0.38,0.7));let shadow=select(1.0,0.18,dot(pt,light)<0.0 && length(cross(pt,light))<radius);
                col=mix(col,vec3<f32>(0.72,0.58,0.36)*(0.68+lines)*shadow,(0.68+lines)*(1.0-gap*0.94));
            }
        }
    }return col;
}
fn cs_weapon_map(p:vec3<f32>,id:f32,time:f32)->f32{
    var d=1000.0;
    if(id<0.5){
        d=max(length(p.xy)-(0.14+0.25*clamp((2.6-p.z)/4.4,0.0,1.0)),abs(p.z)-2.6);
        let angle=atan2(p.y,p.x);let repeat=fract(angle/6.2831853*6.0+0.5)-0.5;
        let fin=vec3<f32>(cos(repeat*6.2831853/6.0)*length(p.xy)-0.43,sin(repeat*6.2831853/6.0)*length(p.xy),p.z+0.45);
        d=min(d,cs_box(fin,vec3<f32>(0.48,0.055,1.25)));
    }else if(id<1.5){
        d=length(p)-(0.95+sin(atan2(p.y,p.x)*3.0+p.z*5.5-time*1.3)*0.16);
        d=min(d,cs_torus(vec3<f32>(cs_rot(p.xy,p.z*1.8-time*0.8),p.z),1.22+sin(p.z*3.0)*0.10,0.095));
    }else if(id<2.5){
        let q=vec3<f32>(cs_rot(p.xy,time*0.27),p.z);d=(abs(q.x)+abs(q.y)+abs(q.z)*0.72-1.55)*0.54+(cc_noise(q*8.0)-0.5)*0.10;
        for(var i=0u;i<6u;i++){let a=f32(i)*2.399963+time*0.4;let c=vec3<f32>(cos(a)*1.5,sin(a)*1.5,sin(a*2.0)*0.45);d=min(d,cs_box(q-c,vec3<f32>(0.14,0.18,0.24)));}
    }else if(id<3.5){
        let q=vec3<f32>(cs_rot(p.xy,time*0.35),p.z);d=length(p)-0.65;
        d=min(d,cs_torus(q,1.25,0.085));d=min(d,cs_torus(vec3<f32>(q.x,q.z,q.y),1.25,0.085));d=min(d,cs_torus(vec3<f32>(q.z,q.y,q.x),1.25,0.085));
    }else if(id<4.5){
        let q=vec3<f32>(cs_rot(p.xy,time*0.4),p.z);d=min(length(q)-0.46,cs_torus(q,1.65,0.11));
        d=min(d,cs_torus(vec3<f32>(q.xy,q.z-0.25),1.25,0.055));d=min(d,cs_torus(vec3<f32>(q.xy,q.z+0.25),1.25,0.055));
        let spokes=abs(sin(atan2(q.y,q.x)*4.0));d=min(d,max(length(q.xy)-1.65,max(0.48-length(q.xy),max(abs(q.z)-0.045,(spokes-0.08)*0.5))));
    }else{
        let q=vec3<f32>(cs_rot(p.xy,time*0.22),p.z);d=(abs(q.x)+abs(q.y)+abs(q.z)*0.42-0.95)*0.60;
        d=min(d,cs_torus(vec3<f32>(q.x,q.z*0.4,q.y),1.2,0.045));
    }return d;
}
// Premultiplied radiance rgb / body coverage alpha; col = col*(1-a)+rgb.
fn cc_projectile(ro:vec3<f32>,rd:vec3<f32>,center:vec3<f32>,time:f32,id:f32,limit:f32)->vec4<f32>{
    let axis=select(normalize(vec3<f32>(14.6,-2.2,-27.4)),vec3<f32>(0,-1,0),time>=15.0);
    let right=normalize(cross(axis,vec3<f32>(0.01,0.0,1.0)));let up=cross(right,axis);let scale=select(1.0,7.0,time>=15.0);let o=(ro-center)/scale;
    let local_o=vec3<f32>(dot(o,right),dot(o,up),dot(o,axis));let local_d=vec3<f32>(dot(rd,right),dot(rd,up),dot(rd,axis));
    let bounds=cc_sphere(local_o,local_d,vec3<f32>(0),3.1);var distance=max(0.0,bounds.x);let far=min(bounds.y,limit/scale);var body=vec3<f32>(0);var coverage=0.0;let tint=cc_color(id);
    if(far>distance){for(var i=0u;i<72u;i++){
        let p=local_o+local_d*distance;let field=cs_weapon_map(p,id,time);
        if(field<0.006){
            let e=0.008;let n=normalize(vec3<f32>(cs_weapon_map(p+vec3<f32>(e,0,0),id,time)-cs_weapon_map(p-vec3<f32>(e,0,0),id,time),cs_weapon_map(p+vec3<f32>(0,e,0),id,time)-cs_weapon_map(p-vec3<f32>(0,e,0),id,time),cs_weapon_map(p+vec3<f32>(0,0,e),id,time)-cs_weapon_map(p-vec3<f32>(0,0,e),id,time)));
            let light=normalize(vec3<f32>(-0.5,0.8,0.6));let diffuse=max(0.0,dot(n,light));let spec=pow(max(0.0,dot(reflect(-light,n),-local_d)),28.0);let grain=cs_detail(p*15.0);let grooves=pow(max(0.0,1.0-abs(sin(p.z*15.0))*19.0),3.0);
            var metal=mix(vec3<f32>(0.035,0.042,0.055),vec3<f32>(0.25,0.29,0.33),grain);var emission=tint*grooves*1.1;
            if(id>0.5 && id<1.5){metal=mix(vec3<f32>(0.07,0.12,0.015),vec3<f32>(0.42,0.48,0.10),grain);emission=tint*pow(max(0.0,1.0-abs(sin(atan2(p.y,p.x)*3.0+p.z*5.5-time))*8.0),3.0)*0.9;}
            else if(id>1.5 && id<2.5){metal=mix(vec3<f32>(0.12,0.026,0.008),vec3<f32>(0.51,0.19,0.07),grain);emission=tint*pow(max(0.0,1.0-abs(cc_noise(p*9.0)-0.5)*30.0),3.0)*2.0;}
            else if(id>2.5 && id<3.5){metal=vec3<f32>(0.09,0.14,0.22);emission=tint*0.08;if(length(p)<0.75){let cloud=cc_fbm(p*13.0+vec3<f32>(time*0.3,0,0));metal=mix(vec3<f32>(0.015,0.035,0.09),vec3<f32>(0.4,0.63,0.85),cloud);emission=tint*(0.12+cloud*0.35)+vec3<f32>(0.5,0.8,1.0)*pow(max(0.0,1.0-abs(cloud-0.51)*32.0),3.0);}}
            else if(id>3.5 && id<4.5){metal=mix(vec3<f32>(0.16,0.27,0.39),vec3<f32>(0.69,0.86,0.96),grain);emission=tint*grooves*0.45;}
            else if(id>4.5){metal=vec3<f32>(0.015,0.035,0.09);emission=tint*pow(1.0-max(0.0,dot(n,-local_d)),3.0)*2.7;}
            body=metal*(0.18+diffuse*1.3)+vec3<f32>(spec*0.9)+emission;coverage=1.0;break;
        }distance+=max(field*0.70,0.005);if(distance>far){break;}
    }}
    var glow=vec3<f32>(0);
    for(var j=0u;j<18u;j++){
        let k=f32(j)/17.0;let twist=k*14.0-time*4.0;let tail=vec3<f32>(cos(twist)*k*0.28,sin(twist)*k*0.28,-2.0-k*7.0);
        let along=dot(tail-local_o,local_d);let delta=local_o+local_d*along-tail;let width=0.16+k*0.28;
        if(along>0.0 && along*scale<limit){glow+=tint*exp(-dot(delta,delta)/(width*width))*(1.0-k)*0.15;}
    }return vec4<f32>(body+glow*(1.0-coverage),coverage);
}
struct CsCamera { eye:vec3<f32>, aim:vec3<f32>, roll:f32, fov:f32 }
const CS_EARTH:vec3<f32> = vec3<f32>(14,-2,-30);
// A continuous radial exclusion constraint. All source shots remain on the front hemisphere,
// so the safeguard cannot teleport the eye through the centre during shot interpolation.
fn cs_safe_eye(position:vec3<f32>,id:f32)->vec3<f32>{
    var p=position;let source_min=select(2.8,5.5,id>3.5 && id<4.5);
    let d=length(p);p*=max(1.0,source_min/max(d,0.001));
    let e=p-CS_EARTH;let ed=length(e);p=CS_EARTH+e*max(1.0,4.85/max(ed,0.001));
    return p;
}
fn cs_camera(time:f32,id:f32,core:vec3<f32>,axis:vec3<f32>)->CsCamera{
    let t=min(time,8.0);let u=max(0.0,time-8.0);let side=normalize(cross(axis,vec3<f32>(0,1,0)));let up=cross(side,axis);
    var angle=0.0;var radius=7.0;var height=1.0;var chase=core-axis*7.0+side*3.0+up;var roll=0.0;var zoom=0.48;
    if(id<0.5){
        // Mercury: fast banking orbit, then a low side-parallel tracking shot.
        angle=-0.63+t*0.14;radius=7.8-t*0.19;height=0.65+sin(t*0.65)*0.5;
        chase=core-axis*(5.6+sin(u*0.35)*0.4)+side*(3.2+sin(u*0.75)*1.1)+up*(-0.25+sin(u*0.55)*0.65);
        roll=-0.12*sin(time*0.65);zoom=0.49;
    }else if(id<1.5){
        // Venus: rising spiral reveal, then a complete corkscrew round the shell.
        angle=-0.45+t*0.15;radius=7.2-t*0.16;height=-0.2+t*0.38;
        chase=core-axis*7.0+side*(cos(u*0.72)*3.3)+up*(sin(u*0.72)*2.4);
        roll=0.14*sin(time*0.55);zoom=0.51;
    }else if(id<2.5){
        // Mars: high tilted reveal and an asteroid side flyby which widens toward Earth.
        angle=0.61-t*0.13;radius=8.6-t*0.20;height=3.6-t*0.39;
        let wide=smoothstep(0.0,4.0,u);chase=core-axis*mix(2.9,8.0,wide)+side*mix(7.0,3.6,wide)+up*(1.8+sin(u*0.5)*0.8);
        roll=0.22*cos(time*0.27);zoom=0.48;
    }else if(id<3.5){
        // Jupiter: crane from below to above the storm, then an orbit of its gyroscope.
        angle=-0.36+t*0.07;radius=7.1;height=-2.6+t*0.82;
        chase=core-axis*6.6+side*(cos(u*0.52)*3.7)+up*(sin(u*0.52)*3.4);
        roll=-0.08*sin(time*0.42);zoom=0.53;
    }else if(id<4.5){
        // Saturn: skirt the ring edge, then sweep from blade profile to its broad face.
        angle=-0.65+t*0.12;radius=8.3-t*0.14;height=2.3+sin(t*0.45)*0.45;
        let reveal=smoothstep(0.0,5.5,u);chase=core-axis*mix(4.0,8.0,reveal)+side*mix(7.0,2.5,reveal)+up*(0.9+sin(u*0.45)*0.8);
        roll=0.10*cos(time*0.38);zoom=0.54;
    }else{
        // Neptune: restrained approach, a suspended orbit, then an accelerating pursuit.
        angle=0.25-t*0.05;radius=9.6-t*0.23;height=1.8-t*0.09;
        let rush=smoothstep(1.2,6.5,u);chase=core-axis*mix(11.0,5.5,rush)+side*(sin(u*0.5)*2.8)+up*(1.0+cos(u*0.5)*1.3);
        roll=-0.10*sin(u*0.5);zoom=mix(0.44,0.56,rush);
    }
    let source_eye=vec3<f32>(sin(angle)*radius,height,cos(angle)*radius);
    let blend=smoothstep(7.0,9.2,time);let eye=cs_safe_eye(mix(source_eye,chase,blend),id);
    let source_aim=mix(vec3<f32>(0),core,smoothstep(4.8,7.8,time)*0.44);
    // The pursuit looks slightly ahead, keeping both the solid weapon and approaching Earth.
    let aim=mix(source_aim,core+axis*0.8,blend);
    return CsCamera(eye,aim,roll,zoom);
}
fn cs_camera_ray(camera:CsCamera,uv:vec2<f32>)->vec3<f32>{
    let f=normalize(camera.aim-camera.eye);var guide=vec3<f32>(0,1,0);
    if(abs(dot(f,guide))>0.97){guide=vec3<f32>(0,0,1);}
    let right=normalize(cross(f,guide));let up=cross(right,f);
    let q=cs_rot((uv*2.0-1.0)*vec2<f32>(frame.resolution.x/frame.resolution.y,-1.0),camera.roll);
    return normalize(f+(right*q.x+up*q.y)*camera.fov);
}
fn cc_space(uv:vec2<f32>,time:f32,id:f32)->vec3<f32>{
    let phase=smoothstep(8.0,15.0,time);let travel=select(phase,phase*phase,id>4.5);let earth=CS_EARTH;
    let start=vec3<f32>(-0.4,0.4,3.0);let finish=earth+vec3<f32>(-0.8,0.3,5.3);let axis=normalize(finish-start);let core=mix(start,finish,travel);
    let camera=cs_camera(time,id,core,axis);let ro=camera.eye;let rd=cs_camera_ray(camera,uv);let stars=pow(cc_hash(floor(rd*1900.0)),260.0);
    var col=vec3<f32>(0.0015,0.002,0.007)+vec3<f32>(0.60,0.76,1.0)*stars*1.8+vec3<f32>(0.018,0.011,0.04)*pow(cc_fbm(rd*5.0),3.0);
    col=cc_planet(ro,rd,earth,4.2,6.0,time,col);col=cc_planet(ro,rd,vec3<f32>(0),2.15,id,time,col);
    // cc_projectile switches to the larger world-space model at t=15. Space footage
    // retains the cinematic scale through the final crossfade rather than engulfing its camera.
    if(time>4.0){let weapon=cc_projectile(ro,rd,core,min(time,14.999),id,1000.0);let wake=smoothstep(4.0,5.5,time);col=col*(1.0-weapon.a*wake)+weapon.rgb*wake;}
    return col*(1.0-smoothstep(0.3,0.85,length(uv-0.5))*0.36);
}

// Actual source blocks, texture-mapped from the game's current block atlas.
// Data: magic,count,group_count,64; 16 words/group, then64/block.
@group(0) @binding(8) var cc_block_sprites: texture_2d_array<f32>;
@group(0) @binding(9) var cc_block_sampler: sampler;
fn db_f(i:u32)->f32{return bitcast<f32>(mod_data[i]);}
fn db_v(i:u32)->vec3<f32>{return vec3<f32>(db_f(i),db_f(i+1u),db_f(i+2u));}
fn db_rotate(p:vec3<f32>,a:vec3<f32>)->vec3<f32>{
    let x=vec3<f32>(p.x,p.y*cos(a.x)-p.z*sin(a.x),p.y*sin(a.x)+p.z*cos(a.x));
    let y=vec3<f32>(x.x*cos(a.y)+x.z*sin(a.y),x.y,-x.x*sin(a.y)+x.z*cos(a.y));
    return vec3<f32>(y.x*cos(a.z)-y.y*sin(a.z),y.x*sin(a.z)+y.y*cos(a.z),y.z);
}
fn db_inverse(p:vec3<f32>,a:vec3<f32>)->vec3<f32>{
    let z=vec3<f32>(p.x*cos(a.z)+p.y*sin(a.z),-p.x*sin(a.z)+p.y*cos(a.z),p.z);
    let y=vec3<f32>(z.x*cos(a.y)-z.z*sin(a.y),z.y,z.x*sin(a.y)+z.z*cos(a.y));
    return vec3<f32>(y.x,y.y*cos(a.x)+y.z*sin(a.x),-y.y*sin(a.x)+y.z*cos(a.x));
}
fn cc_debris(ro:vec3<f32>,rd:vec3<f32>,age:f32,id:f32,limit:f32,background:vec3<f32>)->vec3<f32>{
    if(age<0.0 || age>15.0 || arrayLength(&mod_data)<4u){return background;}
    if(mod_data[0]!=0x43444232u || mod_data[3]!=64u){return background;}
    let count=min(mod_data[1],256u);let groups=min(mod_data[2],4u);
    if(arrayLength(&mod_data)<4u+groups*16u+count*64u){return background;}
    let budget=select(128u,256u,frame.mod_params[1].w>0.5);
    var col=background;var nearest=limit;
    for(var g=0u;g<4u;g++){
        if(g>=groups){break;}
        let h=4u+g*16u;let pivot=db_v(h);let velocity=db_v(h+3u);let spin=db_v(h+6u);
        let flight=max(0.0,age-db_f(h+9u));let radius=db_f(h+10u);
        if(radius<=0.0){continue;}
        var moving=pivot+velocity*flight+vec3<f32>(0,-7.5*flight*flight,0);
        var angle=spin*flight;
        if(id>0.5 && id<1.5){let swirl=flight*0.42;moving.x=pivot.x*cos(swirl)-pivot.z*sin(swirl)+velocity.x*flight*0.55;moving.z=pivot.x*sin(swirl)+pivot.z*cos(swirl)+velocity.z*flight*0.55;}
        if(id>4.5 && age<1.3){let suck=smoothstep(0.0,1.3,age);moving=mix(pivot,pivot*vec3<f32>(0.42,1,0.42)+vec3<f32>(0,9,0),suck);angle=spin*age*0.4;}
        let sphere=cc_sphere(ro,rd,moving,radius);
        if(sphere.y<0.0 || sphere.x>nearest){continue;}
        let local_ro=db_inverse(ro-moving,angle);let local_rd=db_inverse(rd,angle);
        let first=mod_data[h+11u];let n=mod_data[h+12u];
        for(var b=0u;b<256u;b++){
            if(b>=n){break;}
            let index=first+b;if(index>=count || index>=budget){break;}
            let p=4u+groups*16u+index*64u;let origin=db_v(p);
            let hit=cc_box(local_ro,local_rd,origin,vec3<f32>(0.499));
            if(hit<0.0 || hit>=nearest){continue;}
            let q=local_ro+local_rd*hit-origin;
            let absq=abs(q);var side=0u;var uv=vec2<f32>(q.x,q.z)+0.5;var normal=vec3<f32>(0,-1,0);
            if(absq.y>=absq.x && absq.y>=absq.z){if(q.y>0.0){side=1u;normal=vec3<f32>(0,1,0);}}
            else if(absq.z>=absq.x){side=select(2u,3u,q.z>0.0);uv=vec2<f32>(q.x,q.y)+0.5;normal=vec3<f32>(0,0,select(-1.0,1.0,q.z>0.0));}
            else{side=select(4u,5u,q.x>0.0);uv=vec2<f32>(q.z,q.y)+0.5;normal=vec3<f32>(select(-1.0,1.0,q.x>0.0),0,0);}
            let face=p+16u+side*8u;let layer=mod_data[face]&0x7fffffffu;
            if(layer>=textureNumLayers(cc_block_sprites)){continue;}
            let texuv=vec2<f32>(db_f(face+2u),db_f(face+3u))+uv.x*vec2<f32>(db_f(face+4u),db_f(face+5u))+uv.y*vec2<f32>(db_f(face+6u),db_f(face+7u));
            let texel=textureSampleLevel(cc_block_sprites,cc_block_sampler,texuv,i32(layer),0.0);
            if(texel.a<0.4){continue;}
            let rgb=mod_data[face+1u];let tint=vec3<f32>(f32((rgb>>16u)&255u),f32((rgb>>8u)&255u),f32(rgb&255u))/255.0;
            let light=0.40+max(0.0,dot(db_rotate(normal,angle),normalize(vec3<f32>(-0.5,0.8,0.3))))*0.60;
            let surface=texel.rgb*tint*light;
            col=mix(background,surface,1.0-smoothstep(13.0,15.0,age));nearest=hit;
        }
    }
    return col;
}

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

@fragment fn fs_main(v:StageIn)->@location(0) vec4<f32>{
    let t=frame.mod_params[0].w+frame.time.w/20.0;let id=frame.mod_params[1].x;let uv=v.uv;
    let base=textureSampleLevel(scene_color,linear_sampler,uv,0.0).rgb;
    var col=cc_ground(uv,base,t,id);
    if(frame.mod_params[1].y>0.5 && t<17.0){let blend=smoothstep(0.0,2.8,t)*(1.0-smoothstep(14.8,16.5,t));col=mix(col,cc_space(uv,t,id),blend);
        let bars=smoothstep(0.0,1.5,t)*(1.0-smoothstep(15.0,16.4,t));if(uv.y<0.075*bars || uv.y>1.0-0.075*bars){col=vec3<f32>(0.002);}
    }
    col=vec3<f32>(1.0)-exp(-max(col,vec3<f32>(0))*1.05);
    // Fade back to the unmodified game at the end of the aftermath.
    col=mix(col,base,smoothstep(40.0,45.0,t));return vec4<f32>(col,1.0);
}


