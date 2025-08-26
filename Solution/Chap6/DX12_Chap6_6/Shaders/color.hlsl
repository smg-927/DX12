//***************************************************************************************
// color.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//
// Transforms and colors geometry.
//***************************************************************************************

cbuffer ObjectConstants : register(b0)
{
    matrix gWorldViewProj; // float4x4 (HLSL�� column-major �⺻)
    float gTime;
    float3 _pad; // 16����Ʈ ���� ���߱�
};

// VS �Է�/���
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

    // ���� ��ǥ ��������
    float3 pos = vin.PosL;

    // --- ���⼭ ������ �־��� ������ ���� ---
    pos.xy += 0.5f * sin(pos.x) * sin(3.0f * gTime);
    pos.z *= (0.6f + 0.4f * sin(2.0f * gTime));
    // ------------------------------------------------

    // ����-��-��������(�̹� �ϳ��� ������ ��Ʈ���� ����)
    float4 posH = mul(float4(pos, 1.0f), gWorldViewProj);
    vout.PosH = posH;
    vout.Color = vin.Color;

    return vout;
}

float4 PS(PSInput pin) : SV_TARGET
{
    return pin.Color;
}


