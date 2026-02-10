
Buffer<float3> gInputA : register(t0);
RWBuffer<float> gOutput : register(u0);

[numthreads(64, 1, 1)]
void CS(uint3 tid : SV_DispatchThreadID)
{
    float3 v = gInputA[tid.x];
    gOutput[tid.x] = length(v);
}