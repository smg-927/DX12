#include	<windows.h>	
#include	<DirectXMath.h>
#include	<DirectXPackedVector.h>
#include	<iostream>
#include	<random>

using	namespace	std;
using	namespace	DirectX;
using	namespace	DirectX::PackedVector;


void run_ex01_03() {
	
    // 랜덤 엔진 생성
    std::random_device rd;  // 하드웨어 난수 시드 (가능하면)
    std::mt19937 gen(rd()); // Mersenne Twister 엔진

    // float 범위 지정 (예: 0.0 ~ 10.0)
    std::uniform_real_distribution<float> dist(0.0f, 10.0f);

    XMVECTOR u = XMVectorSet(dist(gen), dist(gen), dist(gen), 0.0f);
    XMVECTOR v = XMVectorSet(dist(gen), dist(gen), dist(gen), 0.0f);
    XMVECTOR w = XMVectorSet(dist(gen), dist(gen), dist(gen), 0.0f);

    XMFLOAT4 uf, vf, wf;
    XMStoreFloat4(&uf, u);
    XMStoreFloat4(&vf, v);
    XMStoreFloat4(&wf, w);

    cout << "u : " << "(" << uf.x << "," << uf.y << "," << uf.z << ")" << endl;
    cout << "v : " << "(" << vf.x << "," << vf.y << "," << vf.z << ")" << endl;
    cout << "w : " << "(" << wf.x << "," << wf.y << "," << wf.z << ")" << endl;

    float c, k;
    c = dist(gen);
    k = dist(gen);

    cout << "c : " << c << endl;
    cout << "k : " << k << endl;

    // 1)
    XMVECTOR uplusv = u + v;
    XMVECTOR vplusu = v + u;

    XMFLOAT4 uplusvf, vplusuf;

    XMStoreFloat4(&uplusvf, uplusv);
    XMStoreFloat4(&vplusuf, vplusu);

    bool ans1;

    if (uplusvf.x == vplusuf.x && uplusvf.y == vplusuf.y && uplusvf.z == vplusuf.z)
    {
        ans1 = true;
    }
    else
    {
        ans1 = false;
    }
    // 2)
    
    XMVECTOR comp1 = u + (v + w);
    XMVECTOR comp2 = (u + v) + w;

    XMFLOAT4 comp1f, comp2f;

    XMStoreFloat4(&comp1f, comp1);
    XMStoreFloat4(&comp2f, comp2);

    bool ans2;

    if (comp1f.x == comp2f.x && comp1f.y == comp2f.y && comp1f.z == comp2f.z)
    {
        ans2 = true;
    }
    else
    {
        ans2 = false;
    }

    // 3)

    XMVECTOR comp3 = (c * k) * u;
    XMVECTOR comp4 = c * (k * u);

    XMFLOAT4 comp3f, comp4f;

    XMStoreFloat4(&comp3f, comp3);
    XMStoreFloat4(&comp4f, comp4);

    bool ans3;

    if (comp3f.x == comp4f.x && comp3f.y == comp4f.y && comp3f.z == comp4f.z)
    {
        ans3 = true;
    }
    else
    {
        ans3 = false;
    }

    // 4)

    XMVECTOR comp5 = k * (u + v);
    XMVECTOR comp6 = k * u + k * v;

    XMFLOAT4 comp5f, comp6f;

    XMStoreFloat4(&comp5f, comp5);
    XMStoreFloat4(&comp6f, comp6);

    bool ans4;

    if (comp5f.x == comp6f.x && comp5f.y == comp6f.y && comp5f.z == comp6f.z)
    {
        ans4 = true;
    }
    else
    {
        ans4 = false;
    }

    // 5)
    
    XMVECTOR comp7 = u * (k + c);
    XMVECTOR comp8 = k * u + c * u;

    XMFLOAT4 comp7f, comp8f;

    XMStoreFloat4(&comp7f, comp7);
    XMStoreFloat4(&comp8f, comp8);

    bool ans5;

    if (comp7f.x == comp8f.x && comp7f.y == comp8f.y && comp7f.z == comp8f.z)
    {
        ans5 = true;
    }
    else
    {
        ans5 = false;
    }

    // answer print
    cout << "ans1) u + v = v + u -> " << ans1 << endl;
    cout << "ans2) u + (v + w) = (u + v) + w -> " << ans2 << endl;
    cout << "ans3) (ck)u = c(ku) -> " << ans3 << endl;
    cout << "ans4) k(u + v) = ku + kv -> " << ans4 << endl;
    cout << "ans5) u(k + c) = ku + cu -> " << ans5 << endl;

    // 부동 소수점으로 인해 false가 나옴/.
}
