# 🐜 蚂蚁化工 · AntChem

> *"每一只蚂蚁都是炸药工程师。每一个坩埚都是一次赌博。每一次爆炸都是一场物理喜剧。"*

---

## 这是什么

**AntChem** 是一款 2D 像素风独立游戏。你是蚁巢里最危险的那只行军蚁——**炸药工程师**。

在萤火虫照亮的洞穴实验室里，从 16 种天然原料中合成炸药，去试验场引爆验证，亲手命名，然后带着你的作品去完成蚁后的任务。

## 快速开始

1. 用 Godot 4.4 打开 `project.godot`
2. 按 **F5** 运行
3. 从蚁巢中枢进入洞穴实验室，选原料 → 调研磨/温度 → 合成 → 去试验场引爆

## 开发状态

| 系统 | 状态 |
|------|------|
| 合成配方数据库 | ✅ 9 节点原型 (黑火药→栗色/慢燃 + 中间体 + TNT 线) |
| 设备商店 | ✅ 14 件设备 + 购买逻辑 |
| 原料库存 | ✅ 16 种自然原料 |
| 洞穴实验室 | ✅ 洞穴背景 + 萤火虫光源 + 暗角 + 合成图 + 工作台 |
| 试验场 | ✅ RigidBody2D 建筑破坏 + 粒子 + 引爆 + 命名 |
| 章节选择 | ✅ 三章卡片 UI |
| 蚁巢中枢 | ✅ 场景导航 |
| 像素美术资产 | ✅ 128 程序化精灵 (原料/设备/角色/场景/特效/UI) |
| 音效 | ⬜ Alpha 阶段 |

## 项目结构

```
game_create/
├── assets/           # 128 程序化像素精灵 (python tools/generate_all.py)
├── autoload/         # 全局单例: RecipeDB, EquipmentStore, InventoryManager
├── resources/        # AssetMap (代码→贴图路径映射)
├── scenes/           # 6 个 Godot 场景 (.tscn)
├── scripts/          # 场景对应 GDScript
├── tools/            # 精灵生成引擎 (pixel_art/) + 主生成器 (generate_all.py)
├── DESIGN.md         # 设计宪法: 色板/像素规格/UI 组件/禁止事项
└── project.godot     # Godot 4.4 项目配置
```

## 美术管线

所有像素精灵通过程序化生成——噪波纹理、晶体生长、抖动阴影、刻面渲染：

```bash
python tools/generate_all.py
```

输出 128 个精灵到 `assets/`，覆盖原料/设备/角色/场景/粒子/UI/动画帧。

## 技术

| 项目 | 选择 |
|------|------|
| 引擎 | Godot 4.4 + GDScript |
| 物理 | GodotPhysics2D |
| 粒子 | GPUParticles2D |
| 像素规格 | 32×32 per tile，13 色板 (DESIGN.md) |
| 美术 | 程序化生成 (NumPy + Pillow) |
| 许可 | MIT |
