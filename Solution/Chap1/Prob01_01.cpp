#include	<windows.h>	//	for	XMVerifyCPUSupport
#include	<DirectXMath.h>
#include	<DirectXPackedVector.h>
#include	<iostream>

using	namespace	std;
using	namespace	DirectX;
using	namespace	DirectX::PackedVector;


void run_ex01_01() {

	printf("Running Exerciasdfadfse 01\n");

	XMVECTOR u = XMVectorSet(1.0f, 2.0f, 0.0f, 0.0f);
	XMVECTOR v = XMVectorSet(3.0f, -4.0f, 0.0f, 0.0f);

	// 1)
	XMVECTOR ans1 = u + v;
	// 2)
	XMVECTOR ans2 = u - v;
	// 3)
	XMVECTOR ans3 = (2 * u) + (0.5 * v);
	// 4) 
	XMVECTOR ans4 = (-2 * u) + v;


	XMFLOAT4 a1, a2, a3, a4;

	XMStoreFloat4(&a1, ans1);
	XMStoreFloat4(&a2, ans2);
	XMStoreFloat4(&a3, ans3);
	XMStoreFloat4(&a4, ans4);

	// Ãâ·Â
	cout << "ans1: (" << a1.x << ", " << a1.y << ", " << a1.z << ", " << a1.w << ")\n";
	cout << "ans2: (" << a2.x << ", " << a2.y << ", " << a2.z << ", " << a2.w << ")\n";
	cout << "ans3: (" << a3.x << ", " << a3.y << ", " << a3.z << ", " << a3.w << ")\n";
	cout << "ans4: (" << a4.x << ", " << a4.y << ", " << a4.z << ", " << a4.w << ")\n";
}
