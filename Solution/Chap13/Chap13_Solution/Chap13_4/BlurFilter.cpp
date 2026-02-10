//***************************************************************************************
// BlurFilter.cpp by Frank Luna (C) 2011 All Rights Reserved.
//***************************************************************************************

#include "BlurFilter.h"


BlurFilter::BlurFilter(ID3D12Device* device, 
	                   UINT width, UINT height,
                       DXGI_FORMAT format)
{
	md3dDevice = device;

	mWidth = width;
	mHeight = height;
	mFormat = format;

	BuildResources();
	mSettingsCB = std::make_unique<UploadBuffer<CBSettings>>(md3dDevice, 1, true);

}

ID3D12Resource* BlurFilter::Output()
{
	return mBlurMap0.Get();
}

void BlurFilter::BuildDescriptors(CD3DX12_CPU_DESCRIPTOR_HANDLE hCpuDescriptor,
	                              CD3DX12_GPU_DESCRIPTOR_HANDLE hGpuDescriptor,
	                              UINT descriptorSize)
{
	// Save references to the descriptors. 
	mBlur0CpuSrv = hCpuDescriptor;
	mBlur0CpuUav = hCpuDescriptor.Offset(1, descriptorSize);
	mBlur1CpuSrv = hCpuDescriptor.Offset(1, descriptorSize);
	mBlur1CpuUav = hCpuDescriptor.Offset(1, descriptorSize);

	mBlur0GpuSrv = hGpuDescriptor;
	mBlur0GpuUav = hGpuDescriptor.Offset(1, descriptorSize);
	mBlur1GpuSrv = hGpuDescriptor.Offset(1, descriptorSize);
	mBlur1GpuUav = hGpuDescriptor.Offset(1, descriptorSize);

	BuildDescriptors();
}

void BlurFilter::OnResize(UINT newWidth, UINT newHeight)
{
	if((mWidth != newWidth) || (mHeight != newHeight))
	{
		mWidth = newWidth;
		mHeight = newHeight;

		BuildResources();

		// New resource, so we need new descriptors to that resource.
		BuildDescriptors();
	}
}
 
void BlurFilter::Execute(
	ID3D12GraphicsCommandList* cmdList,
	ID3D12RootSignature* rootSig,
	ID3D12PipelineState* bilateralBlurPSO,
	ID3D12Resource* input,
	int blurCount)
{

	const int blurRadius = 3;

	std::vector<float> weights49 = CalcGaussWeights(2.0f);
	
	CBSettings s = {};
	s.gBlurRadius = blurRadius;
	for (int i = 0; i < 49; ++i)
		s.weight[i] = weights49[i];

	mSettingsCB->CopyData(0, s);

	cmdList->SetComputeRootSignature(rootSig);

	cmdList->SetComputeRootConstantBufferView(
		0,
		mSettingsCB->Resource()->GetGPUVirtualAddress());

	auto transition = CD3DX12_RESOURCE_BARRIER::Transition(
		input,
		D3D12_RESOURCE_STATE_RENDER_TARGET,
		D3D12_RESOURCE_STATE_COPY_SOURCE);
	cmdList->ResourceBarrier(1, &transition);

	transition = CD3DX12_RESOURCE_BARRIER::Transition(
		mBlurMap0.Get(),
		D3D12_RESOURCE_STATE_COMMON,
		D3D12_RESOURCE_STATE_COPY_DEST);
	cmdList->ResourceBarrier(1, &transition);

	cmdList->CopyResource(mBlurMap0.Get(), input);

	transition = CD3DX12_RESOURCE_BARRIER::Transition(
		mBlurMap0.Get(),
		D3D12_RESOURCE_STATE_COPY_DEST,
		D3D12_RESOURCE_STATE_GENERIC_READ); // SRV read
	cmdList->ResourceBarrier(1, &transition);

	transition = CD3DX12_RESOURCE_BARRIER::Transition(
		mBlurMap1.Get(),
		D3D12_RESOURCE_STATE_COMMON,
		D3D12_RESOURCE_STATE_UNORDERED_ACCESS); // UAV write
	cmdList->ResourceBarrier(1, &transition);

	for (int i = 0; i < blurCount; ++i)
	{
		cmdList->SetPipelineState(bilateralBlurPSO);

		const bool even = (i % 2 == 0);

		CD3DX12_GPU_DESCRIPTOR_HANDLE srv = even ? mBlur0GpuSrv : mBlur1GpuSrv;
		CD3DX12_GPU_DESCRIPTOR_HANDLE uav = even ? mBlur1GpuUav : mBlur0GpuUav;

		cmdList->SetComputeRootDescriptorTable(1, srv);
		cmdList->SetComputeRootDescriptorTable(2, uav);

		UINT numGroupsX = (mWidth + 16 - 1) / 16;
		UINT numGroupsY = (mHeight + 16 - 1) / 16;
		cmdList->Dispatch(numGroupsX, numGroupsY, 1);

		auto uavBarrier = CD3DX12_RESOURCE_BARRIER::UAV(even ? mBlurMap1.Get() : mBlurMap0.Get());
		cmdList->ResourceBarrier(1, &uavBarrier);

		auto toRead = even ? mBlurMap0.Get() : mBlurMap1.Get();
		auto toWrite = even ? mBlurMap1.Get() : mBlurMap0.Get();

		auto t1 = CD3DX12_RESOURCE_BARRIER::Transition(
			toRead,
			D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
			D3D12_RESOURCE_STATE_GENERIC_READ);

		auto t2 = CD3DX12_RESOURCE_BARRIER::Transition(
			toWrite,
			D3D12_RESOURCE_STATE_GENERIC_READ,
			D3D12_RESOURCE_STATE_UNORDERED_ACCESS);

		cmdList->ResourceBarrier(1, &t1);
		cmdList->ResourceBarrier(1, &t2);
	}


}

 
std::vector<float> BlurFilter::CalcGaussWeights(float sigma)
{
	const int radius = 3;                 // 7x7 => radius 3
	const int size = 2 * radius + 1;    // 7
	const float twoSigma2 = 2.0f * sigma * sigma;

	assert(sigma > 0.0f);

	std::vector<float> weights(size * size); // 49
	float weightSum = 0.0f;

	for (int y = -radius; y <= radius; ++y)
	{
		for (int x = -radius; x <= radius; ++x)
		{
			const float fx = (float)x;
			const float fy = (float)y;

			// 2D Gaussian: exp(-(x^2 + y^2) / (2*sigma^2))
			const float w = std::exp(-(fx * fx + fy * fy) / twoSigma2);

			const int ix = x + radius;
			const int iy = y + radius;
			weights[iy * size + ix] = w;

			weightSum += w;
		}
	}

	// Normalize so sum = 1
	for (float& w : weights)
		w /= weightSum;

	return weights;
}

void BlurFilter::BuildDescriptors()
{
	D3D12_SHADER_RESOURCE_VIEW_DESC srvDesc = {};
	srvDesc.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
	srvDesc.Format = mFormat;
	srvDesc.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE2D;
	srvDesc.Texture2D.MostDetailedMip = 0;
	srvDesc.Texture2D.MipLevels = 1;

	D3D12_UNORDERED_ACCESS_VIEW_DESC uavDesc = {};

	uavDesc.Format = mFormat;
	uavDesc.ViewDimension = D3D12_UAV_DIMENSION_TEXTURE2D;
	uavDesc.Texture2D.MipSlice = 0;

	md3dDevice->CreateShaderResourceView(mBlurMap0.Get(), &srvDesc, mBlur0CpuSrv);
	md3dDevice->CreateUnorderedAccessView(mBlurMap0.Get(), nullptr, &uavDesc, mBlur0CpuUav);

	md3dDevice->CreateShaderResourceView(mBlurMap1.Get(), &srvDesc, mBlur1CpuSrv);
	md3dDevice->CreateUnorderedAccessView(mBlurMap1.Get(), nullptr, &uavDesc, mBlur1CpuUav);
}

void BlurFilter::BuildResources()
{
	// Note, compressed formats cannot be used for UAV.  We get error like:
	// ERROR: ID3D11Device::CreateTexture2D: The format (0x4d, BC3_UNORM) 
	// cannot be bound as an UnorderedAccessView, or cast to a format that
	// could be bound as an UnorderedAccessView.  Therefore this format 
	// does not support D3D11_BIND_UNORDERED_ACCESS.

	D3D12_RESOURCE_DESC texDesc;
	ZeroMemory(&texDesc, sizeof(D3D12_RESOURCE_DESC));
	texDesc.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
	texDesc.Alignment = 0;
	texDesc.Width = mWidth;
	texDesc.Height = mHeight;
	texDesc.DepthOrArraySize = 1;
	texDesc.MipLevels = 1;
	texDesc.Format = mFormat;
	texDesc.SampleDesc.Count = 1;
	texDesc.SampleDesc.Quality = 0;
	texDesc.Layout = D3D12_TEXTURE_LAYOUT_UNKNOWN;
	texDesc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;

	CD3DX12_HEAP_PROPERTIES heapProps = CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_DEFAULT);

	ThrowIfFailed(md3dDevice->CreateCommittedResource(
		&heapProps,
		D3D12_HEAP_FLAG_NONE,
		&texDesc,
		D3D12_RESOURCE_STATE_COMMON,
		nullptr,
		IID_PPV_ARGS(&mBlurMap0)));

	ThrowIfFailed(md3dDevice->CreateCommittedResource(
		&heapProps,
		D3D12_HEAP_FLAG_NONE,
		&texDesc,
		D3D12_RESOURCE_STATE_COMMON,
		nullptr,
		IID_PPV_ARGS(&mBlurMap1)));
}