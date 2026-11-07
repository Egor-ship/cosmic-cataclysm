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
