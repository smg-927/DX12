cbuffer cbSettings : register(b0)
{
    int gBlurRadius;
    float3 pad;
    float weight[49];
};

static const int gMaxBlurRadius = 3;

Texture2D<float4> gInput : register(t0);
RWTexture2D<float4> gOutput : register(u0);

#define N 16
#define MAX_R 3
#define STRIDE (N + 2*MAX_R)          // 22
#define CACHESZ (STRIDE * STRIDE)     // 484

groupshared float4 gCache[CACHESZ];

static int CacheIndex(int x, int y)
{
    return y * STRIDE + x;
}

static int2 ClampCoord(int2 p, int2 lo, int2 hi)
{
    return int2(
        (p.x < lo.x) ? lo.x : ((p.x > hi.x) ? hi.x : p.x),
        (p.y < lo.y) ? lo.y : ((p.y > hi.y) ? hi.y : p.y)
    );
}

[numthreads(N, N, 1)]
void BilateralBlurCS(uint3 groupThreadID : SV_GroupThreadID,
                     uint3 dispatchThreadID : SV_DispatchThreadID)
{
    uint texW, texH;
    gInput.GetDimensions(texW, texH);
    
    int maxX = (texW > 0) ? (int) texW - 1 : 0;
    int maxY = (texH > 0) ? (int) texH - 1 : 0;

    int2 lo = int2(0, 0);
    int2 hi = int2(maxX, maxY);

    int gx = (int) groupThreadID.x;
    int gy = (int) groupThreadID.y;
    int dx = (int) dispatchThreadID.x;
    int dy = (int) dispatchThreadID.y;
    
    bool inBounds = (dx < (int) texW) && (dy < (int) texH);

    int radius = min(gBlurRadius, gMaxBlurRadius);

    float weights[49] = weight;

    // center in shared cache (fixed layout using MAX_R)
    int cx = gx + MAX_R;
    int cy = gy + MAX_R;
    int cIndex = CacheIndex(cx, cy);

    // --- Shared cache fill (NO varying early exits before sync) ---
    int2 pCenter = ClampCoord(int2(dx, dy), lo, hi);
    gCache[cIndex] = gInput[pCenter];

    // Halos: only some threads write extra cache entries, but all threads will sync.
    if (gx < radius)
    {
        int2 p = ClampCoord(int2(dx - radius, dy), lo, hi);
        gCache[CacheIndex(cx - radius, cy)] = gInput[p];
    }
    if (gx >= N - radius)
    {
        int2 p = ClampCoord(int2(dx + radius, dy), lo, hi);
        gCache[CacheIndex(cx + radius, cy)] = gInput[p];
    }

    if (gy < radius)
    {
        int2 p = ClampCoord(int2(dx, dy - radius), lo, hi);
        gCache[CacheIndex(cx, cy - radius)] = gInput[p];
    }
    if (gy >= N - radius)
    {
        int2 p = ClampCoord(int2(dx, dy + radius), lo, hi);
        gCache[CacheIndex(cx, cy + radius)] = gInput[p];
    }

    if (gx < radius && gy < radius)
    {
        int2 p = ClampCoord(int2(dx - radius, dy - radius), lo, hi);
        gCache[CacheIndex(cx - radius, cy - radius)] = gInput[p];
    }
    if (gx < radius && gy >= N - radius)
    {
        int2 p = ClampCoord(int2(dx - radius, dy + radius), lo, hi);
        gCache[CacheIndex(cx - radius, cy + radius)] = gInput[p];
    }
    if (gx >= N - radius && gy < radius)
    {
        int2 p = ClampCoord(int2(dx + radius, dy - radius), lo, hi);
        gCache[CacheIndex(cx + radius, cy - radius)] = gInput[p];
    }
    if (gx >= N - radius && gy >= N - radius)
    {
        int2 p = ClampCoord(int2(dx + radius, dy + radius), lo, hi);
        gCache[CacheIndex(cx + radius, cy + radius)] = gInput[p];
    }
    
    GroupMemoryBarrierWithGroupSync();

    // --- Bilateral blur ---
    float4 center = gCache[cIndex];

    float4 sumColor = float4(0, 0, 0, 0);
    float sumW = 0.0f;

    const float sigmaR = 0.25f;
    const float inv2SigmaR2 = 1.0f / (2.0f * sigmaR * sigmaR);

    [unroll]
    for (int j = -gMaxBlurRadius; j <= gMaxBlurRadius; ++j)
    {
        if (j < -radius || j > radius)
            continue;

        [unroll]
        for (int i = -gMaxBlurRadius; i <= gMaxBlurRadius; ++i)
        {
            if (i < -radius || i > radius)
                continue;

            int wi = (j + gMaxBlurRadius) * (2 * gMaxBlurRadius + 1) + (i + gMaxBlurRadius);
            float wS = weights[wi];

            float4 s = gCache[CacheIndex(cx + i, cy + j)];

            float3 diff = center.rgb - s.rgb;
            float d2 = dot(diff, diff);
            float wR = exp(-d2 * inv2SigmaR2);

            float w = wS * wR;

            sumColor += s * w;
            sumW += w;
        }
    }

    float4 outColor = sumColor / max(sumW, 1e-6f);
    
    if (inBounds)
    {
        gOutput[int2(dx, dy)] = outColor;
    }
}



//[numthreads(N, 1, 1)]
//void HorzBlurCS(uint3 groupThreadID : SV_GroupThreadID,
//                uint3 dispatchThreadID : SV_DispatchThreadID)
//{
//    // Clamp blur radius to max to avoid out-of-bounds in gCache / weights indexing.
//    int radius = min(gBlurRadius, gMaxBlurRadius);

//    // Put in an array for each indexing.
//    float weights[11] = { w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10 };

//    // Fetch texture dimensions.
//    uint texW, texH;
//    gInput.GetDimensions(texW, texH);

//    // Convert frequently used ids to int for safe math.
//    int gx = (int) groupThreadID.x;
//    int dx = (int) dispatchThreadID.x;
//    int dy = (int) dispatchThreadID.y;

//    int maxX = (int) texW - 1;
//    int maxY = (int) texH - 1;

//    // Guard: if height is 0 (shouldn't happen), avoid negative maxY.
//    // (Optional safety; can omit if guaranteed valid texture)
//    if (maxX < 0 || maxY < 0)
//        return;

//    // This thread group runs N threads. To get the extra 2*radius pixels,
//    // have 2*radius threads sample an extra pixel.
//    if (gx < radius)
//    {
//        int x = max(dx - radius, 0);
//        int y = min(max(dy, 0), maxY);
//        gCache[gx] = gInput[int2(x, y)];
//    }

//    if (gx >= N - radius)
//    {
//        int x = min(dx + radius, maxX);
//        int y = min(max(dy, 0), maxY);
//        gCache[gx + 2 * radius] = gInput[int2(x, y)];
//    }

//    // Load the central pixel for this thread.
//    {
//        int x = min(max(dx, 0), maxX);
//        int y = min(max(dy, 0), maxY);
//        gCache[gx + radius] = gInput[int2(x, y)];
//    }

//    // Wait for all threads to finish filling gCache.
//    GroupMemoryBarrierWithGroupSync();

//    // Now blur each pixel.
//    float4 blurColor = float4(0, 0, 0, 0);

//    // Cache index for this thread's center.
//    int centerK = gx + radius;

//    [unroll]
//    for (int i = -gMaxBlurRadius; i <= gMaxBlurRadius; ++i)
//    {
//        if (i < -radius || i > radius)
//            continue; // only active taps

//        int k = centerK + i;
//        blurColor += weights[i + gMaxBlurRadius] * gCache[k];
//    }

//    // Write output (clamp write coords too)
//    {
//        int x = min(max(dx, 0), maxX);
//        int y = min(max(dy, 0), maxY);
//        gOutput[int2(x, y)] = blurColor;
//    }
//}

//[numthreads(1, N, 1)]
//void VertBlurCS(uint3 groupThreadID : SV_GroupThreadID,
//                uint3 dispatchThreadID : SV_DispatchThreadID)
//{
//    int radius = min(gBlurRadius, gMaxBlurRadius);

//    float weights[11] = { w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10 };

//    uint texW, texH;
//    gInput.GetDimensions(texW, texH);

//    int gy = (int) groupThreadID.y;
//    int dx = (int) dispatchThreadID.x;
//    int dy = (int) dispatchThreadID.y;

//    int maxX = (int) texW - 1;
//    int maxY = (int) texH - 1;

//    if (maxX < 0 || maxY < 0)
//        return;

//    if (gy < radius)
//    {
//        int y = max(dy - radius, 0);
//        int x = min(max(dx, 0), maxX);
//        gCache[gy] = gInput[int2(x, y)];
//    }

//    if (gy >= N - radius)
//    {
//        int y = min(dy + radius, maxY);
//        int x = min(max(dx, 0), maxX);
//        gCache[gy + 2 * radius] = gInput[int2(x, y)];
//    }

//    // Central pixel
//    {
//        int x = min(max(dx, 0), maxX);
//        int y = min(max(dy, 0), maxY);
//        gCache[gy + radius] = gInput[int2(x, y)];
//    }
//    GroupMemoryBarrierWithGroupSync();

//    float4 blurColor = float4(0, 0, 0, 0);
//    int centerK = gy + radius;

//    [unroll]
//    for (int i = -gMaxBlurRadius; i <= gMaxBlurRadius; ++i)
//    {
//        if (i < -radius || i > radius)
//            continue;

//        int k = centerK + i;
//        blurColor += weights[i + gMaxBlurRadius] * gCache[k];
//    }

//    // Write output
//    {
//        int x = min(max(dx, 0), maxX);
//        int y = min(max(dy, 0), maxY);
//        gOutput[int2(x, y)] = blurColor;
//    }
//}
