//***************************************************************************************
// TreeSprite.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//***************************************************************************************

// Defaults for number of lights.
#ifndef NUM_DIR_LIGHTS
    #define NUM_DIR_LIGHTS 3
#endif

#ifndef NUM_POINT_LIGHTS
    #define NUM_POINT_LIGHTS 0
#endif

#ifndef NUM_SPOT_LIGHTS
    #define NUM_SPOT_LIGHTS 0
#endif

// Include structures and functions for lighting.
#include "LightingUtil.hlsl"

Texture2D gDiffuseMap : register(t0);

SamplerState gsamPointWrap : register(s0);
SamplerState gsamPointClamp : register(s1);
SamplerState gsamLinearWrap : register(s2);
SamplerState gsamLinearClamp : register(s3);
SamplerState gsamAnisotropicWrap : register(s4);
SamplerState gsamAnisotropicClamp : register(s5);

// Constant data that varies per frame.
cbuffer cbPerObject : register(b0)
{
    float4x4 gWorld;
    float4x4 gTexTransform;
};

// Constant data that varies per material.
cbuffer cbPass : register(b1)
{
    float4x4 gView;
    float4x4 gInvView;
    float4x4 gProj;
    float4x4 gInvProj;
    float4x4 gViewProj;
    float4x4 gInvViewProj;
    float3 gEyePosW;
    float cbPerObjectPad1;
    float2 gRenderTargetSize;
    float2 gInvRenderTargetSize;
    float gNearZ;
    float gFarZ;
    float gTotalTime;
    float gDeltaTime;
    float4 gAmbientLight;

    float4 gFogColor;
    float gFogStart;
    float gFogRange;
    float2 cbPerObjectPad2;

    // Indices [0, NUM_DIR_LIGHTS) are directional lights;
    // indices [NUM_DIR_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHTS) are point lights;
    // indices [NUM_DIR_LIGHTS+NUM_POINT_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHT+NUM_SPOT_LIGHTS)
    // are spot lights for a maximum of MaxLights per object.
    Light gLights[MaxLights];
};

cbuffer cbMaterial : register(b2)
{
    float4 gDiffuseAlbedo;
    float3 gFresnelR0;
    float gRoughness;
    float4x4 gMatTransform;
};
 
struct VertexIn
{
    float3 PosL : POSITION;
    float3 NormalL : NORMAL;
    float2 TexC : TEXCOORD;
};

struct VertexOut
{
    float4 PosH : SV_POSITION;
    float3 PosW : POSITION;
    float3 NormalW : NORMAL;
};

struct GeoOut
{
    float4 PosH : SV_POSITION;
    float3 PosW : POSITION;
    uint PrimID : SV_PrimitiveID;
};

VertexOut VS(VertexIn vin)
{
    VertexOut vout;
    
    float4 posW = mul(float4(vin.PosL, 1.0f), gWorld);
    vout.PosW = posW.xyz;
    vout.PosH = mul(float4(vin.PosL, 1.0f), gViewProj);
    float3x3 W = (float3x3) gWorld;
    float3 c0 = normalize(float3(W[0][0], W[1][0], W[2][0]));
    float3 c1 = normalize(float3(W[0][1], W[1][1], W[2][1]));
    float3 c2 = normalize(float3(W[0][2], W[1][2], W[2][2]));

    float3x3 R = float3x3(c0, c1, c2);

    vout.NormalW = normalize(mul(vin.NormalL, R));
    return vout;
}
 
[maxvertexcount(4)]
void GS(triangle VertexOut gin[3],
        uint primID : SV_PrimitiveID,
        inout LineStream<GeoOut> triStream)
{
    float3 p = (gin[0].PosW + gin[2].PosW + gin[2].PosW)/3;
    float3 n = normalize(cross(gin[0].PosW - gin[1].PosW, gin[0].PosW - gin[2].PosW));

    float3 p2 = p + 3.0f * n;

    GeoOut o;
    
    o.PosW = p;
    o.PosH = mul(float4(p, 1.0f), gViewProj);
    o.PrimID = primID;
    triStream.Append(o);

    o.PosW = p2;
    o.PosH = mul(float4(p2, 1.0f), gViewProj);
    triStream.Append(o);
}

float4 PS(GeoOut pin) : SV_Target
{
    float4 litColor = float4(1.0f, 0.2f, 0.4f, 1.0f);
    
    return litColor;
}


