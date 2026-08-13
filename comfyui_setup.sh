#!/bin/bash
# ComfyUI 环境配置脚本 — P0
# 运行: bash comfyui_setup.sh
# ComfyUI 路径: D:/ComfyUI

COMFY="D:/ComfyUI"
MODELS="$COMFY/models"

echo "========================================"
echo " 华夏模拟人生 — ComfyUI 环境配置 P0"
echo " ComfyUI: $COMFY"
echo "========================================"

# ── 1. 检查 SDXL Base ──
echo ""
echo "[1/5] 检查 SDXL Base..."
if [ -f "$MODELS/checkpoints/sd_xl_base_1.0.safetensors" ]; then
    echo "  ✅ sd_xl_base_1.0.safetensors 已存在"
else
    echo "  ⚠️ 需要下载 SDXL Base 1.0"
    echo "  📥 https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"
    echo "  → 保存到: $MODELS/checkpoints/"
fi

# ── 2. 安装 Custom Nodes ──
echo ""
echo "[2/5] 安装 ComfyUI 自定义节点..."
cd "$COMFY/custom_nodes"

declare -A NODES=(
    ["ComfyUI-Manager"]="https://github.com/ltdrdata/ComfyUI-Manager.git"
    ["ComfyUI_IPAdapter_plus"]="https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
    ["comfyui_controlnet_aux"]="https://github.com/Fannovel16/comfyui_controlnet_aux.git"
    ["ComfyUI-Advanced-ControlNet"]="https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
    ["rgthree-comfy"]="https://github.com/rgthree/rgthree-comfy.git"
    ["ComfyUI_UltimateSDUpscale"]="https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
)

for node in "${!NODES[@]}"; do
    if [ -d "$node" ]; then
        echo "  ✅ $node"
    else
        echo "  📥 安装 $node..."
        git clone "${NODES[$node]}" 2>/dev/null && echo "  ✅ $node 完成" || echo "  ❌ $node 失败"
    fi
done

# ── 3. LoRA 下载指引 ──
echo ""
echo "[3/5] LoRA 模型下载指引..."
echo "  以下 LoRA 需要手动下载（CivitAI/liblib.art）："
echo ""
echo "  📥 汉服古风 LoRA (Hanfu Style):"
echo "     https://civitai.com/ 搜索 'hanfu' 或 'chinese ancient clothing'"
echo "     → 保存到: $MODELS/loras/hanfu_style.safetensors"
echo ""
echo "  📥 青铜纹样 LoRA (Bronze Pattern):"
echo "     https://www.liblib.art/ 搜索 '青铜纹样' 或 '饕餮纹'"
echo "     → 保存到: $MODELS/loras/bronze_pattern.safetensors"
echo ""
echo "  📥 中国古代建筑 LoRA:"
echo "     https://civitai.com/ 搜索 'ancient chinese architecture'"
echo "     → 保存到: $MODELS/loras/ancient_architecture.safetensors"
echo ""
echo "  💡 也可以先用 SDXL Base 裸模型直接生成，效果足够好。"

# ── 4. ControlNet 下载指引 ──
echo ""
echo "[4/5] ControlNet 下载指引（可选）..."
echo "  📥 Tiling ControlNet (用于无缝纹理):"
echo "     https://huggingface.co/lllyasviel/sd_control_collection"
echo "     → 保存到: $MODELS/controlnet/"
echo "  💡 生成 UI 纹理建议使用 Tiling ControlNet，不装也能先生成。"

# ── 5. 验证清单 ──
echo ""
echo "[5/5] 环境验证清单:"
echo "  [ ] SDXL Base checkpoint 就位"
echo "  [ ] ComfyUI Manager 可加载"
echo "  [ ] 能成功生成一张测试图 (512×512, 20步)"
echo "  [ ] LoRA 模型就位 (可选)"
echo "  [ ] ControlNet 就位 (可选)"
echo ""
echo "========================================"
echo " 配置完成！启动 ComfyUI:"
echo "   cd $COMFY"
echo "   python main.py --listen 127.0.0.1 --port 8188"
echo ""
echo " 然后运行批量生成:"
echo "   cd E:/技术资料/项目/mnrs"
echo "   python batch_generate.py --category ui"
echo "========================================"
