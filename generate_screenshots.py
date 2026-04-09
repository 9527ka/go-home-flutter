#!/usr/bin/env python3
"""
生成 App Store 上架所需的营销截图
支持三种尺寸：6.7 英寸、6.5 英寸、5.5 英寸

运行方式: python3 generate_screenshots.py
"""

from PIL import Image, ImageDraw, ImageFont
import os

# App Store 截图尺寸规格
SIZES = {
    "6.7": (1290, 2796),   # iPhone 15 Pro Max / 14 Pro Max
    "6.5": (1284, 2778),   # iPhone 14 Plus / 13 Pro Max
    "5.5": (1242, 2208),   # iPhone 8 Plus
}

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "screenshots")

# 配色方案
COLORS = {
    "bg_gradient_top":    "#FF6B35",   # 温暖橙色
    "bg_gradient_bottom": "#FF8F5E",
    "phone_bg":           "#F8F9FA",   # 模拟手机屏幕背景
    "card_bg":            "#FFFFFF",
    "primary":            "#FF6B35",
    "text_dark":          "#1A1A2E",
    "text_light":         "#FFFFFF",
    "text_gray":          "#8E8E93",
    "status_green":       "#34C759",
    "status_red":         "#FF3B30",
    "status_orange":      "#FF9500",
    "category_elder":     "#FF6B35",
    "category_child":     "#FF3B30",
    "category_pet":       "#34C759",
    "tab_active":         "#FF6B35",
    "tab_inactive":       "#C7C7CC",
    "chat_bubble_self":   "#FF6B35",
    "chat_bubble_other":  "#E8E8ED",
    "divider":            "#E5E5EA",
}

def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def get_font(size):
    """尝试获取中文字体"""
    font_paths = [
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNSText.ttf",
    ]
    for path in font_paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()

def draw_gradient_bg(draw, width, height, color_top, color_bottom):
    """绘制渐变背景"""
    r1, g1, b1 = hex_to_rgb(color_top)
    r2, g2, b2 = hex_to_rgb(color_bottom)
    for y in range(height):
        ratio = y / height
        r = int(r1 + (r2 - r1) * ratio)
        g = int(g1 + (g2 - g1) * ratio)
        b = int(b1 + (b2 - b1) * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))

def draw_rounded_rect(draw, xy, radius, fill):
    """绘制圆角矩形"""
    x1, y1, x2, y2 = xy
    draw.rectangle([x1 + radius, y1, x2 - radius, y2], fill=fill)
    draw.rectangle([x1, y1 + radius, x2, y2 - radius], fill=fill)
    draw.pieslice([x1, y1, x1 + 2*radius, y1 + 2*radius], 180, 270, fill=fill)
    draw.pieslice([x2 - 2*radius, y1, x2, y1 + 2*radius], 270, 360, fill=fill)
    draw.pieslice([x1, y2 - 2*radius, x1 + 2*radius, y2], 90, 180, fill=fill)
    draw.pieslice([x2 - 2*radius, y2 - 2*radius, x2, y2], 0, 90, fill=fill)

def draw_status_bar(draw, x, y, w, scale):
    """绘制状态栏"""
    font = get_font(int(28 * scale))
    draw.text((x + int(30*scale), y + int(12*scale)), "9:41", fill=hex_to_rgb("#000000"), font=font)
    # 电池图标 (简单矩形)
    bw, bh = int(50*scale), int(24*scale)
    bx = x + w - int(80*scale)
    by = y + int(14*scale)
    draw.rectangle([bx, by, bx+bw, by+bh], outline=hex_to_rgb("#000000"), width=2)
    draw.rectangle([bx+3, by+3, bx+bw-3, by+bh-3], fill=hex_to_rgb("#34C759"))

def draw_phone_frame(img, draw, cx, y, phone_w, phone_h, radius, scale):
    """绘制手机外框"""
    x = cx - phone_w // 2
    # 手机外壳阴影
    shadow_offset = int(8 * scale)
    draw_rounded_rect(draw, (x+shadow_offset, y+shadow_offset, x+phone_w+shadow_offset, y+phone_h+shadow_offset), radius, (0,0,0,40))
    # 手机边框
    draw_rounded_rect(draw, (x-int(4*scale), y-int(4*scale), x+phone_w+int(4*scale), y+phone_h+int(4*scale)), radius+int(4*scale), hex_to_rgb("#1A1A2E"))
    # 手机屏幕
    draw_rounded_rect(draw, (x, y, x+phone_w, y+phone_h), radius, hex_to_rgb(COLORS["phone_bg"]))
    return x, y

def draw_post_card(draw, x, y, w, scale, title, category, location, time_str, status, cat_color):
    """绘制一个寻亲启事卡片"""
    h = int(200 * scale)
    # 卡片背景
    draw_rounded_rect(draw, (x, y, x+w, y+h), int(16*scale), hex_to_rgb(COLORS["card_bg"]))

    # 图片占位区域
    img_size = int(140 * scale)
    img_x = x + int(16*scale)
    img_y = y + int(16*scale)
    draw_rounded_rect(draw, (img_x, img_y, img_x+img_size, img_y+img_size), int(12*scale), hex_to_rgb("#E8E8ED"))
    # 人物图标
    icon_font = get_font(int(48*scale))
    draw.text((img_x + int(36*scale), img_y + int(36*scale)), "👤", font=icon_font, fill=hex_to_rgb(COLORS["text_gray"]))

    # 文字区域
    text_x = img_x + img_size + int(16*scale)
    text_w = w - img_size - int(64*scale)

    # 分类标签
    tag_font = get_font(int(22*scale))
    tag_w = int(80*scale)
    tag_h = int(32*scale)
    draw_rounded_rect(draw, (text_x, img_y, text_x+tag_w, img_y+tag_h), int(6*scale), hex_to_rgb(cat_color))
    draw.text((text_x+int(12*scale), img_y+int(4*scale)), category, fill=hex_to_rgb("#FFFFFF"), font=tag_font)

    # 标题
    title_font = get_font(int(30*scale))
    draw.text((text_x, img_y + tag_h + int(12*scale)), title, fill=hex_to_rgb(COLORS["text_dark"]), font=title_font)

    # 位置和时间
    info_font = get_font(int(22*scale))
    draw.text((text_x, img_y + tag_h + int(52*scale)), f"📍 {location}", fill=hex_to_rgb(COLORS["text_gray"]), font=info_font)
    draw.text((text_x, img_y + tag_h + int(80*scale)), f"🕐 {time_str}", fill=hex_to_rgb(COLORS["text_gray"]), font=info_font)

    # 状态
    status_colors = {"寻找中": COLORS["status_red"], "已找到": COLORS["status_green"]}
    sc = status_colors.get(status, COLORS["status_orange"])
    status_font = get_font(int(22*scale))
    draw.text((x+w-int(100*scale), y+h-int(40*scale)), status, fill=hex_to_rgb(sc), font=status_font)

    return h

def draw_bottom_tab(draw, x, y, w, scale, active_index=0):
    """绘制底部导航栏"""
    tab_h = int(80*scale)
    draw.rectangle([x, y, x+w, y+tab_h], fill=hex_to_rgb(COLORS["card_bg"]))
    draw.line([(x, y), (x+w, y)], fill=hex_to_rgb(COLORS["divider"]), width=1)

    tabs = [("🏠", "首页"), ("💬", "聊天"), ("👤", "我的")]
    tab_w = w // len(tabs)
    icon_font = get_font(int(32*scale))
    label_font = get_font(int(20*scale))

    for i, (icon, label) in enumerate(tabs):
        tx = x + i * tab_w + tab_w // 2
        color = hex_to_rgb(COLORS["tab_active"] if i == active_index else COLORS["tab_inactive"])
        draw.text((tx - int(16*scale), y + int(10*scale)), icon, font=icon_font)
        draw.text((tx - int(16*scale), y + int(48*scale)), label, fill=color, font=label_font)


# ========== 截图 1: 首页 - 寻亲启事列表 ==========
def generate_screenshot_1(width, height, size_name):
    img = Image.new("RGBA", (width, height), (255,255,255,255))
    draw = ImageDraw.Draw(img)
    scale = width / 1290

    # 渐变背景
    draw_gradient_bg(draw, width, height, "#FF6B35", "#FF8F5E")

    # 标题文字
    title_font = get_font(int(72*scale))
    subtitle_font = get_font(int(36*scale))

    title = "发布寻亲启事"
    sub = "帮助走失的亲人找到回家的路"
    tw = draw.textlength(title, font=title_font)
    sw = draw.textlength(sub, font=subtitle_font)
    draw.text(((width-tw)//2, int(120*scale)), title, fill=hex_to_rgb("#FFFFFF"), font=title_font)
    draw.text(((width-sw)//2, int(220*scale)), sub, fill=(255,255,255,200), font=subtitle_font)

    # 手机模拟
    phone_w = int(680*scale)
    phone_h = int(1400*scale)
    phone_r = int(48*scale)
    px, py = draw_phone_frame(img, draw, width//2, int(340*scale), phone_w, phone_h, phone_r, scale)

    # 状态栏
    draw_status_bar(draw, px, py, phone_w, scale)

    # 导航栏
    nav_y = py + int(50*scale)
    nav_font = get_font(int(36*scale))
    draw.text((px + int(24*scale), nav_y + int(12*scale)), "回家了么", fill=hex_to_rgb(COLORS["text_dark"]), font=nav_font)
    search_icon = get_font(int(32*scale))
    draw.text((px + phone_w - int(100*scale), nav_y + int(12*scale)), "🔍", font=search_icon)

    # 分类标签
    cat_y = nav_y + int(70*scale)
    cats = ["全部", "亲人", "儿童", "宠物", "物品"]
    cat_font = get_font(int(26*scale))
    cx = px + int(20*scale)
    for i, cat in enumerate(cats):
        cw = int(100*scale)
        ch = int(44*scale)
        if i == 0:
            draw_rounded_rect(draw, (cx, cat_y, cx+cw, cat_y+ch), int(22*scale), hex_to_rgb(COLORS["primary"]))
            draw.text((cx+int(22*scale), cat_y+int(8*scale)), cat, fill=hex_to_rgb("#FFFFFF"), font=cat_font)
        else:
            draw_rounded_rect(draw, (cx, cat_y, cx+cw, cat_y+ch), int(22*scale), hex_to_rgb("#F2F2F7"))
            draw.text((cx+int(22*scale), cat_y+int(8*scale)), cat, fill=hex_to_rgb(COLORS["text_gray"]), font=cat_font)
        cx += cw + int(16*scale)

    # 卡片列表
    card_y = cat_y + int(70*scale)
    card_margin = int(16*scale)
    card_w = phone_w - 2*card_margin
    cards_data = [
        ("李奶奶 · 女 · 78岁", "亲人", "北京市海淀区", "2025-07-10", "寻找中", COLORS["category_elder"]),
        ("小明 · 男 · 6岁", "儿童", "上海市浦东新区", "2025-07-09", "寻找中", COLORS["category_child"]),
        ("豆豆 · 金毛犬", "宠物", "广州市天河区", "2025-07-08", "已找到", COLORS["category_pet"]),
    ]

    for title, cat, loc, time_str, status, color in cards_data:
        ch = draw_post_card(draw, px+card_margin, card_y, card_w, scale, title, cat, loc, time_str, status, color)
        card_y += ch + int(16*scale)

    # 发布按钮
    fab_size = int(100*scale)
    fab_x = px + phone_w - int(100*scale) - fab_size//2
    fab_y = py + phone_h - int(180*scale)
    draw_rounded_rect(draw, (fab_x, fab_y, fab_x+fab_size, fab_y+fab_size), fab_size//2, hex_to_rgb(COLORS["primary"]))
    plus_font = get_font(int(48*scale))
    draw.text((fab_x+int(26*scale), fab_y+int(16*scale)), "＋", fill=hex_to_rgb("#FFFFFF"), font=plus_font)

    # 底部导航
    draw_bottom_tab(draw, px, py+phone_h-int(80*scale), phone_w, scale, active_index=0)

    return img.convert("RGB")


# ========== 截图 2: 启事详情页 ==========
def generate_screenshot_2(width, height, size_name):
    img = Image.new("RGBA", (width, height), (255,255,255,255))
    draw = ImageDraw.Draw(img)
    scale = width / 1290

    draw_gradient_bg(draw, width, height, "#FF8F5E", "#FFB088")

    title_font = get_font(int(72*scale))
    subtitle_font = get_font(int(36*scale))
    title = "详情一目了然"
    sub = "查看走失者详细信息并提供线索"
    tw = draw.textlength(title, font=title_font)
    sw = draw.textlength(sub, font=subtitle_font)
    draw.text(((width-tw)//2, int(120*scale)), title, fill=hex_to_rgb("#FFFFFF"), font=title_font)
    draw.text(((width-sw)//2, int(220*scale)), sub, fill=(255,255,255,200), font=subtitle_font)

    phone_w = int(680*scale)
    phone_h = int(1400*scale)
    phone_r = int(48*scale)
    px, py = draw_phone_frame(img, draw, width//2, int(340*scale), phone_w, phone_h, phone_r, scale)

    draw_status_bar(draw, px, py, phone_w, scale)

    # 返回 + 标题
    nav_y = py + int(50*scale)
    nav_font = get_font(int(36*scale))
    back_font = get_font(int(32*scale))
    draw.text((px+int(16*scale), nav_y+int(12*scale)), "←", fill=hex_to_rgb(COLORS["primary"]), font=back_font)
    draw.text((px+int(60*scale), nav_y+int(12*scale)), "启事详情", fill=hex_to_rgb(COLORS["text_dark"]), font=nav_font)

    # 图片区域
    img_y = nav_y + int(70*scale)
    img_h = int(400*scale)
    draw.rectangle([px, img_y, px+phone_w, img_y+img_h], fill=hex_to_rgb("#E8E8ED"))
    placeholder_font = get_font(int(80*scale))
    draw.text((px+phone_w//2-int(60*scale), img_y+int(140*scale)), "🧓", font=placeholder_font)
    # 图片指示器
    dot_y = img_y + img_h - int(30*scale)
    for i in range(3):
        dx = px + phone_w//2 - int(30*scale) + i*int(30*scale)
        r = int(8*scale) if i == 0 else int(6*scale)
        c = hex_to_rgb(COLORS["primary"]) if i == 0 else hex_to_rgb("#C7C7CC")
        draw.ellipse([dx-r, dot_y-r, dx+r, dot_y+r], fill=c)

    # 信息区域
    info_y = img_y + img_h + int(20*scale)
    info_x = px + int(24*scale)
    info_w = phone_w - int(48*scale)

    # 状态标签
    tag_font = get_font(int(24*scale))
    tag_w = int(100*scale)
    tag_h = int(36*scale)
    draw_rounded_rect(draw, (info_x, info_y, info_x+tag_w, info_y+tag_h), int(6*scale), hex_to_rgb(COLORS["status_red"]))
    draw.text((info_x+int(16*scale), info_y+int(5*scale)), "寻找中", fill=hex_to_rgb("#FFFFFF"), font=tag_font)

    # 姓名
    name_font = get_font(int(42*scale))
    draw.text((info_x, info_y+int(50*scale)), "李奶奶", fill=hex_to_rgb(COLORS["text_dark"]), font=name_font)

    # 基本信息
    detail_font = get_font(int(26*scale))
    details = [
        ("性别", "女"),
        ("年龄", "78 岁"),
        ("身高", "约 155cm"),
        ("外貌特征", "白发、走路缓慢、穿蓝色外套"),
    ]
    dy = info_y + int(110*scale)
    for label, value in details:
        draw.text((info_x, dy), f"{label}:", fill=hex_to_rgb(COLORS["text_gray"]), font=detail_font)
        draw.text((info_x+int(140*scale), dy), value, fill=hex_to_rgb(COLORS["text_dark"]), font=detail_font)
        dy += int(44*scale)

    # 走失信息
    draw.line([(info_x, dy+int(10*scale)), (info_x+info_w, dy+int(10*scale))], fill=hex_to_rgb(COLORS["divider"]), width=1)
    dy += int(30*scale)
    section_font = get_font(int(30*scale))
    draw.text((info_x, dy), "📍 走失信息", fill=hex_to_rgb(COLORS["text_dark"]), font=section_font)
    dy += int(48*scale)
    draw.text((info_x, dy), "地点: 北京市海淀区中关村大街", fill=hex_to_rgb(COLORS["text_gray"]), font=detail_font)
    dy += int(40*scale)
    draw.text((info_x, dy), "时间: 2025-07-10 14:30", fill=hex_to_rgb(COLORS["text_gray"]), font=detail_font)

    # 底部按钮
    btn_y = py + phone_h - int(130*scale)
    btn_h = int(56*scale)
    btn_margin = int(24*scale)
    half_w = (phone_w - 3*btn_margin) // 2

    # 拨打电话
    draw_rounded_rect(draw, (px+btn_margin, btn_y, px+btn_margin+half_w, btn_y+btn_h), int(28*scale), hex_to_rgb("#34C759"))
    btn_font = get_font(int(28*scale))
    draw.text((px+btn_margin+int(40*scale), btn_y+int(12*scale)), "📞 拨打电话", fill=hex_to_rgb("#FFFFFF"), font=btn_font)

    # 提供线索
    draw_rounded_rect(draw, (px+2*btn_margin+half_w, btn_y, px+2*btn_margin+2*half_w, btn_y+btn_h), int(28*scale), hex_to_rgb(COLORS["primary"]))
    draw.text((px+2*btn_margin+half_w+int(40*scale), btn_y+int(12*scale)), "💡 提供线索", fill=hex_to_rgb("#FFFFFF"), font=btn_font)

    return img.convert("RGB")


# ========== 截图 3: 发布启事页面 ==========
def generate_screenshot_3(width, height, size_name):
    img = Image.new("RGBA", (width, height), (255,255,255,255))
    draw = ImageDraw.Draw(img)
    scale = width / 1290

    draw_gradient_bg(draw, width, height, "#34C759", "#5BD67B")

    title_font = get_font(int(72*scale))
    subtitle_font = get_font(int(36*scale))
    title = "一键发布启事"
    sub = "简单填写信息，让更多人帮助寻找"
    tw = draw.textlength(title, font=title_font)
    sw = draw.textlength(sub, font=subtitle_font)
    draw.text(((width-tw)//2, int(120*scale)), title, fill=hex_to_rgb("#FFFFFF"), font=title_font)
    draw.text(((width-sw)//2, int(220*scale)), sub, fill=(255,255,255,200), font=subtitle_font)

    phone_w = int(680*scale)
    phone_h = int(1400*scale)
    phone_r = int(48*scale)
    px, py = draw_phone_frame(img, draw, width//2, int(340*scale), phone_w, phone_h, phone_r, scale)

    draw_status_bar(draw, px, py, phone_w, scale)

    nav_y = py + int(50*scale)
    nav_font = get_font(int(36*scale))
    back_font = get_font(int(32*scale))
    draw.text((px+int(16*scale), nav_y+int(12*scale)), "←", fill=hex_to_rgb(COLORS["primary"]), font=back_font)
    draw.text((px+int(60*scale), nav_y+int(12*scale)), "发布启事", fill=hex_to_rgb(COLORS["text_dark"]), font=nav_font)

    # 分类选择
    form_y = nav_y + int(80*scale)
    form_x = px + int(24*scale)
    form_w = phone_w - int(48*scale)
    label_font = get_font(int(28*scale))
    value_font = get_font(int(26*scale))

    draw.text((form_x, form_y), "选择分类", fill=hex_to_rgb(COLORS["text_dark"]), font=label_font)
    form_y += int(44*scale)

    cats = [("🧓 亲人", True), ("👶 儿童", False), ("🐕 宠物", False), ("📦 物品", False)]
    cx = form_x
    for cat_text, active in cats:
        cw = int(130*scale)
        ch = int(50*scale)
        bg = hex_to_rgb(COLORS["primary"]) if active else hex_to_rgb("#F2F2F7")
        tc = hex_to_rgb("#FFFFFF") if active else hex_to_rgb(COLORS["text_gray"])
        draw_rounded_rect(draw, (cx, form_y, cx+cw, form_y+ch), int(12*scale), bg)
        draw.text((cx+int(16*scale), form_y+int(10*scale)), cat_text, fill=tc, font=value_font)
        cx += cw + int(12*scale)

    # 表单字段
    form_y += int(80*scale)
    fields = [
        ("基本信息", [("姓名", "李奶奶"), ("性别", "女"), ("年龄", "78")]),
        ("走失信息", [("走失城市", "北京市"), ("走失地点", "海淀区中关村大街"), ("走失时间", "2025-07-10 14:30")]),
        ("联系方式", [("联系人", "李先生"), ("联系电话", "138****1234")]),
    ]

    for section_title, section_fields in fields:
        section_font = get_font(int(30*scale))
        draw.text((form_x, form_y), section_title, fill=hex_to_rgb(COLORS["text_dark"]), font=section_font)
        form_y += int(48*scale)

        for fname, fval in section_fields:
            # 字段背景
            field_h = int(52*scale)
            draw_rounded_rect(draw, (form_x, form_y, form_x+form_w, form_y+field_h), int(10*scale), hex_to_rgb("#F8F9FA"))
            draw.text((form_x+int(16*scale), form_y+int(12*scale)), fname, fill=hex_to_rgb(COLORS["text_gray"]), font=value_font)
            draw.text((form_x+int(160*scale), form_y+int(12*scale)), fval, fill=hex_to_rgb(COLORS["text_dark"]), font=value_font)
            form_y += field_h + int(12*scale)

        form_y += int(16*scale)

    # 上传照片区域
    draw.text((form_x, form_y), "上传照片", fill=hex_to_rgb(COLORS["text_dark"]), font=label_font)
    form_y += int(44*scale)
    photo_size = int(100*scale)
    for i in range(3):
        phx = form_x + i * (photo_size + int(12*scale))
        if i < 2:
            draw_rounded_rect(draw, (phx, form_y, phx+photo_size, form_y+photo_size), int(10*scale), hex_to_rgb("#E8E8ED"))
            draw.text((phx+int(30*scale), form_y+int(24*scale)), "🖼️", font=get_font(int(36*scale)))
        else:
            draw_rounded_rect(draw, (phx, form_y, phx+photo_size, form_y+photo_size), int(10*scale), hex_to_rgb("#F2F2F7"))
            plus = get_font(int(40*scale))
            draw.text((phx+int(30*scale), form_y+int(22*scale)), "＋", fill=hex_to_rgb(COLORS["text_gray"]), font=plus)

    return img.convert("RGB")


# ========== 截图 4: 聊天室 ==========
def generate_screenshot_4(width, height, size_name):
    img = Image.new("RGBA", (width, height), (255,255,255,255))
    draw = ImageDraw.Draw(img)
    scale = width / 1290

    draw_gradient_bg(draw, width, height, "#007AFF", "#5AC8FA")

    title_font = get_font(int(72*scale))
    subtitle_font = get_font(int(36*scale))
    title = "实时聊天协作"
    sub = "志愿者在线沟通，共同寻找走失者"
    tw = draw.textlength(title, font=title_font)
    sw = draw.textlength(sub, font=subtitle_font)
    draw.text(((width-tw)//2, int(120*scale)), title, fill=hex_to_rgb("#FFFFFF"), font=title_font)
    draw.text(((width-sw)//2, int(220*scale)), sub, fill=(255,255,255,200), font=subtitle_font)

    phone_w = int(680*scale)
    phone_h = int(1400*scale)
    phone_r = int(48*scale)
    px, py = draw_phone_frame(img, draw, width//2, int(340*scale), phone_w, phone_h, phone_r, scale)

    draw_status_bar(draw, px, py, phone_w, scale)

    nav_y = py + int(50*scale)
    nav_font = get_font(int(36*scale))
    draw.text((px+int(16*scale), nav_y+int(12*scale)), "←", fill=hex_to_rgb(COLORS["primary"]), font=get_font(int(32*scale)))
    draw.text((px+int(60*scale), nav_y+int(12*scale)), "公共聊天室", fill=hex_to_rgb(COLORS["text_dark"]), font=nav_font)
    online_font = get_font(int(22*scale))
    draw.text((px+phone_w-int(130*scale), nav_y+int(16*scale)), "🟢 28人在线", fill=hex_to_rgb(COLORS["text_gray"]), font=online_font)

    # 聊天消息
    chat_y = nav_y + int(80*scale)
    msg_font = get_font(int(26*scale))
    name_font = get_font(int(22*scale))
    time_font = get_font(int(18*scale))

    messages = [
        ("other", "志愿者小王", "大家好！我在海淀区中关村附近看到一位走失亲人，穿蓝色外套", "14:32"),
        ("self", "我", "是不是白头发的奶奶？我刚看到那条启事", "14:33"),
        ("other", "热心市民", "我在附近，可以去确认一下", "14:34"),
        ("other", "志愿者小王", "好的！她现在在中关村地铁站 B 口附近", "14:35"),
        ("self", "我", "太好了！我已经联系了发布者的家人", "14:36"),
        ("other", "热心市民", "🎉 找到了！亲人家属已经赶到", "14:40"),
    ]

    for msg_type, name, text, time_str in messages:
        bubble_margin = int(16*scale)
        bubble_max_w = int(420*scale)
        bubble_h = int(80*scale)
        bubble_padding = int(14*scale)

        if msg_type == "other":
            bx = px + bubble_margin
            # 头像
            avatar_size = int(40*scale)
            draw_rounded_rect(draw, (bx, chat_y, bx+avatar_size, chat_y+avatar_size), avatar_size//2, hex_to_rgb("#E8E8ED"))
            # 名字
            draw.text((bx+avatar_size+int(8*scale), chat_y), name, fill=hex_to_rgb(COLORS["text_gray"]), font=name_font)
            # 气泡
            by = chat_y + int(28*scale)
            text_w = min(draw.textlength(text, font=msg_font) + 2*bubble_padding, bubble_max_w)
            draw_rounded_rect(draw, (bx+avatar_size+int(8*scale), by, bx+avatar_size+int(8*scale)+int(text_w), by+bubble_h), int(16*scale), hex_to_rgb(COLORS["chat_bubble_other"]))
            draw.text((bx+avatar_size+int(8*scale)+bubble_padding, by+bubble_padding), text[:18], fill=hex_to_rgb(COLORS["text_dark"]), font=msg_font)
            if len(text) > 18:
                draw.text((bx+avatar_size+int(8*scale)+bubble_padding, by+bubble_padding+int(34*scale)), text[18:36], fill=hex_to_rgb(COLORS["text_dark"]), font=msg_font)
            # 时间
            draw.text((bx+avatar_size+int(8*scale)+int(text_w)+int(8*scale), by+int(28*scale)), time_str, fill=hex_to_rgb(COLORS["text_gray"]), font=time_font)
        else:
            text_w = min(draw.textlength(text, font=msg_font) + 2*bubble_padding, bubble_max_w)
            bx = px + phone_w - bubble_margin - int(text_w)
            by = chat_y + int(28*scale)
            draw_rounded_rect(draw, (bx, by, bx+int(text_w), by+bubble_h), int(16*scale), hex_to_rgb(COLORS["chat_bubble_self"]))
            draw.text((bx+bubble_padding, by+bubble_padding), text[:18], fill=hex_to_rgb("#FFFFFF"), font=msg_font)
            if len(text) > 18:
                draw.text((bx+bubble_padding, by+bubble_padding+int(34*scale)), text[18:36], fill=hex_to_rgb("#FFFFFF"), font=msg_font)
            draw.text((bx-int(50*scale), by+int(28*scale)), time_str, fill=hex_to_rgb(COLORS["text_gray"]), font=time_font)

        chat_y += bubble_h + int(40*scale)

    # 输入框
    input_y = py + phone_h - int(130*scale)
    input_h = int(52*scale)
    input_x = px + int(16*scale)
    input_w = phone_w - int(130*scale)
    draw_rounded_rect(draw, (input_x, input_y, input_x+input_w, input_y+input_h), int(26*scale), hex_to_rgb("#F2F2F7"))
    draw.text((input_x+int(20*scale), input_y+int(12*scale)), "输入消息...", fill=hex_to_rgb(COLORS["text_gray"]), font=msg_font)
    # 发送按钮
    send_size = int(52*scale)
    send_x = input_x + input_w + int(12*scale)
    draw_rounded_rect(draw, (send_x, input_y, send_x+send_size, input_y+send_size), send_size//2, hex_to_rgb(COLORS["primary"]))
    draw.text((send_x+int(12*scale), input_y+int(8*scale)), "↑", fill=hex_to_rgb("#FFFFFF"), font=get_font(int(30*scale)))

    # 底部导航
    draw_bottom_tab(draw, px, py+phone_h-int(80*scale), phone_w, scale, active_index=1)

    return img.convert("RGB")


# ========== 截图 5: 个人中心 ==========
def generate_screenshot_5(width, height, size_name):
    img = Image.new("RGBA", (width, height), (255,255,255,255))
    draw = ImageDraw.Draw(img)
    scale = width / 1290

    draw_gradient_bg(draw, width, height, "#5856D6", "#AF52DE")

    title_font = get_font(int(72*scale))
    subtitle_font = get_font(int(36*scale))
    title = "管理你的发布"
    sub = "查看启事、收藏线索、收到通知"
    tw = draw.textlength(title, font=title_font)
    sw = draw.textlength(sub, font=subtitle_font)
    draw.text(((width-tw)//2, int(120*scale)), title, fill=hex_to_rgb("#FFFFFF"), font=title_font)
    draw.text(((width-sw)//2, int(220*scale)), sub, fill=(255,255,255,200), font=subtitle_font)

    phone_w = int(680*scale)
    phone_h = int(1400*scale)
    phone_r = int(48*scale)
    px, py = draw_phone_frame(img, draw, width//2, int(340*scale), phone_w, phone_h, phone_r, scale)

    draw_status_bar(draw, px, py, phone_w, scale)

    # 个人中心标题
    nav_y = py + int(50*scale)
    nav_font = get_font(int(36*scale))
    draw.text((px+int(24*scale), nav_y+int(12*scale)), "个人中心", fill=hex_to_rgb(COLORS["text_dark"]), font=nav_font)

    # 头像和用户信息区
    profile_y = nav_y + int(80*scale)
    avatar_size = int(120*scale)
    avatar_x = px + phone_w//2 - avatar_size//2
    draw_rounded_rect(draw, (avatar_x, profile_y, avatar_x+avatar_size, profile_y+avatar_size), avatar_size//2, hex_to_rgb(COLORS["primary"]))
    avatar_font = get_font(int(60*scale))
    draw.text((avatar_x+int(28*scale), profile_y+int(22*scale)), "🧑", font=avatar_font)

    name_font = get_font(int(34*scale))
    user_name = "爱心志愿者"
    nw = draw.textlength(user_name, font=name_font)
    draw.text(((px+phone_w//2-int(nw)//2), profile_y+avatar_size+int(16*scale)), user_name, fill=hex_to_rgb(COLORS["text_dark"]), font=name_font)

    phone_font = get_font(int(24*scale))
    phone_text = "138****1234"
    pw = draw.textlength(phone_text, font=phone_font)
    draw.text(((px+phone_w//2-int(pw)//2), profile_y+avatar_size+int(58*scale)), phone_text, fill=hex_to_rgb(COLORS["text_gray"]), font=phone_font)

    # 统计数据
    stats_y = profile_y + avatar_size + int(100*scale)
    stats = [("3", "我的发布"), ("12", "我的收藏"), ("5", "新消息")]
    stat_w = phone_w // 3
    stat_num_font = get_font(int(40*scale))
    stat_label_font = get_font(int(22*scale))

    for i, (num, label) in enumerate(stats):
        sx = px + i * stat_w + stat_w // 2
        draw.text((sx-int(12*scale), stats_y), num, fill=hex_to_rgb(COLORS["primary"]), font=stat_num_font)
        lw = draw.textlength(label, font=stat_label_font)
        draw.text((sx-int(lw)//2, stats_y+int(50*scale)), label, fill=hex_to_rgb(COLORS["text_gray"]), font=stat_label_font)

    # 分割线
    div_y = stats_y + int(90*scale)
    draw.line([(px+int(24*scale), div_y), (px+phone_w-int(24*scale), div_y)], fill=hex_to_rgb(COLORS["divider"]), width=1)

    # 菜单列表
    menu_y = div_y + int(16*scale)
    menu_font = get_font(int(28*scale))
    menus = [
        ("📋", "我的启事"),
        ("⭐", "我的收藏"),
        ("🔔", "消息通知"),
        ("🌐", "语言设置"),
        ("💬", "意见反馈"),
        ("ℹ️", "关于我们"),
    ]

    for icon, text in menus:
        item_h = int(64*scale)
        draw.text((px+int(32*scale), menu_y+int(16*scale)), icon, font=get_font(int(28*scale)))
        draw.text((px+int(80*scale), menu_y+int(16*scale)), text, fill=hex_to_rgb(COLORS["text_dark"]), font=menu_font)
        # 箭头
        draw.text((px+phone_w-int(48*scale), menu_y+int(16*scale)), "›", fill=hex_to_rgb(COLORS["text_gray"]), font=menu_font)
        menu_y += item_h
        draw.line([(px+int(80*scale), menu_y), (px+phone_w-int(24*scale), menu_y)], fill=hex_to_rgb(COLORS["divider"]), width=1)

    # 底部导航
    draw_bottom_tab(draw, px, py+phone_h-int(80*scale), phone_w, scale, active_index=2)

    return img.convert("RGB")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    generators = [
        ("01_home_list", generate_screenshot_1),
        ("02_post_detail", generate_screenshot_2),
        ("03_post_create", generate_screenshot_3),
        ("04_chat_room", generate_screenshot_4),
        ("05_profile", generate_screenshot_5),
    ]

    for size_name, (w, h) in SIZES.items():
        size_dir = os.path.join(OUTPUT_DIR, f"{size_name}_inch")
        os.makedirs(size_dir, exist_ok=True)

        for filename, generator in generators:
            print(f"生成 {size_name}英寸 - {filename}...")
            img = generator(w, h, size_name)
            output_path = os.path.join(size_dir, f"{filename}.png")
            img.save(output_path, "PNG", quality=95)
            print(f"  ✓ {output_path}")

    print(f"\n✅ 所有截图已生成到: {OUTPUT_DIR}")
    print(f"  共生成 {len(SIZES)} 种尺寸 × {len(generators)} 张 = {len(SIZES) * len(generators)} 张截图")


if __name__ == "__main__":
    main()
