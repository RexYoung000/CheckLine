# Stage 2b-2 · 视觉设计报告（含 Design DNA）

> 模式：Deep　|　参考：Copilot Money（深空金融）+ PRODUCT.md 品牌口径

---

## 视觉概念

**「深空暖金」— Deep Space with Warm Gold**

预算线的视觉 DNA 源于一个张力：

- **深色画布**（来自 Copilot Money 的深空金融）— 让数据成为视觉焦点
- **暖金庆祝**（来自心愿基金的心智）— 让克制有温度，不让克制变成冷酷

> 记账的时刻是沉静的深空蓝，达成心愿的时刻是金色绽放。

---

## Design DNA JSON

```json
{
  "meta": {
    "name": "预算线 CheckLine · 深空暖金",
    "description": "以深色画布承载预算数据，以暖金庆祝承载心愿情感。克制的日常 + 绽放的高光。",
    "source_references": ["Copilot Money", "PRODUCT.md 品牌口径"],
    "created_at": "2026-06-11"
  },

  "design_system": {
    "color": {
      "palette_type": "analogous",
      "primary": {
        "hex": "#1A73E8",
        "role": "品牌主色 — 可交互元素、主进度条、选中态"
      },
      "secondary": {
        "hex": "#4FC3F7",
        "role": "辅助蓝 — 次要进度条、次级强调"
      },
      "accent": {
        "hex": "#FFB300",
        "role": "庆祝色 — 心愿达成、结算高光、分享卡片"
      },
      "neutral": {
        "scale": ["#000814", "#0D1B2A", "#1B2838", "#415A77", "#778DA9", "#E0E1DD"],
        "usage": "背景层级：Canvas(#000814) → Card(#0D1B2A) → 文字(#E0E1DD)"
      },
      "semantic": {
        "success": "#00C853",
        "warning": "#FFB300",
        "error": "#FF5252",
        "info": "#4FC3F7"
      },
      "surface": {
        "background": "#000814",
        "card": "#0D1B2A",
        "elevated": "#1B2838"
      },
      "contrast_strategy": "dark-on-light (扣血/支出用亮色在深底上)，gold-on-dark (庆祝)"
    },

    "typography": {
      "type_scale": {
        "display": { "size": "56pt", "weight": "bold", "line_height": "1.0", "tracking": "-0.5" },
        "heading_1": { "size": "34pt", "weight": "bold", "line_height": "1.1", "tracking": "-0.3" },
        "heading_2": { "size": "22pt", "weight": "semibold", "line_height": "1.2", "tracking": "0" },
        "heading_3": { "size": "17pt", "weight": "semibold", "line_height": "1.3", "tracking": "0" },
        "body": { "size": "15pt", "weight": "regular", "line_height": "1.5", "tracking": "0" },
        "body_small": { "size": "13pt", "weight": "regular", "line_height": "1.4", "tracking": "0" },
        "caption": { "size": "11pt", "weight": "medium", "line_height": "1.3", "tracking": "0.3" },
        "overline": { "size": "10pt", "weight": "semibold", "line_height": "1.2", "tracking": "0.5" }
      },
      "font_families": {
        "heading": "SF Pro Display",
        "body": "SF Pro Text",
        "mono": "SF Mono (金额数字)"
      },
      "font_style_notes": "中文字体搭配 PingFang SC。大金额数字用 SF Mono 的等宽特性保证对齐。"
    },

    "spacing": {
      "base_unit": "8pt",
      "scale": [4, 8, 12, 16, 20, 24, 32, 48, 64],
      "content_density": "comfortable",
      "section_rhythm": "32pt 主区块间隔，16pt 内间距"
    },

    "layout": {
      "grid_system": "单列 + 水平边距 20pt（iOS）；居中 640pt（macOS）",
      "max_content_width": "640pt",
      "columns": "1（mobile）/ 2（iPad + Mac sidebar）",
      "gutter": "16pt",
      "breakpoints": ["compact: <428pt", "regular: ≥428pt"],
      "alignment_tendency": "centered cards"
    },

    "shape": {
      "border_radius": {
        "small": "8pt",
        "medium": "12pt",
        "large": "16pt",
        "pill": "999pt"
      },
      "border_usage": "subtle 1px on cards (#1B2838)",
      "divider_style": "1px #1B2838, 左右缩进 16pt"
    },

    "elevation": {
      "shadow_style": "soft diffused",
      "levels": {
        "low": "y:2 blur:8 opacity:0.08",
        "medium": "y:4 blur:16 opacity:0.12",
        "high": "y:8 blur:32 opacity:0.16"
      },
      "depth_cues": "暗色层级递进（Canvas → Card → Elevated），轻阴影辅助"
    },

    "iconography": {
      "style": "SF Symbols 5，填充 + 轮廓混用",
      "stroke_weight": "2pt",
      "size_scale": [16, 20, 24, 32, 48],
      "preferred_set": "SF Symbols"
    },

    "motion": {
      "easing": "spring(duration: 0.4, bounce: 0.15) 用于微交互；easeInOut 0.3s 用于转场",
      "duration_scale": {
        "micro": "150ms — 选中/切换态",
        "normal": "300ms — 页面转场、扣血动效",
        "macro": "800ms — 结算高光、心愿达成"
      },
      "entrance_pattern": "fade + slight scaleUp(0.97→1)",
      "exit_pattern": "fadeOut 200ms",
      "philosophy": "日常克制（轻盈微交互），高光绽放（宏达仪式感）"
    },

    "components": {
      "button_style": "填充圆角按钮（主色），描边按钮（次要），纯文字按钮（取消）",
      "input_style": "底部圆角输入框 + placeholder 灰色",
      "card_style": "16pt 圆角 + 1px 边框 + 8pt 内间距",
      "navigation_pattern": "iOS: TabView 底部 4 tab；macOS: NavigationSplitView 侧栏",
      "modal_style": "iOS: .sheet (bottom) / .fullScreenCover (结算清单)；macOS: .sheet",
      "list_style": "圆形首字母 + 两行文字（PlainListStyle）",
      "component_notes": "BudgetTagChip: 选中=填充主色+白字，未选=描边主色+透明底"
    }
  },

  "design_style": {
    "aesthetic": {
      "mood": ["沉静", "专注", "温暖", "有节制", "值得期待"],
      "visual_metaphor": "深空中的仪表盘 — 在静谧的深色空间里，数据清晰发光；心愿像远处的金色星星",
      "era_influence": "当代极简 + 太空年代暖意",
      "genre": "premium iOS utility with emotional warmth",
      "personality_traits": ["克制的", "温柔的", "可靠的", "有仪式感的"],
      "adjectives": ["沉静不冷漠", "温暖不甜腻", "专业不僵硬"]
    },

    "visual_language": {
      "complexity": "minimal",
      "ornamentation": "subtle accents — 庆祝时刻才丰富",
      "whitespace_usage": "充足留白，让预算和心愿数字呼吸",
      "visual_weight_distribution": "C 位大数字 > 进度条 > 辅助信息",
      "focal_strategy": "single hero element — 主屏只聚焦「当前预算剩余」一个英雄数字",
      "contrast_level": "高对比（深底亮数据），低对比（卡片层级间的暗色递进）",
      "texture_usage": "无纹理，纯色 + 轻阴影"
    },

    "composition": {
      "hierarchy_method": "scale contrast — 大数字 + 粗体重 vs 小字轻量",
      "balance_type": "centered symmetry 主屏，asymmetric 详情页",
      "flow_direction": "top-down vertical scan",
      "grouping_strategy": "卡片分组 + 16pt 间距构建区块",
      "negative_space_role": "让数据「呼吸」，突出 C 位信息"
    },

    "imagery": {
      "photo_treatment": "N/A（无照片内容）",
      "illustration_style": "线性图标 + 几何心愿图案",
      "graphic_elements": "进度条、环形图、分类色块",
      "pattern_usage": "none",
      "image_shape": "N/A"
    },

    "interaction_feel": {
      "feedback_style": "即时 + 温柔 — Haptic 轻反馈（扣血），Haptic 强反馈（达成）",
      "hover_behavior": "macOS: 轻微提亮卡片",
      "transition_personality": "snappy for micro (150ms), smooth glide for navigation (300ms), cinematic for celebration (800ms)",
      "loading_style": "骨架屏（shimmer）+ 进度条平滑增长",
      "microinteraction_density": "moderate — 扣血/结算/达成都需要，日常不要太花"
    },

    "brand_voice_in_ui": {
      "tone": "温柔但有边界。不教育用户，不制造焦虑。",
      "formality": "casual-professional — 像朋友在提醒，不是银行在通知",
      "cta_style": "friendly invitation —「记一笔」「设个心愿」「看看结算」",
      "empty_state_approach": "鼓励式 —「还没有预算？花 1 分钟设一个，然后今天就开始。」",
      "error_tone": "不责备 —「同步出了点问题，自动重试中」而非「同步失败」"
    }
  },

  "visual_effects": {
    "overview": {
      "effect_intensity": "subtle-accent",
      "performance_tier": "lightweight",
      "fallback_strategy": "无效果时回退纯色静态 UI",
      "primary_technology": "SwiftUI animation + Haptic"
    },

    "background_effects": {
      "type": "gradient-animation",
      "description": "庆祝时刻背景从深空蓝渐变过渡到暖金色光芒，配合粒子效果",
      "technology": "SwiftUI MeshGradient (iOS 18+)",
      "params": {
        "color_palette": ["#000814", "#0D1B2A", "#FFB300", "#FFD54F"],
        "speed": "slow (3s loop)",
        "density": "sparse",
        "opacity": "0.3",
        "blend_mode": "normal"
      }
    },

    "particle_systems": {
      "enabled": true,
      "type": "confetti",
      "description": "心愿达成时金色粒子从中心绽放，结算高光时少量粒子点缀",
      "technology": "SwiftUI Canvas / TimelineView",
      "params": {
        "count": "60 (达成) / 20 (结算高光)",
        "shape": "circle + star",
        "size_range": "4pt - 12pt",
        "movement_pattern": "outward explosion + gravity fade",
        "color_behavior": "gold gradient (#FFB300 → #FFD54F → transparent)",
        "interaction": "none",
        "spawn_area": "center burst"
      }
    },

    "3d_elements": {
      "enabled": false,
      "type": "none",
      "description": "MVP 不做 3D",
      "technology": "none",
      "params": {
        "renderer": "none",
        "lighting": "none",
        "camera": "none",
        "materials": "none",
        "geometry": "none",
        "post_processing": [],
        "interaction_model": "none"
      }
    },

    "shader_effects": {
      "enabled": false,
      "type": "none",
      "description": "MVP 不做 shader",
      "technology": "none",
      "params": {
        "uniforms": {},
        "vertex_manipulation": "none",
        "fragment_output": "none",
        "noise_type": "none",
        "distortion": "none"
      }
    },

    "scroll_effects": {
      "parallax": { "enabled": false, "layers": "0", "depth_range": "none", "speed_curve": "none" },
      "scroll_triggered_animations": { "enabled": false, "trigger_points": [], "animation_type": "none", "scrub_behavior": "none" },
      "scroll_morphing": { "enabled": false, "description": "none" }
    },

    "text_effects": {
      "type": "counter-animate",
      "description": "金额数字平滑滚动递增递减（扣血时数字向下滚动，结余入账时向上滚动）",
      "technology": "SwiftUI Text + contentTransition(.numericText())",
      "params": {
        "split_strategy": "none",
        "animation_per_unit": "none",
        "stagger": "none",
        "effect_style": "numeric counter scroll"
      }
    },

    "cursor_effects": {
      "enabled": false,
      "type": "none",
      "description": "mobile-first 不做光标效果",
      "params": { "shape": "none", "size": "0", "blend_mode": "normal", "trail": "none", "interaction_zone": "none" }
    },

    "image_effects": {
      "type": "none",
      "description": "不涉及图片处理",
      "technology": "none",
      "params": { "filter_pipeline": "none", "hover_transform": "none", "reveal_animation": "none", "distortion_type": "none" }
    },

    "glassmorphism_neumorphism": {
      "enabled": true,
      "style": "frosted-layers",
      "params": {
        "blur_radius": "20pt",
        "transparency": "0.15",
        "border_treatment": "1pt white 0.1 opacity",
        "shadow_type": "none",
        "light_source_angle": "top"
      }
    },

    "canvas_drawings": {
      "enabled": false,
      "type": "none",
      "description": "none",
      "technology": "none",
      "params": { "draw_method": "none", "animation_loop": "none", "color_scheme": "none", "responsiveness": "none", "interaction": "none" }
    },

    "svg_animations": {
      "enabled": false,
      "type": "none",
      "description": "none",
      "params": { "animation_method": "none", "path_morphing": "none", "stroke_animation": "none", "filter_effects": "none" }
    },

    "composite_notes": "日常界面以深色静态为主+微交互（扣血动效），仅在结算高光和心愿达成时启用粒子+背景渐变。庆祝效果以 SwiftUI Canvas + TimelineView 实现，不引入第三方渲染库。MVP 阶段效果强度控制为「克制日常 + 高光时刻」，避免过度动效干扰预算专注感。"
  }
}
```

---

## 色彩系统速查表

| Token | Hex | 用途 |
|-------|-----|------|
| `bg-canvas` | `#000814` | 主背景 |
| `bg-card` | `#0D1B2A` | 卡片背景 |
| `bg-elevated` | `#1B2838` | 模态背景 |
| `brand-primary` | `#1A73E8` | 主色（按钮、进度条、选中态） |
| `brand-secondary` | `#4FC3F7` | 辅助蓝 |
| `accent-celebration` | `#FFB300` | 庆祝金（心愿、结算高光） |
| `semantic-success` | `#00C853` | 结余正向变化 |
| `semantic-warning` | `#FFB300` | 超支提醒 |
| `semantic-error` | `#FF5252` | 扣血、支出、超支抵扣 |
| `text-primary` | `#E0E1DD` | 主要文字 |
| `text-secondary` | `#778DA9` | 次要文字 |
| `text-muted` | `#415A77` | 辅助信息 |
| `divider` | `#1B2838` | 分割线 |

---

## 关键差异：预算线 vs Copilot Money

| 维度 | Copilot Money | 预算线 |
|------|-------------|--------|
| 核心情感 | 专业、掌控 | 克制、温暖、期待 |
| 品牌色 | 冷蓝 `#1C6CFF` | 暖蓝 `#1A73E8` + 暖金 `#FFB300` |
| 庆祝色 | 无专用庆祝色 | 暖金 `#FFB300` 是核心情感锚点 |
| 动效哲学 | 功能动效 | 克制日常 + 仪式高光双轨 |
| 语义映射 | 红=支出(消极) | 红=扣血(中性体感)，金=心愿(积极) |
| 文案调性 | 中立专业 | 温柔但有边界 |
