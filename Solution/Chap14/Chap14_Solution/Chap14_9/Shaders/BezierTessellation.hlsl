//***************************************************************************************
// BezierTessellation.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//
// Demonstrates hardware tessellating a cubic Bezier triangle patch (10 control points).
//***************************************************************************************


 // Include structures and functions for lighting.
#include "LightingUtil.hlsl"

Texture2D    gDiffuseMap : register(t0);


SamplerState gsamPointWrap        : register(s0);
SamplerState gsamPointClamp       : register(s1);
SamplerState gsamLinearWrap       : register(s2);
SamplerState gsamLinearClamp      : register(s3);
SamplerState gsamAnisotropicWrap  : register(s4);
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
	float4   gDiffuseAlbedo;
	float3   gFresnelR0;
	float    gRoughness;
	float4x4 gMatTransform;
};

struct VertexIn
{
	float3 PosL    : POSITION;
};

struct VertexOut
{
	float3 PosL    : POSITION;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout;

	vout.PosL = vin.PosL;

	return vout;
}

struct PatchTess
{
	float EdgeTess[3]   : SV_TessFactor;
	float InsideTess[1] : SV_InsideTessFactor;
};

PatchTess ConstantHS(InputPatch<VertexOut, 10> patch, uint patchID : SV_PrimitiveID)
{
	PatchTess pt;

	pt.EdgeTess[0] = 25;
	pt.EdgeTess[1] = 25;
	pt.EdgeTess[2] = 25;

	pt.InsideTess[0] = 25;

	return pt;
}

struct HullOut
{
	float3 PosL : POSITION;
};

[domain("tri")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(10)]
[patchconstantfunc("ConstantHS")]
[maxtessfactor(64.0f)]
HullOut HS(InputPatch<VertexOut, 10> p,
           uint i : SV_OutputControlPointID,
           uint patchId : SV_PrimitiveID)
{
	HullOut hout;

	hout.PosL = p[i].PosL;

	return hout;
}

struct DomainOut
{
	float4 PosH : SV_POSITION;
};

// Cubic triangular Bezier surface.
// Control points indexed as:
//   [0]=P300, [1]=P030, [2]=P003   (corners)
//   [3]=P210, [4]=P120             (edge 0-1)
//   [5]=P021, [6]=P012             (edge 1-2)
//   [7]=P102, [8]=P201             (edge 0-2)
//   [9]=P111                       (interior)
// Formula: sum of C(3;i,j,k)*u^i*v^j*w^k * P_ijk, i+j+k=3
float3 CubicBezierTriangle(const OutputPatch<HullOut, 10> patch, float3 uvw)
{
	float u = uvw.x;
	float v = uvw.y;
	float w = uvw.z;

	return patch[0].PosL * (u*u*u)
	     + patch[1].PosL * (v*v*v)
	     + patch[2].PosL * (w*w*w)
	     + patch[3].PosL * (3.0f * u*u*v)
	     + patch[4].PosL * (3.0f * u*v*v)
	     + patch[5].PosL * (3.0f * v*v*w)
	     + patch[6].PosL * (3.0f * v*w*w)
	     + patch[7].PosL * (3.0f * u*w*w)
	     + patch[8].PosL * (3.0f * u*u*w)
	     + patch[9].PosL * (6.0f * u*v*w);
}

// The domain shader is called for every vertex created by the tessellator.
[domain("tri")]
DomainOut DS(PatchTess patchTess,
             float3 uvw : SV_DomainLocation,
             const OutputPatch<HullOut, 10> bezPatch)
{
	DomainOut dout;

	float3 p = CubicBezierTriangle(bezPatch, uvw);

	float4 posW = mul(float4(p, 1.0f), gWorld);
	dout.PosH = mul(posW, gViewProj);

	return dout;
}

float4 PS(DomainOut pin) : SV_Target
{
    return float4(1.0f, 1.0f, 1.0f, 1.0f);
}
