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
