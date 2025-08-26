//***************************************************************************************
// color.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//
// Transforms and colors geometry.
//***************************************************************************************

cbuffer ObjectConstants : register(b0)
{
    matrix gWorldViewProj; // float4x4 (HLSL은 column-major 기본)
    float gTime;
    float3 _pad; // 16바이트 정렬 맞추기
};

// VS 입력/출력
struct VSInput
{
    float3 PosL : POSITION;
    float4 Color : COLOR;
};

struct PSInput
{
    float4 PosH : SV_POSITION;
    float4 Color : COLOR;
};

PSInput VS(VSInput vin)
{
    PSInput vout;

    // 로컬 좌표 가져오기
    float3 pos = vin.PosL;

    // --- 여기서 문제에 주어진 변형을 적용 ---
    pos.xy += 0.5f * sin(pos.x) * sin(3.0f * gTime);
    pos.z *= (0.6f + 0.4f * sin(2.0f * gTime));
    // ------------------------------------------------

    // 월드-뷰-프로젝션(이미 하나로 합쳐진 매트릭스 사용시)
    float4 posH = mul(float4(pos, 1.0f), gWorldViewProj);
    vout.PosH = posH;
    vout.Color = vin.Color;

    return vout;
}

float4 PS(PSInput pin) : SV_TARGET
{
    return pin.Color;
}


