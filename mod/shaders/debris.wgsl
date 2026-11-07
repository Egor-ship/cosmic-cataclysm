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
