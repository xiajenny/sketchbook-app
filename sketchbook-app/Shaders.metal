//
//  Shaders.metal
//  macOSMetal
//
//  Created by Zach Eriksen on 4/30/18.
//  Copyright © 2018 Zach Eriksen. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position;
    float4 color;
};


struct VertexOut {
    float4 position [[ position ]];
    float4 color;
};

vertex VertexOut basic_vertex_function(const device VertexIn *vertices [[ buffer(0) ]],
                                       uint vertexID [[ vertex_id  ]]) {
    VertexOut vOut;
    vOut.position = float4(vertices[vertexID].position,1);
    vOut.color = vertices[vertexID].color;
    return vOut;
}


fragment float4 basic_fragment_function(VertexOut vIn [[ stage_in ]]) {
    return vIn.color;
}

struct vxin
{
  packed_float3 pos;
  packed_float2 uv;
};

struct vxout
{
  float4 pos [[position]];
  float2 uv;
    float3 color;
};

struct vxout_brush
{
    float4 pos [[position]];
    float2 local_uv;
    float2 uv;
};
struct Uniforms
{
  float4x4 modelMatrix;
//  float4x4 projectionMatrix;
};

vertex vxout basic_vertex(const device vxin* vertex_array [[ buffer(0) ]],
                          //const device Uniforms& uniforms [[ buffer(1) ]],
                          unsigned int vid [[ vertex_id ]])
{
    vxin vi = vertex_array[vid];
    
    vxout vo;
    vo.uv = vi.uv;
    float4 p = float4(vi.pos, 1.0);
    //float4x4 m = uniforms.modelMatrix;
    //vo.pos = m * p;
    vo.pos = p;
    return vo;
}

fragment half4 basic_fragment(vxout fin [[ stage_in ]],
                              texture2d<half> tx [[ texture(0) ]])
{
    constexpr sampler txsampler;
    return tx.sample(txsampler, fin.uv);
}

struct uniform2d
{
    float2 translate;
    float2 scale;
    float3 color;
};

vertex vxout brush_vertex(const device vxin* vertex_array [[ buffer(0) ]],
                          const device uniform2d &uniforms [[ buffer(1) ]],
                          unsigned int vid [[ vertex_id ]])
{
    vxin vi = vertex_array[vid];
    
    vxout vo;
    vo.uv = vi.uv;
    vo.color = uniforms.color;
    float2 translate = uniforms.translate;
    float2 scale = uniforms.scale;
    float2 pos;
    pos.x = vi.pos[0];
    pos.y = vi.pos[1];
    pos = pos * scale + translate;
    float4 p = float4(pos, 0.0, 1.0);
    //vo.pos = m * p;
    vo.pos = p;
    return vo;
}
vertex vxout stroke_vertex(const device vxin* vertex_array [[ buffer(0) ]],
                          const device uniform2d *uniforms [[ buffer(1) ]],
                          unsigned int vid [[ vertex_id ]],
                          uint16_t iid [[ instance_id ]])
{
    vxin vi = vertex_array[vid];
    
    vxout vo;
    vo.uv = vi.uv;
    vo.color = uniforms[iid].color;
    float2 translate = uniforms[iid].translate;
    float2 scale = uniforms[iid].scale;
    float2 pos;
    pos.x = vi.pos[0];
    pos.y = vi.pos[1];
    pos = pos * scale + translate;
    float4 p = float4(pos, 0.0, 1.0);
    //vo.pos = m * p;
    vo.pos = p;
    return vo;
}

fragment half4 brush_fragment(vxout fin [[ stage_in ]],
                              texture2d<half> tx [[ texture(0) ]])
{
    constexpr sampler txsampler;
    half4 brush = tx.sample(txsampler, fin.uv);
    brush.rgb = half3(fin.color.rgb);
    return brush;
}

fragment half4 brush_fragment_depr(vxout_brush fin [[ stage_in ]],
                              texture2d<half> tx [[ texture(0) ]],
                              texture2d<half> brush [[ texture(1) ]])
{
    constexpr sampler txsampler;
    half4 color = tx.sample(txsampler, fin.uv);
    half4 brush_color = brush.sample(txsampler, fin.uv);
    return color + brush_color;
}
