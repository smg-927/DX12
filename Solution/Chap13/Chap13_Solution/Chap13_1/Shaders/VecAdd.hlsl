
struct Data
{
	float3 v1;
};

StructuredBuffer<Data> gInputA : register(t0);
RWStructuredBuffer<Data> gOutput : register(u0);

[numthreads(64, 1, 1)]
void CS(int3 dtid : SV_DispatchThreadID)
{
    gOutput[dtid.x].v1 = gInputA[dtid.x].v1;
}
