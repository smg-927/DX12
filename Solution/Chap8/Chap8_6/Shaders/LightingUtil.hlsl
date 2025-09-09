//***************************************************************************************
// LightingUtil.hlsl (fixed for single float3 shadowFactor)
//***************************************************************************************

#define MaxLights 16

struct Light
{
    float3 Strength;
    float FalloffStart;
    float3 Direction;
    float FalloffEnd;
    float3 Position;
    float SpotPower;
};

struct Material
{
    float4 DiffuseAlbedo;
    float3 FresnelR0;
    float Shininess;
};

struct LightingComponents
{
    float3 Diffuse;
    float3 Specular;
};

float CalcAttenuation(float d, float falloffStart, float falloffEnd)
{
    return saturate((falloffEnd - d) / max(1e-6f, (falloffEnd - falloffStart)));
}

float3 SchlickFresnel(float3 R0, float3 normal, float3 lightVec)
{
    float cosIncidentAngle = saturate(dot(normal, lightVec));
    float f0 = 1.0f - cosIncidentAngle;
    float3 reflectPercent = R0 + (1.0f - R0) * (f0 * f0 * f0 * f0 * f0);
    return reflectPercent;
}

static LightingComponents LC_Zero()
{
    LightingComponents z;
    z.Diffuse = float3(0.0f, 0.0f, 0.0f);
    z.Specular = float3(0.0f, 0.0f, 0.0f);
    return z;
}

LightingComponents BlinnPhong(float3 lightStrength, float3 lightVec, float3 normal, float3 toEye, Material mat)
{
    LightingComponents LC = LC_Zero();

    // Diffuse
    LC.Diffuse = mat.DiffuseAlbedo.rgb * lightStrength;

    // Specular
    const float m = mat.Shininess * 256.0f;
    float3 halfVec = normalize(toEye + lightVec);
    float NdotH = max(dot(halfVec, normal), 0.0f);
    float roughnessFactor = (m + 8.0f) * pow(NdotH, m) / 8.0f;
    float3 fresnelFactor = SchlickFresnel(mat.FresnelR0, halfVec, lightVec);
    float3 specAlbedo = fresnelFactor * roughnessFactor;
    specAlbedo = specAlbedo / (specAlbedo + 1.0f);
    LC.Specular = specAlbedo * lightStrength;

    return LC;
}

LightingComponents ComputeDirectionalLight(in Light L, in Material mat, float3 normal, float3 toEye)
{
    float3 lightVec = normalize(-L.Direction);
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float3 lightStrength = L.Strength * ndotl;
    return BlinnPhong(lightStrength, lightVec, normal, toEye, mat);
}

LightingComponents ComputePointLight(in Light L, in Material mat, float3 pos, float3 normal, float3 toEye)
{
    LightingComponents zero = LC_Zero();
    float3 lightVec = L.Position - pos;
    float d = length(lightVec);
    if (d <= 1e-6f || d > L.FalloffEnd) return zero;
    lightVec /= d;
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float att = CalcAttenuation(d, L.FalloffStart, L.FalloffEnd);
    float3 lightStrength = L.Strength * ndotl * att;
    return BlinnPhong(lightStrength, lightVec, normal, toEye, mat);
}

LightingComponents ComputeSpotLight(in Light L, in Material mat, float3 pos, float3 normal, float3 toEye)
{
    LightingComponents zero = LC_Zero();
    float3 lightVec = L.Position - pos;
    float d = length(lightVec);
    if (d <= 1e-6f || d > L.FalloffEnd) return zero;
    lightVec /= d;
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float att = CalcAttenuation(d, L.FalloffStart, L.FalloffEnd);
    float spotFactor = pow(max(dot(-lightVec, normalize(L.Direction)), 0.0f), L.SpotPower);
    float3 lightStrength = L.Strength * ndotl * att * spotFactor;
    return BlinnPhong(lightStrength, lightVec, normal, toEye, mat);
}

// NOTE: shadowFactor is a single float3 (per-pixel). It will be broadcast for each light.
float4 ComputeLighting(Light gLights[MaxLights], Material mat,
    float3 pos, float3 normal, float3 toEye,
    float3 shadowFactor)   // single float3
{
    LightingComponents result = LC_Zero();

    int i = 0;

#if (NUM_DIR_LIGHTS > 0)
    for (i = 0; i < NUM_DIR_LIGHTS; ++i)
    {
        LightingComponents Lc = ComputeDirectionalLight(gLights[i], mat, normal, toEye);
        result.Diffuse += shadowFactor * Lc.Diffuse;
        result.Specular += shadowFactor * Lc.Specular;
    }
#endif

#if (NUM_POINT_LIGHTS > 0)
    for (i = NUM_DIR_LIGHTS; i < NUM_DIR_LIGHTS + NUM_POINT_LIGHTS; ++i)
    {
        LightingComponents Lc = ComputePointLight(gLights[i], mat, pos, normal, toEye);
        result.Diffuse += shadowFactor * Lc.Diffuse;
        result.Specular += shadowFactor * Lc.Specular;
    }
#endif

#if (NUM_SPOT_LIGHTS > 0)
    for (i = NUM_DIR_LIGHTS + NUM_POINT_LIGHTS; i < NUM_DIR_LIGHTS + NUM_POINT_LIGHTS + NUM_SPOT_LIGHTS; ++i)
    {
        LightingComponents Lc = ComputeSpotLight(gLights[i], mat, pos, normal, toEye);
        result.Diffuse += shadowFactor * Lc.Diffuse;
        result.Specular += shadowFactor * Lc.Specular;
    }
#endif

    // clamp and quantize per-channel (toon)
    result.Diffuse = saturate(result.Diffuse);
    result.Specular = saturate(result.Specular);

    float3 qdiffuse;
    qdiffuse.x = (result.Diffuse.x < 0.0f) ? 0.4f : ((result.Diffuse.x <= 0.5f) ? 0.6f : 1.0f);
    qdiffuse.y = (result.Diffuse.y < 0.0f) ? 0.4f : ((result.Diffuse.y <= 0.5f) ? 0.6f : 1.0f);
    qdiffuse.z = (result.Diffuse.z < 0.0f) ? 0.4f : ((result.Diffuse.z <= 0.5f) ? 0.6f : 1.0f);

    float3 qspecular;
    qspecular.x = (result.Specular.x < 0.1f) ? 0.1f : ((result.Specular.x < 0.8f) ? 0.5f : 1.0f);
    qspecular.y = (result.Specular.y < 0.1f) ? 0.1f : ((result.Specular.y < 0.8f) ? 0.5f : 1.0f);
    qspecular.z = (result.Specular.z < 0.1f) ? 0.1f : ((result.Specular.z < 0.8f) ? 0.5f : 1.0f);

    float3 finalColor = qdiffuse + qspecular;
    return float4(finalColor, 1.0f);
}
