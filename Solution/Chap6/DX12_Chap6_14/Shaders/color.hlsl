// color_fixed.hlsl

cbuffer cbPerObject : register(b0)
{
    float4x4 gWorldViewProj;
    float4   gTint;
};

struct VertexIn
{
    float3 PosL : POSITION;
    float4 Color : COLOR0;
};

struct VertexOut
{
    float4 PosH : SV_POSITION;
    float4 Color : COLOR0;
    float4 Tint : COLOR1;
};

VertexOut VS(VertexIn vin)
{
    VertexOut vout;

    // CPU에서 WorldViewProj를 Transpose 해서 업로드하고 있으므로 이 mul 순서가 맞습니다.
    vout.PosH = mul(float4(vin.PosL, 1.0f), gWorldViewProj);

    vout.Color = vin.Color;
    vout.Tint = gTint;

    return vout;
}

float4 PS(VertexOut pin) : SV_Target
{
    // 정점 컬러에 tint를 곱해서 최종 색으로 사용
    return pin.Color * pin.Tint;
}
