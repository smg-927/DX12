//=============================================================================
// Performs a separable Gaussian blur with a blur radius up to 5 pixels.
// Safe version: does NOT use Texture2D.Length (uses GetDimensions instead).
//=============================================================================

cbuffer cbSettings : register(b0)
{
    int gBlurRadius;

    // Support up to 11 blur weights.
    float w0;
    float w1;
    float w2;
    float w3;
    float w4;
    float w5;
    float w6;
    float w7;
    float w8;
    float w9;
    float w10;
};

static const int gMaxBlurRadius = 5;

// 명시 타입 권장 (원본처럼 untyped Texture2D도 되지만, 안전/명확성 위해 float4로)
Texture2D<float4> gInput : register(t0);
RWTexture2D<float4> gOutput : register(u0);

#define N 256
#define CacheSize (N + 2*gMaxBlurRadius)
groupshared float4 gCache[CacheSize];

[numthreads(N, 1, 1)]
void HorzBlurCS(uint3 groupThreadID : SV_GroupThreadID,
                uint3 dispatchThreadID : SV_DispatchThreadID)
{
    // Clamp blur radius to max to avoid out-of-bounds in gCache / weights indexing.
    int radius = min(gBlurRadius, gMaxBlurRadius);

    // Put in an array for each indexing.
    float weights[11] = { w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10 };

    // Fetch texture dimensions.
    uint texW, texH;
    gInput.GetDimensions(texW, texH);

    // Convert frequently used ids to int for safe math.
    int gx = (int) groupThreadID.x;
    int dx = (int) dispatchThreadID.x;
    int dy = (int) dispatchThreadID.y;

    int maxX = (int) texW - 1;
    int maxY = (int) texH - 1;

    // Guard: if height is 0 (shouldn't happen), avoid negative maxY.
    // (Optional safety; can omit if guaranteed valid texture)
    if (maxX < 0 || maxY < 0)
        return;

    // This thread group runs N threads. To get the extra 2*radius pixels,
    // have 2*radius threads sample an extra pixel.
    if (gx < radius)
    {
        int x = max(dx - radius, 0);
        int y = min(max(dy, 0), maxY);
        gCache[gx] = gInput[int2(x, y)];
    }

    if (gx >= N - radius)
    {
        int x = min(dx + radius, maxX);
        int y = min(max(dy, 0), maxY);
        gCache[gx + 2 * radius] = gInput[int2(x, y)];
    }

    // Load the central pixel for this thread.
    {
        int x = min(max(dx, 0), maxX);
        int y = min(max(dy, 0), maxY);
        gCache[gx + radius] = gInput[int2(x, y)];
    }

    // Wait for all threads to finish filling gCache.
    GroupMemoryBarrierWithGroupSync();

    // Now blur each pixel.
    float4 blurColor = float4(0, 0, 0, 0);

    // Cache index for this thread's center.
    int centerK = gx + radius;

    [unroll]
    for (int i = -gMaxBlurRadius; i <= gMaxBlurRadius; ++i)
    {
        if (i < -radius || i > radius)
            continue; // only active taps

        int k = centerK + i;
        blurColor += weights[i + gMaxBlurRadius] * gCache[k];
    }

    // Write output (clamp write coords too)
    {
        int x = min(max(dx, 0), maxX);
        int y = min(max(dy, 0), maxY);
        gOutput[int2(x, y)] = blurColor;
    }
}

[numthreads(1, N, 1)]
void VertBlurCS(uint3 groupThreadID : SV_GroupThreadID,
                uint3 dispatchThreadID : SV_DispatchThreadID)
{
    int radius = min(gBlurRadius, gMaxBlurRadius);

    float weights[11] = { w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10 };

    uint texW, texH;
    gInput.GetDimensions(texW, texH);

    int gy = (int) groupThreadID.y;
    int dx = (int) dispatchThreadID.x;
    int dy = (int) dispatchThreadID.y;

    int maxX = (int) texW - 1;
    int maxY = (int) texH - 1;

    if (maxX < 0 || maxY < 0)
        return;

    if (gy < radius)
    {
        int y = max(dy - radius, 0);
        int x = min(max(dx, 0), maxX);
        gCache[gy] = gInput[int2(x, y)];
    }

    if (gy >= N - radius)
    {
        int y = min(dy + radius, maxY);
        int x = min(max(dx, 0), maxX);
        gCache[gy + 2 * radius] = gInput[int2(x, y)];
    }

    // Central pixel
    {
        int x = min(max(dx, 0), maxX);
        int y = min(max(dy, 0), maxY);
        gCache[gy + radius] = gInput[int2(x, y)];
    }

    GroupMemoryBarrierWithGroupSync();

    float4 blurColor = float4(0, 0, 0, 0);
    int centerK = gy + radius;

    [unroll]
    for (int i = -gMaxBlurRadius; i <= gMaxBlurRadius; ++i)
    {
        if (i < -radius || i > radius)
            continue;

        int k = centerK + i;
        blurColor += weights[i + gMaxBlurRadius] * gCache[k];
    }

    // Write output
    {
        int x = min(max(dx, 0), maxX);
        int y = min(max(dy, 0), maxY);
        gOutput[int2(x, y)] = blurColor;
    }
}
