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


