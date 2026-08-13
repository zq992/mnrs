#!/usr/bin/env python3
"""批量调用 ComfyUI API 生成游戏资产
用法: python batch_generate.py [--category portraits|backgrounds|ui|icons|events|all]
     ComfyUI 需已在 D:\ComfyUI 启动: python main.py --listen 127.0.0.1 --port 8188
"""
import json, urllib.request, urllib.parse, time, os, sys, argparse
from pathlib import Path

COMFY_URL = "http://127.0.0.1:8188"
OUTPUT_BASE = Path("D:/ComfyUI/output")
PROJECT_ASSETS = Path("E:/技术资料/项目/mnrs/resources/textures")

# ============================================================
# 全局负向提示词
# ============================================================
NEGATIVE = (
    "(worst quality, low quality, normal quality:1.4), "
    "(multiple limbs, extra fingers, fused fingers, missing fingers:1.3), "
    "(modern clothing, modern buildings, modern elements:1.5), "
    "(signature, watermark, text, logo, username:1.3), "
    "(anime, cartoon, 3d render, cgi:1.4), "
    "(blurry, jpeg artifacts, noise, grain:1.2), "
    "(asymmetrical eyes, bad anatomy, deformed:1.3), "
    "(Western architecture, European style, Gothic:1.4), "
    "(neon lights, electricity, technology:1.5)"
)

# ============================================================
# 工作流模板 — 根据类别构建节点图
# ============================================================
def make_workflow(prompt: str, neg: str, width: int, height: int,
                  checkpoint: str = "sd_xl_base_1.0.safetensors",
                  steps: int = 30, cfg: float = 7.0,
                  seed: int = -1, sampler: str = "dpmpp_2m",
                  scheduler: str = "karras",
                  output_prefix: str = "output",
                  lora_stack: list = None) -> dict:
    """构建标准 SDXL txt2img 工作流"""
    if seed == -1:
        import random
        seed = random.randint(1, 2**31 - 1)

    nodes = {
        "1": {  # CheckpointLoader
            "inputs": {"ckpt_name": checkpoint},
            "class_type": "CheckpointLoaderSimple"
        },
        "2": {  # Positive CLIP
            "inputs": {
                "text": prompt,
                "clip": ["1", 1]
            },
            "class_type": "CLIPTextEncode"
        },
        "3": {  # Negative CLIP
            "inputs": {
                "text": neg,
                "clip": ["1", 1]
            },
            "class_type": "CLIPTextEncode"
        },
        "4": {  # Empty Latent
            "inputs": {
                "width": width,
                "height": height,
                "batch_size": 1
            },
            "class_type": "EmptyLatentImage"
        },
        "5": {  # KSampler
            "inputs": {
                "seed": seed,
                "steps": steps,
                "cfg": cfg,
                "sampler_name": sampler,
                "scheduler": scheduler,
                "denoise": 1.0,
                "model": ["1", 0],
                "positive": ["2", 0],
                "negative": ["3", 0],
                "latent_image": ["4", 0]
            },
            "class_type": "KSampler"
        },
        "6": {  # VAEDecode
            "inputs": {
                "samples": ["5", 0],
                "vae": ["1", 2]
            },
            "class_type": "VAEDecode"
        },
        "7": {  # SaveImage
            "inputs": {
                "filename_prefix": output_prefix,
                "images": ["6", 0]
            },
            "class_type": "SaveImage"
        }
    }
    return nodes


def queue_prompt(workflow: dict) -> dict:
    """提交工作流到 ComfyUI"""
    data = json.dumps({"prompt": workflow}).encode("utf-8")
    req = urllib.request.Request(f"{COMFY_URL}/prompt", data=data)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def get_history(prompt_id: str) -> dict:
    """获取任务结果"""
    with urllib.request.urlopen(f"{COMFY_URL}/history/{prompt_id}") as resp:
        return json.loads(resp.read())


def wait_for_completion(prompt_id: str, timeout: int = 600) -> dict:
    """等待任务完成"""
    start = time.time()
    while time.time() - start < timeout:
        history = get_history(prompt_id)
        if prompt_id in history:
            return history[prompt_id]
        time.sleep(2)
    raise TimeoutError(f"生成超时 ({timeout}s)")


# ============================================================
# 提示词库
# ============================================================
PROMPTS = {
    # ── UI 纹理 ──
    "ui": [
        {
            "name": "panel_bg",
            "prompt": (
                "(masterpiece, best quality:1.2), seamless tileable dark bronze "
                "panel texture, ancient Chinese Western Zhou dynasty bronze vessel "
                "surface, subtle cloud-thunder pattern (云雷纹), dark greenish-brown "
                "patina, oxidized copper, smooth surface with subtle spiral relief "
                "patterns, even lighting, flat texture, no shadows, game UI panel "
                "background, 2D texture map, tiling texture, repeatable pattern"
            ),
            "w": 512, "h": 512, "steps": 25, "cfg": 7.0,
            "output": "ui_textures/panel_bg"
        },
        {
            "name": "panel_corner_taotie",
            "prompt": (
                "taotie mask pattern (饕餮纹), ancient Chinese bronze ritual vessel "
                "decoration, symmetrical monster face with bulging eyes and horns, "
                "intricate spiral and thunder patterns surrounding, dark bronze and "
                "gold color scheme, square composition, ornamental design, traditional "
                "Chinese bronze art, flat 2D ornament, decorative corner piece, "
                "symmetrical, vector style"
            ),
            "w": 256, "h": 256, "steps": 25, "cfg": 8.0,
            "output": "ui_textures/panel_corner"
        },
        {
            "name": "panel_border_h",
            "prompt": (
                "seamless horizontal border strip with Chinese cloud-thunder pattern "
                "(云雷纹), ancient Chinese Western Zhou bronze decorative band, "
                "continuous spiral meander pattern, dark bronze with subtle gold "
                "highlights, flat 2D ornamental border, horizontal repeating pattern, "
                "even lighting, game UI border element"
            ),
            "w": 512, "h": 64, "steps": 25, "cfg": 7.0,
            "output": "ui_textures/panel_border_h"
        },
        {
            "name": "button_normal",
            "prompt": (
                "horizontal button-shaped bronze plate, ancient Chinese Western Zhou "
                "dynasty decorative metal plaque, rectangular with slightly rounded "
                "corners, simple cloud pattern (云纹) border, dark bronze center with "
                "subtle texture, game UI button, 2D flat design, centered composition"
            ),
            "w": 256, "h": 64, "steps": 20, "cfg": 6.0,
            "output": "ui_textures/button_normal"
        },
        {
            "name": "bar_health",
            "prompt": (
                "seamless thin horizontal strip, ancient Chinese cinnabar red (朱砂) "
                "texture for health bar, fine granular pigment texture, vermillion tone, "
                "flat 2D colored strip, game UI health bar fill, solid color with "
                "minimal grain texture"
            ),
            "w": 256, "h": 32, "steps": 20, "cfg": 5.0,
            "output": "ui_textures/bar_health"
        },
        {
            "name": "bar_reputation",
            "prompt": (
                "seamless thin horizontal strip, ancient Chinese bronze green texture "
                "for reputation bar, oxidized copper patina color, flat 2D colored "
                "strip, game UI bar fill"
            ),
            "w": 256, "h": 32, "steps": 20, "cfg": 5.0,
            "output": "ui_textures/bar_reputation"
        },
        {
            "name": "bar_power",
            "prompt": (
                "seamless thin horizontal strip, ancient Chinese dark gold texture "
                "for power bar, subtle metallic sheen, flat 2D colored strip, "
                "game UI bar fill"
            ),
            "w": 256, "h": 32, "steps": 20, "cfg": 5.0,
            "output": "ui_textures/bar_power"
        },
        {
            "name": "bar_ambition",
            "prompt": (
                "seamless thin horizontal strip, ancient Chinese ochre reddish-brown "
                "texture for ambition bar, earthy pigment tone, flat 2D colored strip, "
                "game UI bar fill"
            ),
            "w": 256, "h": 32, "steps": 20, "cfg": 5.0,
            "output": "ui_textures/bar_ambition"
        },
    ],

    # ── 角色立绘 ──
    "portraits": [
        {
            "name": "player_young_shi",
            "prompt": (
                "(masterpiece, best quality:1.2), 1boy, young man, 20 years old, "
                "ancient Chinese nobility, Western Zhou dynasty scholar-official (士), "
                "wearing traditional dark deep blue 深衣 (shenyi robe) with bronze belt "
                "hooks, black hair tied in a topknot with simple jade hairpin, dignified "
                "expression, calm and refined, bronze ritual vessel patterns on sleeve "
                "cuffs, standing in ancient Chinese courtyard, soft natural lighting, "
                "overcast sky, ancient Chinese ink painting aesthetics, elegant brushwork "
                "feel, (low saturation, muted earth tones:1.1), full body portrait"
            ),
            "w": 512, "h": 768, "steps": 30, "cfg": 7.0,
            "output": "portraits/player_young_shi"
        },
        {
            "name": "npc_wife",
            "prompt": (
                "(masterpiece, best quality:1.2), 1girl, young Chinese noblewoman, "
                "18 years old, Western Zhou dynasty lady, wearing elegant 曲裾深衣 "
                "(curved-hem robe) in warm earth tones, simple jade hair ornaments, "
                "modest and graceful expression, lowered eyes, seated in a quiet chamber "
                "with weaving loom nearby, soft diffused light through paper windows, "
                "gentle and refined atmosphere, ancient Chinese portrait painting style, "
                "delicate lines, full body portrait"
            ),
            "w": 512, "h": 768, "steps": 28, "cfg": 6.5,
            "output": "portraits/npc_wife"
        },
        {
            "name": "npc_father",
            "prompt": (
                "(masterpiece, best quality:1.2), 1man, middle-aged Chinese scholar, "
                "45 years old, Western Zhou minor official, wearing simple grey-blue "
                "深衣, plain cloth cap (缁布冠), dignified fatherly expression, "
                "holding bamboo slips, modest study room background, warm lighting, "
                "ancient Chinese portrait, half body"
            ),
            "w": 512, "h": 768, "steps": 28, "cfg": 7.0,
            "output": "portraits/npc_father"
        },
        {
            "name": "npc_colleague",
            "prompt": (
                "(masterpiece, best quality:1.2), 1boy, young Chinese scholar, 25 years "
                "old, Western Zhou minor official, wearing simple grey-blue 深衣, plain "
                "cloth cap, friendly yet reserved expression, holding bamboo slips (竹简) "
                "in hands, modest study room background with scrolls and bronze lamps, "
                "gentle light from window, ancient Chinese literati painting aesthetic"
            ),
            "w": 512, "h": 768, "steps": 28, "cfg": 6.5,
            "output": "portraits/npc_colleague"
        },
    ],

    # ── 城市背景 ──
    "backgrounds": [
        {
            "name": "city_haojing",
            "prompt": (
                "(masterpiece, best quality:1.2), ancient Chinese capital city, "
                "Western Zhou dynasty Haojing (镐京), grand earthen city walls with "
                "watchtowers, rammed earth architecture (夯土建筑), ceremonial bronze "
                "tripods in public squares, wide straight avenues, horse-drawn chariots, "
                "busy marketplace with merchants and farmers, Fenghao ruins archaeological "
                "reconstruction style, overcast autumn sky, misty atmosphere, distant "
                "Qinling mountains silhouette, epic historical illustration, wide "
                "panoramic landscape, ancient Chinese architectural painting"
            ),
            "w": 1280, "h": 720, "steps": 35, "cfg": 8.0,
            "output": "backgrounds/city_haojing"
        },
        {
            "name": "city_luoyi",
            "prompt": (
                "(masterpiece, best quality:1.2), ancient Chinese eastern capital Luoyi "
                "(洛邑), newly built Zhou dynasty administrative city, symmetrical layout "
                "with central palace complex, wide Luo River flowing beside city walls, "
                "elegant bridges and water gates, government officials in robes walking "
                "along stone pathways, bronze workshops with smoke rising from furnaces, "
                "spring morning light, grand historical panorama"
            ),
            "w": 1280, "h": 720, "steps": 35, "cfg": 8.0,
            "output": "backgrounds/city_luoyi"
        },
    ],

    # ── 技能图标 ──
    "icons": [
        {
            "name": "skill_ritual",
            "prompt": (
                "game icon, ancient Chinese bronze ritual vessel (鼎), simple flat "
                "design, minimal detail, bronze tripod silhouette, golden outline on "
                "dark background, white background removed, transparent ready, game "
                "asset icon, 2D, vector style"
            ),
            "w": 512, "h": 512, "steps": 20, "cfg": 5.0,
            "output": "icons/skill_ritual"
        },
        {
            "name": "skill_archery",
            "prompt": (
                "game icon, ancient Chinese composite bow and chariot wheel, simple "
                "flat design, minimal detail, crossed bow and wheel silhouette, dark "
                "bronze on transparent, game asset icon, 2D, vector style"
            ),
            "w": 512, "h": 512, "steps": 20, "cfg": 5.0,
            "output": "icons/skill_archery"
        },
        {
            "name": "skill_writing",
            "prompt": (
                "game icon, bamboo slips (竹简) tied with string and abacus/算筹, "
                "simple flat design, natural bamboo color, transparent background, "
                "2D game asset icon, vector style"
            ),
            "w": 512, "h": 512, "steps": 20, "cfg": 5.0,
            "output": "icons/skill_writing"
        },
        {
            "name": "skill_music",
            "prompt": (
                "game icon, ancient Chinese bronze bells (编钟) and stone chimes (编磬), "
                "simple flat design, minimal detail, golden bronze, transparent "
                "background, 2D game asset icon"
            ),
            "w": 512, "h": 512, "steps": 20, "cfg": 5.0,
            "output": "icons/skill_music"
        },
        {
            "name": "skill_strategy",
            "prompt": (
                "game icon, ancient Chinese bronze dagger-axe (戈) and military flag, "
                "simple flat design, minimal detail, crossed weapons silhouette, "
                "transparent background, 2D game asset icon"
            ),
            "w": 512, "h": 512, "steps": 20, "cfg": 5.0,
            "output": "icons/skill_strategy"
        },
        {
            "name": "skill_medicine",
            "prompt": (
                "game icon, traditional Chinese medicine mortar and pestle with herbal "
                "bundle, simple flat design, natural earth tones, transparent background, "
                "2D game asset icon"
            ),
            "w": 512, "h": 512, "steps": 20, "cfg": 5.0,
            "output": "icons/skill_medicine"
        },
        {
            "name": "skill_persuasion",
            "prompt": (
                "game icon, ancient Chinese messenger tally (符节) with flame motif, "
                "simple flat design, dark bronze, transparent background, 2D game "
                "asset icon"
            ),
            "w": 512, "h": 512, "steps": 20, "cfg": 5.0,
            "output": "icons/skill_persuasion"
        },
    ],

    # ── 事件插图 ──
    "events": [
        {
            "name": "event_court",
            "prompt": (
                "(masterpiece, best quality:1.2), ancient Chinese court scene, Western "
                "Zhou dynasty, king or high official seated on a low platform, kneeling "
                "officials in ceremonial robes presenting bamboo slip reports, grand "
                "wooden hall with lacquer columns and bronze vessels, solemn atmosphere, "
                "dramatic lighting through high windows, historical illustration style, "
                "epic composition"
            ),
            "w": 768, "h": 512, "steps": 30, "cfg": 7.5,
            "output": "events/event_court_audience"
        },
        {
            "name": "event_martial",
            "prompt": (
                "(masterpiece, best quality:1.2), ancient Chinese military training "
                "ground, Western Zhou warriors in leather armor practicing archery and "
                "chariot combat, dust rising from galloping horses, wooden training "
                "weapons and targets, energetic and disciplined atmosphere, overcast "
                "sky, dramatic historical scene, Chinese historical movie still aesthetic"
            ),
            "w": 768, "h": 512, "steps": 30, "cfg": 7.5,
            "output": "events/event_martial_test"
        },
    ],
}


# ============================================================
# 主流程
# ============================================================
def generate_category(category: str, checkpoint: str = "sd_xl_base_1.0.safetensors"):
    """生成某一类别的所有资产"""
    items = PROMPTS.get(category, [])
    if not items:
        print(f"未知类别: {category}")
        print(f"可用类别: {list(PROMPTS.keys())}")
        return

    print(f"\n{'='*60}")
    print(f"开始批量生成: {category} ({len(items)} 项)")
    print(f"{'='*60}")

    for i, item in enumerate(items):
        name = item["name"]
        print(f"\n[{i+1}/{len(items)}] {name}")
        print(f"  尺寸: {item['w']}×{item['h']} | 步数: {item['steps']} | CFG: {item['cfg']}")

        wf = make_workflow(
            prompt=item["prompt"],
            neg=NEGATIVE,
            width=item["w"],
            height=item["h"],
            steps=item["steps"],
            cfg=item["cfg"],
            checkpoint=checkpoint,
            output_prefix=item["output"]
        )

        try:
            result = queue_prompt(wf)
            prompt_id = result.get("prompt_id")
            if prompt_id:
                print(f"  已提交: {prompt_id}, 等待完成...")
                history = wait_for_completion(prompt_id)
                print(f"  ✅ 完成 → {item['output']}_*.png")
            else:
                print(f"  ❌ 提交失败: {result}")
        except Exception as e:
            print(f"  ❌ 错误: {e}")

    print(f"\n{'='*60}")
    print(f"{category} 全部完成! 输出目录: D:/ComfyUI/output/")
    print(f"{'='*60}")


def main():
    parser = argparse.ArgumentParser(description="批量生成游戏资产到 ComfyUI")
    parser.add_argument("--category", "-c", default="all",
                        choices=["all", "ui", "portraits", "backgrounds", "icons", "events"],
                        help="资产生成类别 (默认: all)")
    parser.add_argument("--checkpoint", default="sd_xl_base_1.0.safetensors",
                        help="SDXL checkpoint 文件名 (默认: sd_xl_base_1.0.safetensors)")
    parser.add_argument("--list", action="store_true", help="列出所有提示词和类别")
    args = parser.parse_args()

    if args.list:
        for cat, items in PROMPTS.items():
            print(f"\n{cat} ({len(items)} 项):")
            for item in items:
                print(f"  - {item['name']}: {item['w']}×{item['h']} → {item['output']}")
        return

    print("=" * 60)
    print("华夏模拟人生 — ComfyUI 批量资产生成")
    print(f"ComfyUI: {COMFY_URL}")
    print(f"Checkpoint: {args.checkpoint}")
    print("=" * 60)

    if args.category == "all":
        for cat in ["ui", "portraits", "backgrounds", "icons", "events"]:
            generate_category(cat, args.checkpoint)
    else:
        generate_category(args.category, args.checkpoint)

    print("\n🎉 全部生成完成！")
    print(f"检查 D:/ComfyUI/output/ 下的子目录获取生成的资产")
    print(f"将满意的图片复制到 E:/技术资料/项目/mnrs/resources/textures/ 对应子目录")


if __name__ == "__main__":
    main()
