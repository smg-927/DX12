
struct Data
{
	float3 v1;
};

ConsumeStructuredBuffer<Data> gInput : register(u0);
AppendStructuredBuffer<Data> gOutput : register(u1);


[numthreads(64, 1, 1)]
void CS(int3 dtid : SV_DispatchThreadID)
{
    Data p = gInput.Consume();
    gOutput.Append(p);
}
