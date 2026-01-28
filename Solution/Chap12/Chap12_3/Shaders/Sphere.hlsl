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
    
    float explodeSpeed;
    float gExplodeTime;
    float gExplodeStartTime;
    float padding;

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
    float3 PosW : POSITION;
    float3 normal : NORMAL;
    float3 texC : TEXCOORD;
};

struct VertexOut
{
    float3 PosW : POSITION;
    float3 normal : NORMAL;
    float3 texC : TEXCOORD;
};

struct GeoOut
{
    float4 PosH : SV_POSITION;
    float3 PosW : POSITION;
    float3 NormalW : NORMAL;
    float2 TexC : TEXCOORD;
    uint PrimID : SV_PrimitiveID;
};

VertexOut VS(VertexIn vin)
{
    VertexOut vout;
    
    vout.PosW = vin.PosW;
    vout.normal = vin.normal;
    vout.texC = vin.texC;

    return vout;
}

void EmitTri(float3 a, float3 b, float3 c, inout TriangleStream<GeoOut> triStream, uint primID)
{
    GeoOut o;
    o.PrimID = primID;
    
    
    o.NormalW = normalize(a);
    o.NormalW = normalize(b);
    o.NormalW = normalize(c);
    
    float3 normal = normalize(cross(b - a, c - a)) * explodeSpeed;
    a += ((gExplodeTime - gExplodeStartTime) * normal);
    o.PosW = a;
    o.TexC = float2(0.0f, 1.0f);
    o.PosH = mul(float4(a, 1.0f), gViewProj);
    triStream.Append(o);
    b += ((gExplodeTime - gExplodeStartTime) * normal);
    o.PosW = b;
    o.TexC = float2(1.0f, 1.0f);
    o.PosH = mul(float4(b, 1.0f), gViewProj) ;
    triStream.Append(o);
    c += ((gExplodeTime - gExplodeStartTime) * normal);
    o.PosW = c;
    o.TexC = float2(0.5f, 0.0f);
    o.PosH = mul(float4(c, 1.0f), gViewProj);
    triStream.Append(o);
}

[maxvertexcount(3)]
void GS(triangle VertexOut gin[3],
        uint primID : SV_PrimitiveID,
        inout TriangleStream<GeoOut> triStream)
{
    float3 a = gin[0].PosW;
    float3 b = gin[1].PosW;
    float3 c = gin[2].PosW;
    
    EmitTri(a, b, c, triStream, primID);
}

float4 PS(GeoOut pin) : SV_Target
{
    float4 diffuseAlbedo = gDiffuseMap.Sample(gsamAnisotropicWrap, pin.TexC) * gDiffuseAlbedo;
	
#ifdef ALPHA_TEST
	// Discard pixel if texture alpha < 0.1.  We do this test as soon 
	// as possible in the shader so that we can potentially exit the
	// shader early, thereby skipping the rest of the shader code.
	clip(diffuseAlbedo.a - 0.1f);
#endif
    
    pin.NormalW = normalize(pin.NormalW);
    
    float3 toEyeW = gEyePosW - pin.PosW;
    float distToEye = length(toEyeW);
    toEyeW /= distToEye; // normalize

    // Light terms.
    float4 ambient = gAmbientLight * diffuseAlbedo;

    const float shininess = 1.0f - gRoughness;
    Material mat = { diffuseAlbedo, gFresnelR0, shininess };
    float3 shadowFactor = 1.0f;
    float4 directLight = ComputeLighting(gLights, mat, pin.PosW,
        pin.NormalW, toEyeW, shadowFactor);

    float4 litColor = ambient + directLight;

//#ifdef FOG
	//float fogAmount = saturate((distToEye - gFogStart) / gFogRange);
	//litColor = lerp(litColor, gFogColor, fogAmount);
//#endif

    // Common convention to take alpha from diffuse albedo.
    litColor.a = diffuseAlbedo.a;

    return litColor;
}


