#include <iostream>
#include "../../../Common/Camera.h"
#include "../../../Common/d3dApp.h"
#include "../../../Common/d3dUtil.h"
#include "../../../Common/DDSTextureLoader.h"
#include "../../../Common/GameTimer.h"
#include "../../../Common/GeometryGenerator.h"
#include "../../../Common/MathHelper.h"

int main()
{
    const D3D12_INPUT_ELEMENT_DESC InputLayout[] =
    {
        // SemanticName, SemanticIndex, Format,                   InputSlot, AlignedByteOffset,            InputSlotClass,           InstanceDataStepRate
        { "POSITION",  0, DXGI_FORMAT_R32G32B32_FLOAT,           0,         0,                 D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TANGENT",   0, DXGI_FORMAT_R32G32B32_FLOAT,           0,         12,                D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "NORMAL",    0, DXGI_FORMAT_R32G32B32_FLOAT,           0,         24,                D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD",  0, DXGI_FORMAT_R32G32_FLOAT,              0,         36,                D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD",  1, DXGI_FORMAT_R32G32_FLOAT,              0,         44,                D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "COLOR",     0, DXGI_FORMAT_R8G8B8A8_UNORM,            0,         52,                D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };
    const UINT NumElements = _countof(InputLayout);
}
