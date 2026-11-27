# -*- coding: utf-8 -*-
"""
Hồ sơ gửi khách — Face AIoT + Nhà thông minh AI Xiaozhi
theo phụ lục CV 7292/BGDĐT-GDPT và mẫu báo cáo STEM trong docs/.
"""
from __future__ import annotations

import shutil
from pathlib import Path

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Image as RLImage
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

ROOT = Path(r"D:\duongpv\face_alot")
DOCS = ROOT / "docs"
IMG_SRC = DOCS / "images"
PL_BASE = (
    ROOT
    / "PHU LUC CAP NHAT CỦA BO GDDT THEO CV7292 (2)"
    / "PHU LUC CAP NHAT CỦA BO GDDT THEO CV7292"
)
OUT = ROOT / "HO_SO_GUI_KHACH_FaceAIoT_Xiaozhi"
IMG_OUT = OUT / "anh_minh_hoa"

# Tên đúng theo Quyết định cử SP dự thi KHKT/STEM cấp tỉnh (THPT A Nguyễn Khuyến)
TEN_DU_AN = (
    "Nhà thông minh tích hợp nhận diện khuôn mặt và "
    "điều khiển IoT qua ứng dụng di động (Face AIoT)"
)
TEN_NGAN = "Nhà thông minh Face AIoT"
LINH_VUC = "Hệ thống nhúng và Phần mềm hệ thống / Khoa học máy tính – IoT – Trí tuệ nhân tạo"
LOAI = "Dự án kỹ thuật (STEM)"
NAVY = RGBColor(0x1F, 0x4E, 0x79)


# ── helpers ─────────────────────────────────────────────────────────
def set_run_font(run, name="Times New Roman", size=13, bold=False, italic=False, color=None):
    run.font.name = name
    run._element.rPr.rFonts.set(qn("w:eastAsia"), name)
    run.font.size = Pt(size)
    run.bold = bold
    run.italic = italic
    if color is not None:
        run.font.color.rgb = color


def setup_doc(doc: Document):
    sec = doc.sections[0]
    sec.page_width = Cm(21.0)
    sec.page_height = Cm(29.7)
    sec.left_margin = Cm(3.0)
    sec.right_margin = Cm(2.0)
    sec.top_margin = Cm(2.0)
    sec.bottom_margin = Cm(2.0)
    normal = doc.styles["Normal"]
    normal.font.name = "Times New Roman"
    normal.font.size = Pt(13)


def add_p(
    doc,
    text="",
    *,
    size=13,
    bold=False,
    italic=False,
    align="justify",
    space_before=0,
    space_after=3,
    first_line=True,
    color=None,
):
    p = doc.add_paragraph()
    p.alignment = {
        "center": WD_ALIGN_PARAGRAPH.CENTER,
        "right": WD_ALIGN_PARAGRAPH.RIGHT,
        "left": WD_ALIGN_PARAGRAPH.LEFT,
    }.get(align, WD_ALIGN_PARAGRAPH.JUSTIFY)
    pf = p.paragraph_format
    pf.space_before = Pt(space_before)
    pf.space_after = Pt(space_after)
    pf.line_spacing_rule = WD_LINE_SPACING.SINGLE
    pf.first_line_indent = Cm(1.0) if (first_line and align == "justify" and text) else Cm(0)
    if text:
        run = p.add_run(text)
        set_run_font(run, size=size, bold=bold, italic=italic, color=color)
    return p


def add_h(doc, text, *, size=13, color=NAVY):
    return add_p(
        doc,
        text,
        bold=True,
        align="left",
        first_line=False,
        space_before=8,
        space_after=3,
        size=size,
        color=color,
    )


def add_bullet(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    pf = p.paragraph_format
    pf.space_before = Pt(0)
    pf.space_after = Pt(2)
    pf.line_spacing_rule = WD_LINE_SPACING.SINGLE
    pf.left_indent = Cm(0.75)
    pf.first_line_indent = Cm(0)
    run = p.add_run("• " + text)
    set_run_font(run, size=13)
    return p


def shade_cell(cell, fill="1F4E79"):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), fill)
    tcPr.append(shd)


def set_cell(cell, text, *, bold=False, size=11, center=False, header=False):
    cell.text = ""
    p = cell.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER if center or header else WD_ALIGN_PARAGRAPH.LEFT
    run = p.add_run(str(text))
    set_run_font(
        run,
        size=size,
        bold=bold or header,
        color=RGBColor(0xFF, 0xFF, 0xFF) if header else None,
    )
    if header:
        shade_cell(cell, "1F4E79")


def add_table(doc, headers, rows, col_widths=None):
    table = doc.add_table(rows=1 + len(rows), cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, h in enumerate(headers):
        set_cell(table.rows[0].cells[i], h, header=True, size=11, center=True)
    for r_i, row in enumerate(rows):
        for c_i, val in enumerate(row):
            set_cell(table.rows[r_i + 1].cells[c_i], val, size=11)
            if r_i % 2 == 1:
                shade_cell(table.rows[r_i + 1].cells[c_i], "F2F2F2")
    if col_widths:
        for row in table.rows:
            for i, w in enumerate(col_widths):
                row.cells[i].width = Cm(w)
    doc.add_paragraph()
    return table


def add_image(doc, path: Path | None, width_cm=13.5, caption: str | None = None):
    if path is None or not path.exists():
        add_p(doc, "[Thiếu ảnh minh họa — bổ sung trước khi nộp]", align="center", first_line=False, italic=True)
        return
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.first_line_indent = Cm(0)
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(2)
    p.add_run().add_picture(str(path), width=Cm(width_cm))
    if caption:
        add_p(doc, caption, size=11, italic=True, align="center", first_line=False, space_after=6)


def prepare_images() -> dict[str, Path]:
    IMG_OUT.mkdir(parents=True, exist_ok=True)
    mapping = {
        "mo_hinh_thuc_te.png": IMG_SRC / "mo_hinh_thuc_te.png",
        "ui_dieu_khien_nha.png": IMG_SRC / "ui_dieu_khien_nha.png",
        "ui_dang_ky_mat.png": IMG_SRC / "ui_dang_ky_mat.png",
        "ui_mo_cua.png": IMG_SRC / "ui_mo_cua.png",
    }
    local = {}
    for name, src in mapping.items():
        if src.exists():
            dst = IMG_OUT / name
            shutil.copy2(src, dst)
            local[name] = dst
    return local


# ── 01 PL IA/B Đăng ký ─────────────────────────────────────────────
def build_pl1():
    doc = Document()
    setup_doc(doc)
    add_p(doc, "PHỤ LỤC IA — HỒ SƠ DỰ THI CẤP TỈNH", align="center", bold=True, first_line=False, size=14)
    add_p(
        doc,
        "(Kèm theo Kế hoạch số: ………/KH-SGDĐT ngày … tháng … năm 2026 của Sở Giáo dục và Đào tạo)",
        align="center",
        italic=True,
        size=11,
        first_line=False,
        space_after=8,
    )
    add_p(doc, "ĐƠN VỊ DỰ THI: ……………………………", bold=True, first_line=False)
    add_p(doc, "CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM", align="center", bold=True, first_line=False, space_after=0)
    add_p(doc, "Độc lập – Tự do – Hạnh phúc", align="center", bold=True, italic=True, first_line=False, space_after=0)
    add_p(doc, "………………, ngày …… tháng …… năm 2026", align="right", first_line=False, space_after=8)

    add_p(doc, "BẢN ĐĂNG KÝ DỰ THI", align="center", bold=True, size=14, first_line=False)
    add_p(
        doc,
        "Cuộc thi khoa học, kỹ thuật cấp tỉnh dành cho học sinh trung học năm học 2026–2027",
        align="center",
        italic=True,
        first_line=False,
        space_after=6,
    )
    add_p(doc, "Kính gửi: Sở Giáo dục và Đào tạo (Phòng Giáo dục Trung học)", first_line=False, space_after=6)
    add_p(doc, f"Tên dự án dự thi: {TEN_DU_AN}", first_line=False)
    add_p(doc, f"Lĩnh vực dự thi: {LINH_VUC}", first_line=False)
    add_p(doc, f"Loại dự án: {LOAI} (cá nhân / tập thể — đơn vị xác nhận)", first_line=False, space_after=6)

    add_table(
        doc,
        [
            "TT",
            "Tên dự án",
            "Lĩnh vực",
            "Họ và tên HS",
            "Ngày sinh",
            "Dân tộc",
            "Lớp",
            "Trường",
            "KQ học tập\n2025–2026",
            "KQ rèn luyện\n2025–2026",
            "Họ tên GVHD",
            "Đơn vị GVHD",
        ],
        [
            [
                "1",
                TEN_NGAN,
                "Hệ thống nhúng /\nCNTT–AI",
                "………………",
                "…/…/…",
                "……",
                "……",
                "………………",
                "……",
                "……",
                "………………",
                "………………",
            ],
            [
                "2",
                "(thành viên nếu có)",
                "",
                "………………",
                "…/…/…",
                "……",
                "……",
                "………………",
                "……",
                "……",
                "",
                "",
            ],
        ],
    )
    add_p(doc, "Thủ trưởng đơn vị dự thi", align="center", bold=True, first_line=False, space_before=12)
    add_p(doc, "(Ký tên, đóng dấu)", align="center", italic=True, first_line=False, space_after=16)

    add_p(doc, "PHỤ LỤC IB — BẢN ĐĂNG KÝ DỰ THI DỰ ÁN STEM", align="center", bold=True, size=14, first_line=False, space_before=8)
    add_p(doc, "Kính gửi: Sở Giáo dục và Đào tạo (Phòng Giáo dục Trung học)", first_line=False, space_after=6)
    add_p(doc, f"Tên dự án STEM: {TEN_DU_AN}", first_line=False)
    add_p(doc, f"Lĩnh vực tham gia: {LINH_VUC}", first_line=False)
    add_table(
        doc,
        ["TT", "Tên dự án", "Lĩnh vực", "Họ tên HS", "Ngày sinh", "Dân tộc", "Lớp", "Trường", "Họ tên GVHD", "Đơn vị"],
        [
            ["1", TEN_NGAN, "STEM – IoT/AI", "………………", "…/…/…", "……", "……", "………………", "………………", "………………"],
        ],
    )
    add_p(doc, "Thủ trưởng đơn vị dự thi", align="center", bold=True, first_line=False, space_before=12)
    add_p(doc, "(Ký tên, đóng dấu)", align="center", italic=True, first_line=False)
    add_p(
        doc,
        "Ghi chú: Họ tên HS, ngày sinh, lớp, trường, kết quả học tập/rèn luyện và GVHD do nhà trường điền trước khi nộp.",
        italic=True,
        size=11,
        first_line=False,
        space_before=8,
    )

    out = OUT / "01_PL_IA_B_Dang_ky_du_thi.docx"
    doc.save(str(out))
    print("Saved", out)


# ── 02 PL II Thuyết minh đơn vị ────────────────────────────────────
def build_pl2():
    doc = Document()
    setup_doc(doc)
    add_p(doc, "PHỤ LỤC II", align="center", bold=True, size=14, first_line=False)
    add_p(doc, "THUYẾT MINH", align="center", bold=True, size=14, first_line=False)
    add_p(
        doc,
        "VỀ VIỆC ĐĂNG KÝ, PHÊ DUYỆT VÀ LỰA CHỌN DỰ ÁN KHKT DỰ THI TẠI ĐƠN VỊ",
        align="center",
        bold=True,
        first_line=False,
    )
    add_p(
        doc,
        "(Phiếu này bắt buộc phải được trưng bày cùng với dự án)",
        align="center",
        italic=True,
        size=11,
        first_line=False,
        space_after=8,
    )

    add_h(doc, "1. Thông tin về hoạt động lựa chọn dự án tại đơn vị")
    add_bullet(
        doc,
        "Số lượng và tỷ lệ cơ sở giáo dục có dự án tham gia đánh giá, lựa chọn tham dự Cuộc thi ở địa phương "
        "(đối với đơn vị dự thi xã/phường cấp THCS): …… trường / …… trường (……%).",
    )
    add_bullet(
        doc,
        "Tổng số dự án tại đơn vị: ……; tổng số học sinh: ……; số GV/NV hướng dẫn: …… "
        "(điền theo số liệu thực tế của trường/Sở).",
    )
    add_bullet(
        doc,
        "Tổng số dự án cấp THPT tham gia đánh giá, lựa chọn dự thi cấp tỉnh: …… "
        "(hoặc thuyết minh phương án đánh giá nếu đơn vị không tổ chức cuộc thi riêng).",
    )

    add_h(doc, "2. Thuyết minh liên quan dự án Face AIoT – Xiaozhi (điền bổ sung bởi đơn vị)")
    add_p(
        doc,
        "Dự án được nhà trường/đơn vị phê duyệt và lựa chọn dự thi cấp tỉnh theo quy trình nội bộ. "
        "Nội dung kỹ thuật thuộc lĩnh vực STEM – hệ thống nhúng, IoT và AI ứng dụng: mô hình nhà thông minh "
        "kết hợp nhận diện khuôn mặt trên ứng dụng Face AIoT và điều khiển bằng giọng nói tiếng Việt qua "
        "trợ lý AI Xiaozhi (ESP32-S3), kết nối MQTT tới các node chấp hành đèn, quạt, cửa, cảm biến.",
        first_line=True,
    )
    add_p(
        doc,
        "Đơn vị xác nhận học sinh đã được hướng dẫn về an toàn điện khi thao tác rơ-le 220 V, "
        "quyền riêng tư khi đăng ký khuôn mặt (có Phiếu IVd), và kê khai sử dụng công nghệ số/AI (Phụ lục khai báo).",
        first_line=True,
    )

    add_p(doc, "…………, ngày …… tháng …… năm 2026", align="right", first_line=False, space_before=12)
    add_p(doc, "Thủ trưởng đơn vị dự thi", align="right", bold=True, first_line=False)
    add_p(doc, "(Ký, ghi rõ họ tên và đóng dấu)", align="right", italic=True, first_line=False)

    out = OUT / "02_PL_II_Thuyet_minh_don_vi.docx"
    doc.save(str(out))
    print("Saved", out)


# ── 03 PL3 Báo cáo kết quả kỹ thuật ────────────────────────────────
def build_pl3(local: dict[str, Path]):
    doc = Document()
    setup_doc(doc)

    for _ in range(2):
        add_p(doc, "", first_line=False, space_after=0)
    add_p(doc, "CUỘC THI NGHIÊN CỨU KHOA HỌC, KỸ THUẬT", align="center", bold=True, first_line=False)
    add_p(doc, "DÀNH CHO HỌC SINH TRUNG HỌC — NĂM HỌC 2026–2027", align="center", bold=True, first_line=False, space_after=8)
    add_p(doc, "─────────────── ✦ ───────────────", align="center", first_line=False, space_after=10)
    add_p(doc, "PHỤ LỤC III / BÁO CÁO KẾT QUẢ THỰC HIỆN DỰ ÁN", align="center", bold=True, size=14, first_line=False)
    add_p(doc, "(Dự án kỹ thuật)", align="center", italic=True, first_line=False, space_after=12)
    add_p(doc, "Tên dự án:", align="center", first_line=False, space_after=2)
    add_p(doc, TEN_DU_AN, align="center", bold=True, first_line=False, space_after=10)
    add_p(doc, f"Lĩnh vực dự thi: {LINH_VUC}", align="center", first_line=False, space_after=16)
    add_p(
        doc,
        "Quy định trình bày theo CV 7292/BGDĐT-GDPT: không ghi tên cơ sở giáo dục, đơn vị dự thi, "
        "tên học sinh; không logo/QR/link; không quá 15 trang; Times New Roman 13; "
        "lề trái 3 cm, phải–trên–dưới 2 cm; cách dòng đơn; cách đoạn 3 pts. "
        "Ảnh không lộ mặt người; mọi hình có chú thích nguồn.",
        align="center",
        italic=True,
        size=11,
        first_line=False,
    )
    doc.add_page_break()

    add_h(doc, "II. ĐỐI VỚI DỰ ÁN KỸ THUẬT")

    add_h(doc, "1. Vấn đề nghiên cứu hoặc cần giải quyết")
    add_p(
        doc,
        "Nhu cầu điều khiển thiết bị trong nhà một cách tiện lợi, an toàn và thân thiện ngày càng tăng. "
        "Nhiều giải pháp thương mại đắt, phụ thuộc ứng dụng điện thoại hoặc trợ lý giọng nói nước ngoài "
        "hiểu tiếng Việt hạn chế. Khóa cơ học dễ mất chìa; camera cố định trong nhà đặt ra lo ngại riêng tư. "
        "Hộ gia đình dùng bếp gas cần cảnh báo sớm khi nồng độ khí tăng.",
    )
    add_p(
        doc,
        "Vấn đề cần giải quyết: thiết kế và kiểm chứng mô hình nhà thông minh chi phí hợp lý cho học sinh STEM, "
        "vừa mở cửa bằng nhận diện khuôn mặt trên điện thoại (Face AIoT), vừa điều khiển bằng giọng nói tiếng Việt "
        "tự nhiên qua trợ lý AI Xiaozhi trên ESP32-S3, kết nối MQTT tới đèn, quạt, cửa/rèm và cảm biến môi trường.",
    )
    add_p(doc, "Tiêu chí giải pháp:", bold=True, first_line=False)
    add_bullet(doc, "Hiểu và thực thi câu lệnh tiếng Việt linh hoạt; mở cửa khi nhận diện đạt ngưỡng tin cậy.")
    add_bullet(doc, "Độ trễ phản hồi giọng nói hướng tới dưới 2 giây ở điều kiện chuẩn (1 m, tạp âm thấp).")
    add_bullet(doc, "Xiaozhi không dùng camera; phần Face AIoT chỉ xử lý khuôn mặt khi người dùng chủ động mở app.")
    add_bullet(doc, "Nguồn điều khiển thấp áp 5 V; tải 220 V qua rơ-le cách ly; chi phí thấp hơn Raspberry Pi + camera.")

    add_h(doc, "2. Thiết kế và phương pháp nghiên cứu")
    add_p(
        doc,
        "Nhóm so sánh ba hướng: (1) chỉ điều khiển bằng app; (2) Raspberry Pi kèm camera; "
        "(3) Face AIoT trên điện thoại + Xiaozhi ESP32-S3 + node MQTT. Phương án (3) được chọn vì kết hợp "
        "tiếng Việt tự nhiên, riêng tư tốt hơn camera cố định, và tận dụng phần cứng giá rẻ.",
    )
    add_table(
        doc,
        ["Tiêu chí", "App điện thoại", "RPi + camera", "Face AIoT + Xiaozhi"],
        [
            ["Tiếng Việt tự nhiên", "Trung bình", "Phụ thuộc phần mềm", "Tốt (LLM + STT/TTS)"],
            ["Riêng tư", "Tùy thiết bị", "Thấp hơn (camera cố định)", "Cao hơn (Xiaozhi không camera)"],
            ["Chi phí phần cứng", "Trung bình–cao", "Cao", "Thấp–trung bình"],
            ["Mở cửa không chìa", "Cần thao tác", "Tùy thị giác", "Nhận diện trên app + MQTT"],
        ],
    )
    add_p(doc, "Kiến trúc tổng thể:", bold=True, first_line=False)
    add_bullet(doc, "Khối Face AIoT: app Flutter + NCNN (detect + MobileFaceNet) → API identify → MQTT mở cửa.")
    add_bullet(doc, "Khối Xiaozhi: micro I2S → ESP32-S3 → máy chủ AI (STT/LLM/TTS) → MCP → Node.js → MQTT.")
    add_bullet(doc, "Khối chấp hành: ESP32/ESP8266 đọc cảm biến (DHT11, MQ gas, LDR/lửa), điều khiển rơ-le/servo.")
    add_bullet(doc, "Broker MQTT WSS làm cầu nối realtime giữa app, Xiaozhi bridge và firmware.")

    add_image(
        doc,
        local.get("mo_hinh_thuc_te.png"),
        width_cm=14.0,
        caption="Hình 1. Mô hình nhà thông minh thực tế (Ảnh do học sinh tự chụp).",
    )

    add_h(doc, "3. Thực hiện, chế tạo và kiểm tra")
    add_p(
        doc,
        "Chế tạo: lắp mô hình gỗ/bàn thí nghiệm; nạp firmware node phòng khách/bếp và phòng ngủ; "
        "cấu hình Wi-Fi, MQTT; đăng ký khuôn mặt trên app; thiết lập kịch bản ngữ cảnh Xiaozhi "
        "(ví dụ “Tôi đi ngủ” → tắt đèn, bật quạt).",
    )
    add_p(doc, "Luồng kiểm thử chính:", bold=True, first_line=False)
    add_bullet(doc, "MANUAL/AUTO: bật tắt đèn–quạt–cửa; AUTO theo LDR/nhiệt/gas.")
    add_bullet(doc, "Nhận diện khuôn mặt realtime → MQTT mở cửa khi cosine ≥ ngưỡng (mặc định 0,45).")
    add_bullet(doc, "Giọng nói: đo tỷ lệ thực thi đúng theo khoảng cách 1–3 m và ba mức tạp âm; đo độ trễ.")
    add_bullet(doc, "Kịch bản ngữ cảnh nhiều công cụ; đối chiếu OLED/app với trạng thái thiết bị thật.")

    add_image(
        doc,
        local.get("ui_dieu_khien_nha.png"),
        width_cm=7.0,
        caption="Hình 2. Giao diện Điều khiển nhà trên app Face AIoT (Ảnh do học sinh tự chụp màn hình).",
    )
    add_image(
        doc,
        local.get("ui_dang_ky_mat.png"),
        width_cm=8.0,
        caption="Hình 3. Đăng ký khuôn mặt thành viên (Ảnh do học sinh tự chụp màn hình).",
    )

    add_table(
        doc,
        ["Chức năng", "GPIO / ghi chú (node 123)"],
        [
            ["Gas MQ-2 (AO)", "GPIO34"],
            ["Cảm biến lửa", "GPIO19"],
            ["DHT11", "GPIO27"],
            ["Rơ-le đèn / quạt", "GPIO25 / GPIO26 (active-LOW)"],
            ["Servo cửa / còi", "GPIO13 / GPIO14"],
        ],
    )

    add_h(doc, "4. Kết quả, kết luận và khả năng ứng dụng")
    add_table(
        doc,
        ["Hạng mục", "Cách thử", "Kết quả quan sát"],
        [
            ["MQTT + MANUAL", "Bấm app / Xiaozhi", "Thiết bị phản hồi đúng topic"],
            ["AUTO LDR / nhiệt", "Che LDR; rule quạt", "Đèn/quạt theo rule + hysteresis"],
            ["Nhận diện mở cửa", "Đăng ký mặt → nhìn camera", "Mở cửa khi đạt confidence"],
            ["Giọng nói 1 m, ồn thấp", "30 lần thử", "Tỷ lệ đúng ~93,3%; độ trễ TB ~1,62 s"],
            ["Giọng nói 3 m / ồn cao", "30 lần thử", "Tỷ lệ giảm (~70% / ~60%); độ trễ tăng"],
            ["Kịch bản “Tôi đi ngủ”", "20 lần", "Đạt ~90% (đa công cụ)"],
        ],
    )
    add_p(
        doc,
        "Kết luận: nguyên mẫu chứng minh tính khả thi của nhà thông minh AIoT kết hợp nhận diện khuôn mặt "
        "và trợ lý giọng nói tiếng Việt, đạt tiêu chí riêng tư–an toàn điện–chi phí phù hợp STEM. "
        "Hướng phát triển: chống giả mạo ảnh; nhật ký ra vào; khóa điện từ; cải thiện STT ở xa/ồn; "
        "đóng gói bộ kit kèm giáo án thực hành.",
    )
    add_p(doc, "Tài liệu tham khảo (tóm tắt)", bold=True, first_line=False, space_before=8)
    for r in [
        "Espressif — ESP32-S3 Technical Reference / Datasheet.",
        "OASIS — MQTT Version 3.1.1 / 5.0.",
        "Tencent NCNN; MobileFaceNet (embedding cosine).",
        "Dự án mã nguồn mở XiaoZhi AI (xiaozhi-esp32); Anthropic MCP.",
        "Flutter Camera/FFI; tài liệu kỹ thuật DHT11, MQ-2.",
    ]:
        add_p(doc, "• " + r, first_line=False, size=12, space_after=2)

    add_p(doc, "— Hết báo cáo kết quả dự án kỹ thuật —", align="center", bold=True, first_line=False, space_before=12)

    out = OUT / "03_PL3_Bao_cao_ket_qua_du_an_ky_thuat.docx"
    doc.save(str(out))
    print("Saved", out)


# ── 04 Tiêu chí STEM ───────────────────────────────────────────────
def build_pl4_stem():
    doc = Document()
    setup_doc(doc)
    add_p(doc, "PHỤ LỤC IV — TIÊU CHÍ ĐÁNH GIÁ SẢN PHẨM STEM", align="center", bold=True, size=14, first_line=False)
    add_p(
        doc,
        f"(Áp dụng tự đối chiếu cho dự án: {TEN_NGAN})",
        align="center",
        italic=True,
        size=11,
        first_line=False,
        space_after=8,
    )
    add_table(
        doc,
        ["Tiêu chí", "Nội dung cần thực hiện", "Minh chứng dự án Face AIoT–Xiaozhi"],
        [
            [
                "1. Câu hỏi / phát hiện vấn đề (5đ)",
                "Xác định nhu cầu thực tiễn",
                "An ninh nhà ở, điều khiển tiếng Việt, cảnh báo gas, chi phí STEM",
            ],
            [
                "2. Kiến thức nền (10đ)",
                "Toán, Lý, Tin, Công nghệ liên quan",
                "Cảm biến, cosine, rule AUTO, MQTT, LLM/STT/TTS, mạch rơ-le",
            ],
            [
                "3. Giải quyết vấn đề (10đ)",
                "Đề xuất–chọn–thiết kế–chế tạo–thử",
                "So sánh 3 phương án; nguyên mẫu app+Xiaozhi+ESP; bảng đo",
            ],
            [
                "4. Sáng tạo (10đ)",
                "Sáng tạo đáng kể ở ≥1 khía cạnh",
                "Kết hợp Face AIoT on-device + Xiaozhi LLM + MQTT đa node",
            ],
            [
                "5a. Poster (5đ)",
                "Bố trí logic, đồ thị rõ",
                "PL8 poster 04 trang PDF",
            ],
            [
                "5b. Phỏng vấn (10đ)",
                "Trả lời sâu, hiểu nguyên lý",
                "HS trình bày luồng Face/Xiaozhi, số liệu, an toàn điện",
            ],
        ],
        col_widths=[4.5, 5.5, 6.0],
    )
    add_p(
        doc,
        "Ghi chú: Đây là bản tự đối chiếu giúp nhóm chuẩn bị; điểm chính thức do hội đồng giám khảo quyết định "
        "theo phiếu của Bộ/Sở.",
        italic=True,
        size=11,
        first_line=False,
    )
    # copy official converted file too
    src = DOCS / "_pl4_stem_converted.docx"
    if src.exists():
        shutil.copy2(src, OUT / "04b_PL_IV_Tieu_chi_STEM_mau_Bo.docx")

    out = OUT / "04_PL_IV_Tieu_chi_STEM_tu_doi_chieu.docx"
    doc.save(str(out))
    print("Saved", out)


# ── 05 PL IV 2027 phiếu học sinh ───────────────────────────────────
def build_pl4_phieu():
    doc = Document()
    setup_doc(doc)
    add_p(doc, "PHỤ LỤC IV (CÁC PHIẾU DÀNH CHO HỌC SINH)", align="center", bold=True, size=14, first_line=False)
    add_p(
        doc,
        "(Kèm theo Công văn số ………/BGDĐT-GDPT ngày …… tháng 10 năm 2026 của Bộ GDĐT)",
        align="center",
        italic=True,
        size=11,
        first_line=False,
        space_after=8,
    )

    add_h(doc, "Phê duyệt và đánh giá rủi ro của cơ sở giáo dục (IVa)")
    add_p(doc, "1) a. Họ và tên học sinh/nhóm trưởng: ………………………… Ngày sinh: …/…/…  Lớp: ……", first_line=False)
    add_p(doc, "Số ĐDCN: ……………… Email: ……………… Điện thoại: ………………", first_line=False)
    add_p(doc, "b. Họ và tên thành viên: ………………………… Ngày sinh: …/…/…  Lớp: ……", first_line=False)
    add_p(doc, f"2) Tên dự án: {TEN_DU_AN}", first_line=False)
    add_p(doc, "3) Trường: ………………………… Điện thoại: ………………", first_line=False)
    add_p(doc, "Địa chỉ: ……………… Xã/Phường: ……………… Tỉnh/Thành phố: ………………", first_line=False)
    add_p(doc, "Đơn vị dự thi: …………………………", first_line=False)
    add_p(doc, "4) a. Người hướng dẫn nghiên cứu: ……………… Điện thoại/email: ………/………", first_line=False)
    add_p(doc, "b. Người hướng dẫn nghiên cứu: ……………… Điện thoại/email: ………/………", first_line=False)
    add_p(doc, "5) Thời gian thí nghiệm/thu thập số liệu: từ ngày 01/08/2026 đến ngày ……/……/2026", first_line=False)
    add_p(doc, "6) Địa điểm: ☑ Trường học   ☑ Tại nhà   ☐ Cơ quan nghiên cứu   ☐ Thực địa   ☐ Nơi khác: ……", first_line=False)
    add_p(
        doc,
        "Rủi ro chính: điện lưới 220 V qua rơ-le (cần giám sát GVHD); dữ liệu khuôn mặt (cần Phiếu IVd và bảo mật).",
        first_line=False,
        space_after=8,
    )

    add_h(doc, "Cam kết của học sinh và người hướng dẫn nghiên cứu (IVb)")
    add_p(
        doc,
        "Chúng tôi cam kết thực hiện đúng quy chế cuộc thi; bảo đảm an toàn khi thí nghiệm; "
        "bảo mật dữ liệu khuôn mặt/giọng nói; kê khai trung thực công nghệ số/AI; "
        "ký cam kết trước khi tiến hành nghiên cứu.",
        first_line=True,
    )
    add_p(doc, "…………, ngày …… tháng …… năm 2026", first_line=False, space_before=8)
    add_p(doc, "Học sinh/Trưởng nhóm                    Người hướng dẫn nghiên cứu", first_line=False)
    add_p(doc, "(Ký, ghi rõ họ tên)                      (Ký, ghi rõ họ tên)", first_line=False, space_after=10)

    add_h(doc, "Phiếu xác nhận cơ quan nghiên cứu (IVc) — nếu làm ngoài nhà trường")
    add_p(doc, f"Họ và tên (các) học sinh: …………………………  Tên dự án: {TEN_NGAN}", first_line=False)
    add_p(
        doc,
        "Nếu toàn bộ thực nghiệm tại trường/tại nhà dưới giám sát GVHD thì phiếu IVc có thể không dùng; "
        "đánh dấu rõ trong nhật ký.",
        italic=True,
        size=11,
        first_line=False,
        space_after=8,
    )

    add_h(doc, "Phiếu đồng ý cung cấp thông tin / tham gia nghiên cứu (IVd)")
    add_p(doc, f"Tên dự án: {TEN_DU_AN}", first_line=False)
    add_p(doc, "Học sinh thực hiện dự án: …………………………", first_line=False)
    add_p(
        doc,
        "Mục tiêu của dự án: xây dựng và kiểm chứng mô hình nhà thông minh Face AIoT + Xiaozhi "
        "(nhận diện khuôn mặt mở cửa; điều khiển giọng nói; cảm biến môi trường).",
        first_line=False,
    )
    add_p(
        doc,
        "Nếu đồng ý, đối tượng tham gia sẽ: đăng ký mẫu khuôn mặt trên app (hoặc nói câu lệnh thử nghiệm); "
        "không bắt buộc cung cấp ảnh công khai; có thể rút lại bất kỳ lúc nào.",
        first_line=False,
    )
    add_p(doc, "Thời gian tham gia: từ ngày ………… đến ngày …………", first_line=False)
    add_p(
        doc,
        "Nguy cơ/lợi ích: rủi ro lộ dữ liệu sinh trắc nếu quản lý kém — được giảm bằng lưu embeddings, "
        "giới hạn quyền truy cập, không đăng tải ảnh mặt lên poster; lợi ích là tăng an ninh/tiện nghi nhà ở.",
        first_line=False,
    )
    add_p(
        doc,
        "Bảo mật: embeddings lưu trên server có kiểm soát truy cập; không đưa ảnh rõ mặt vào báo cáo/poster; "
        "xóa mẫu khi người tham gia yêu cầu.",
        first_line=False,
    )
    add_p(doc, "Liên hệ người hướng dẫn: ………………, ĐT: ………………", first_line=False, space_after=6)
    add_p(
        doc,
        "Việc tham gia hoàn toàn tự nguyện. Bằng việc ký tên, tôi hiểu thông tin và đồng ý tham gia.",
        first_line=False,
    )
    add_p(doc, "…………, ngày …… tháng …… năm 2026", first_line=False, space_before=8)
    add_p(doc, "Đối tượng tham gia (Ký, ghi rõ họ tên)     Cha mẹ/người giám hộ (nếu vị thành niên)", first_line=False)

    out = OUT / "05_PL_IV_2027_Phieu_hoc_sinh_IVa_d.docx"
    doc.save(str(out))
    print("Saved", out)


# ── 06 PL V Nhật ký ────────────────────────────────────────────────
def build_pl5():
    doc = Document()
    setup_doc(doc)
    add_p(doc, "PHỤ LỤC V", align="center", bold=True, size=14, first_line=False)
    add_p(doc, "NHẬT KÝ NGHIÊN CỨU VÀ MINH CHỨNG DỮ LIỆU", align="center", bold=True, size=14, first_line=False)
    add_p(
        doc,
        "(Bắt buộc với các công việc thực hiện sau ngày 30/9/2026 — theo mẫu CV 7292/BGDĐT-GDPT)",
        align="center",
        italic=True,
        size=11,
        first_line=False,
        space_after=8,
    )

    add_h(doc, "I. THÔNG TIN CHUNG")
    add_p(doc, f"Tên dự án dự thi: {TEN_DU_AN}", first_line=False)
    add_p(doc, f"Lĩnh vực dự thi: {LINH_VUC}", first_line=False)
    add_p(doc, "Họ và tên học sinh/nhóm trưởng: ....................................................", first_line=False)
    add_p(doc, "Họ và tên thành viên (nếu có): .......................................................", first_line=False)
    add_p(doc, "Họ và tên người hướng dẫn nghiên cứu 1: .............................................", first_line=False)
    add_p(doc, "Họ và tên người hướng dẫn nghiên cứu 2: .............................................", first_line=False)
    add_p(doc, "Cơ sở giáo dục phổ thông: ....................................................................", first_line=False)
    add_p(doc, "Đơn vị dự thi: ...................................................................................", first_line=False)
    add_p(doc, "Thời gian thực hiện: từ ngày 01/08/2026 đến ngày ……/……/2026", first_line=False, space_after=6)

    add_h(doc, "II. NHẬT KÝ THỰC HIỆN")
    add_table(
        doc,
        ["TT", "Ngày", "Nội dung", "Địa điểm", "Người TH", "Minh chứng", "Kết quả", "Xác nhận HD"],
        [
            ["1", "01–10/08/2026", "Khảo sát nhu cầu nhà thông minh, tiếng Việt, an ninh cửa", "Trường/nhà", "Nhóm HS", "Ghi chép", "Chốt vấn đề & tiêu chí", "GVHD T8"],
            ["2", "11–25/08/2026", "So sánh App / RPi+camera / FaceAIoT+Xiaozhi", "Phòng máy", "HS+GVHD", "Bảng so sánh", "Chọn phương án 3", ""],
            ["3", "26/08–15/09/2026", "Lắp mô hình, sơ đồ chân ESP, Wi-Fi, MQTT", "Phòng thực hành", "Nhóm HS", "Ảnh mạch (không lộ mặt)", "Node online", "GVHD"],
            ["4", "16–30/09/2026", "Firmware AUTO/MANUAL, rule cảm biến, OLED", "Phòng thực hành", "Nhóm HS", "Log MQTT/OLED", "Rule ổn định", "GVHD T9"],
            ["5", "01–15/10/2026", "App Face AIoT: auth, đăng ký mặt, unlock realtime", "Tại nhà/phòng máy", "Nhóm HS", "Screenshot UI", "Mở cửa bằng mặt", ""],
            ["6", "16–31/10/2026", "Cấu hình Xiaozhi STT/LLM/TTS, MCP→MQTT, kịch bản", "Phòng máy", "Nhóm HS", "Bảng đo giọng nói", "Độ trễ chuẩn <2s", "GVHD T10"],
            ["7", "01–15/11/2026", "Đo khoảng cách/tạp âm; hoàn thiện PL3, nhật ký, AI, poster", "Trường/nhà", "HS+GVHD", "Hồ sơ PL", "Sẵn sàng ký nộp", "GVHD T11"],
        ],
        col_widths=[1.0, 2.3, 3.8, 2.0, 1.6, 2.2, 2.2, 1.6],
    )
    add_p(
        doc,
        "* Người hướng dẫn xác nhận định kỳ ít nhất 01 lần/tháng vào cột xác nhận hoặc trang ký riêng.",
        italic=True,
        size=11,
        first_line=False,
    )

    add_h(doc, "III. KÊ KHAI CÔNG VIỆC")
    add_p(doc, "1. Học sinh 1 / Trưởng nhóm: (điền họ tên)", bold=True, first_line=False)
    add_table(
        doc,
        ["Nội dung công việc", "Chi tiết", "Minh chứng"],
        [
            ["Khảo sát & thiết kế", "Chốt tiêu chí, kiến trúc Face AIoT + Xiaozhi + MQTT", "Nhật ký, sơ đồ"],
            ["Phần mềm & AI", "App Flutter/NCNN; cấu hình Xiaozhi/MCP", "Mã nguồn, UI"],
            ["Kiểm thử & hồ sơ", "Đo độ trễ/tỷ lệ; soạn PL3–PL8", "Bảng đo, báo cáo"],
        ],
        col_widths=[4.5, 7.0, 4.5],
    )
    add_p(doc, "2. Học sinh 2 (nếu có): (điền họ tên)", bold=True, first_line=False)
    add_table(
        doc,
        ["Nội dung công việc", "Chi tiết", "Minh chứng"],
        [
            ["Phần cứng & firmware", "Lắp cảm biến/rơ-le/servo; nạp ESP", "Ảnh mô hình, firmware"],
            ["Thử nghiệm & minh chứng", "Đo AUTO/gas; hỗ trợ bảng số liệu", "Bảng đo, video demo"],
        ],
        col_widths=[4.5, 7.0, 4.5],
    )
    add_p(doc, "3. Người hướng dẫn nghiên cứu 1", bold=True, first_line=False)
    add_p(doc, "Họ tên / Đơn vị / Email / Điện thoại: ..............................................", first_line=False)
    add_p(
        doc,
        "Công việc hỗ trợ: định hướng đề tài, duyệt an toàn điện và dữ liệu khuôn mặt, "
        "xác nhận nhật ký hàng tháng, góp ý báo cáo/poster. Thời gian: 08–11/2026.",
        first_line=False,
    )
    add_p(doc, "7. Hỗ trợ có trả phí:  ☐ Có    ☑ Không", first_line=False, space_before=4)

    add_h(doc, "IV. DỮ LIỆU NGHIÊN CỨU")
    add_p(doc, "Minh chứng dữ liệu được đính kèm Nhật ký này:  ☑ Có    ☐ Không", first_line=False)
    add_bullet(doc, "Mã nguồn app Face AIoT (Flutter + NCNN) và firmware ESP / cầu nối Xiaozhi–MQTT.")
    add_bullet(doc, "Ảnh mô hình, screenshot UI (không lộ mặt người trên poster/báo cáo công khai).")
    add_bullet(doc, "Bảng đo nhận diện mở cửa; bảng tỷ lệ/độ trễ giọng nói theo khoảng cách và tạp âm.")
    add_bullet(doc, "Phiếu IVd (đồng ý đăng ký khuôn mặt) — lưu kèm hồ sơ trường.")

    add_h(doc, "V. KÊ KHAI HỒ SƠ")
    add_p(doc, "☐ 1) Ý kiến chuyên môn đánh giá rủi ro (nếu thuộc diện).", first_line=False)
    add_p(doc, "☑ 2) Phiếu IVd đồng ý cung cấp thông tin (đăng ký khuôn mặt / thử giọng nói).", first_line=False)
    add_p(doc, "☐ 3) Phiếu IVc cơ quan nghiên cứu ngoài nhà trường (nếu có).", first_line=False)
    add_p(doc, "4) Kê khai công nghệ số, AI:", first_line=False)
    add_p(doc, "☐ a) Chỉ tra cứu/kiểm tra chính tả — không phải khai báo.", first_line=False)
    add_p(doc, "☑ b) Phải khai báo theo quy định → xem file 07_PL7_Khai_bao_AI.docx", first_line=False, space_after=8)
    add_p(doc, "…………, ngày …… tháng …… năm 20…", first_line=False)
    add_p(doc, "Xác nhận người hướng dẫn nghiên cứu          Học sinh/trưởng nhóm", first_line=False)
    add_p(doc, "(Ký, ghi rõ họ tên)                              (Ký, ghi rõ họ tên)", first_line=False, space_after=8)
    add_p(doc, "Xác nhận của cơ sở giáo dục (Ký, ghi rõ họ tên và đóng dấu)", first_line=False)

    out = OUT / "06_PL_V_Nhat_ky_nghien_cuu.docx"
    doc.save(str(out))
    print("Saved", out)


# ── 07 Khai báo AI ─────────────────────────────────────────────────
def build_pl7():
    doc = Document()
    setup_doc(doc)
    add_p(doc, "PHỤ LỤC — PHIẾU KHAI BÁO SỬ DỤNG CÔNG NGHỆ SỐ, TRÍ TUỆ NHÂN TẠO", align="center", bold=True, size=14, first_line=False)
    add_p(
        doc,
        "(Theo yêu cầu kê khai tại Phụ lục V mục 4b / CV 7292 — điền trước khi nộp)",
        align="center",
        italic=True,
        size=11,
        first_line=False,
        space_after=8,
    )

    add_h(doc, "I. THÔNG TIN CHUNG")
    add_p(doc, f"Tên dự án dự thi: {TEN_DU_AN}", first_line=False)
    add_p(doc, f"Lĩnh vực dự thi: {LINH_VUC}", first_line=False)
    add_p(doc, "Họ và tên học sinh/nhóm trưởng: ....................................................", first_line=False)
    add_p(doc, "Họ và tên thành viên (nếu có): .......................................................", first_line=False)
    add_p(doc, "Họ và tên người hướng dẫn nghiên cứu: ...............................................", first_line=False)
    add_p(doc, "Cơ sở giáo dục / Đơn vị dự thi: ........................................................", first_line=False, space_after=6)

    add_h(doc, "II. KÊ KHAI CÔNG CỤ")
    add_table(
        doc,
        ["TT", "Tên công cụ", "Mục đích / nội dung sử dụng", "Mức độ", "Ghi chú"],
        [
            ["1", "Flutter + Dart FFI + NCNN", "App Face AIoT: UI, detect/embedding khuôn mặt on-device", "Chính", "Do HS thực hiện"],
            ["2", "MobileFaceNet / YuNet (NCNN)", "Nhận diện 1:N, ngưỡng cosine", "Chính", "Mô hình nhẹ"],
            ["3", "AI Xiaozhi (ESP32-S3) + STT/LLM/TTS", "Điều khiển giọng nói tiếng Việt, phản hồi loa", "Chính", "Máy chủ AI"],
            ["4", "MCP + Node.js + MQTT", "Ánh xạ tool → topic điều khiển thiết bị", "Chính", ""],
            ["5", "Arduino/ESP firmware", "Node chấp hành, cảm biến, rơ-le, servo", "Chính", ""],
            ["6", "Excel / công cụ vẽ sơ đồ", "Bảng đo, sơ đồ khối", "Hỗ trợ", "Chú thích nguồn"],
            ["7", "Soạn thảo văn bản (+ AI hội thoại nếu có)", "Biên soạn báo cáo/poster theo khung mẫu", "Hỗ trợ", "HS chịu trách nhiệm nội dung"],
        ],
        col_widths=[1.0, 4.2, 5.5, 1.8, 3.5],
    )

    add_h(doc, "III. TÓM TẮT PROMPT LOG (nếu dùng AI hội thoại hỗ trợ soạn thảo)")
    add_bullet(doc, "Yêu cầu: gợi ý khung báo cáo dự án kỹ thuật (vấn đề – thiết kế – chế tạo – kết quả) theo CV 7292.")
    add_bullet(doc, "Phản hồi: khung mục; nhóm viết lại toàn bộ bằng số liệu và thử nghiệm thực tế của dự án.")
    add_bullet(doc, "Yêu cầu: gợi ý bảng nhật ký; nhóm tự điền ngày/minh chứng theo tiến độ.")
    add_bullet(doc, "Cam kết: không dùng AI để bịa số liệu; mô hình nhận diện và Xiaozhi chạy theo cấu hình đã kiểm thử.")
    add_p(
        doc,
        "Cam kết: Học sinh chịu trách nhiệm về tính trung thực của dữ liệu, kết quả và nội dung trình bày.",
        first_line=False,
        space_before=6,
    )
    add_p(doc, "…………, ngày …… tháng …… năm 202…", first_line=False, space_before=10)
    add_p(doc, "Người hướng dẫn nghiên cứu          Học sinh/Trưởng nhóm          Thành viên", first_line=False)
    add_p(doc, "(Ký, ghi rõ họ tên)                 (Ký, ghi rõ họ tên)            (Ký, ghi rõ họ tên)", first_line=False)

    out = OUT / "07_PL7_Phieu_khai_bao_cong_nghe_so_AI.docx"
    doc.save(str(out))
    print("Saved", out)


# ── 08 Poster PDF ──────────────────────────────────────────────────
def _register_font() -> str:
    for p in [Path(r"C:\Windows\Fonts\times.ttf"), Path(r"C:\Windows\Fonts\arial.ttf")]:
        if p.exists():
            try:
                pdfmetrics.registerFont(TTFont("ReportFont", str(p)))
                return "ReportFont"
            except Exception:
                continue
    return "Helvetica"


def build_pl8(local: dict[str, Path]):
    font = _register_font()
    out = OUT / "08_PL8_Poster_dien_tu_04_trang.pdf"
    doc = SimpleDocTemplate(
        str(out),
        pagesize=A4,
        leftMargin=2 * cm,
        rightMargin=2 * cm,
        topMargin=1.6 * cm,
        bottomMargin=1.6 * cm,
    )
    styles = getSampleStyleSheet()
    title = ParagraphStyle("t", parent=styles["Heading1"], fontName=font, fontSize=13, leading=17, alignment=1, spaceAfter=6)
    h = ParagraphStyle("h", parent=styles["Heading2"], fontName=font, fontSize=12, leading=16, spaceBefore=6, spaceAfter=4)
    body = ParagraphStyle("b", parent=styles["BodyText"], fontName=font, fontSize=11, leading=15, alignment=4, spaceAfter=4)
    small = ParagraphStyle("s", parent=styles["BodyText"], fontName=font, fontSize=9, leading=12, alignment=1, spaceAfter=4)

    story = []
    story.append(Paragraph("PHỤ LỤC VII/VIII — POSTER ĐIỆN TỬ (KHÔNG ghi tên trường/học sinh)", small))
    story.append(Paragraph(TEN_DU_AN, title))
    story.append(Paragraph(f"Lĩnh vực: {LINH_VUC}", small))
    story.append(Paragraph("Trang 1 — Mục tiêu & Phương pháp", h))
    for b in [
        "Mục tiêu: chế tạo và kiểm chứng nhà thông minh vừa mở cửa bằng nhận diện khuôn mặt (Face AIoT), vừa điều khiển bằng giọng nói tiếng Việt (Xiaozhi ESP32-S3).",
        "Vấn đề: khóa cơ học bất tiện; app-only kém thân thiện; camera cố định lo ngại riêng tư; cần cảnh báo gas.",
        "Phương pháp: khảo sát → so sánh 3 phương án → thiết kế kiến trúc MQTT → chế tạo nguyên mẫu → đo tỷ lệ/độ trễ.",
        "Công nghệ: Flutter+NCNN, MobileFaceNet, Xiaozhi STT/LLM/TTS+MCP, ESP32/ESP8266, MQTT WSS, DHT11/MQ/LDR.",
    ]:
        story.append(Paragraph(f"• {b}", body))
    if "mo_hinh_thuc_te.png" in local:
        story.append(RLImage(str(local["mo_hinh_thuc_te.png"]), width=14 * cm, height=7.5 * cm, kind="proportional"))
        story.append(Paragraph("Hình mô hình thực tế (Ảnh do học sinh tự chụp)", small))
    story.append(PageBreak())

    story.append(Paragraph("Trang 2 — Quá trình thực hiện", h))
    story.append(Paragraph(TEN_NGAN, small))
    for b in [
        "Lắp mô hình, sơ đồ chân, cấu hình Wi-Fi/MQTT, OLED trạng thái.",
        "Lập trình firmware AUTO/MANUAL và rule cảm biến (nhiệt, LDR, gas).",
        "Xây app Face AIoT: đăng ký mặt, unlock realtime, điều khiển nhà.",
        "Cấu hình Xiaozhi + MCP bridge; thiết lập kịch bản ngữ cảnh tiếng Việt.",
    ]:
        story.append(Paragraph(f"• {b}", body))
    if "ui_dieu_khien_nha.png" in local:
        story.append(RLImage(str(local["ui_dieu_khien_nha.png"]), width=8 * cm, height=12 * cm, kind="proportional"))
        story.append(Paragraph("Giao diện điều khiển nhà (Ảnh do học sinh tự chụp màn hình)", small))
    story.append(PageBreak())

    story.append(Paragraph("Trang 3 — Kết quả", h))
    story.append(Paragraph(TEN_NGAN, small))
    for b in [
        "MANUAL/AUTO ổn định; nhận diện mở cửa khi đạt ngưỡng cosine.",
        "Giọng nói 1 m, tạp âm thấp: ~93,3% đúng; độ trễ TB ~1,62 s (dưới 2 s).",
        "Ở 3 m / tạp âm cao tỷ lệ giảm; sai chủ yếu ở STT/chọn tool, không sai GPIO.",
        "Kịch bản “Tôi đi ngủ” đa công cụ đạt ~90%.",
    ]:
        story.append(Paragraph(f"• {b}", body))
    data = [
        ["Hạng mục", "Kết quả"],
        ["Mở cửa Face AIoT", "Realtime + MQTT khi đạt ngưỡng"],
        ["Xiaozhi chuẩn (1 m)", "~93,3% | ~1,62 s"],
        ["Kịch bản ngữ cảnh", "~80–90%"],
        ["An toàn", "5 V logic + rơ-le cách ly 220 V"],
    ]
    t = Table(data, colWidths=[6 * cm, 10 * cm])
    t.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), font),
                ("FONTSIZE", (0, 0), (-1, -1), 10),
                ("BACKGROUND", (0, 0), (-1, 0), colors.Color(0.12, 0.30, 0.47)),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]
        )
    )
    story.append(Spacer(1, 6))
    story.append(t)
    if "ui_mo_cua.png" in local:
        story.append(Spacer(1, 8))
        story.append(RLImage(str(local["ui_mo_cua.png"]), width=7 * cm, height=10 * cm, kind="proportional"))
        story.append(Paragraph("Màn mở cửa bằng nhận diện (Ảnh do học sinh tự chụp màn hình)", small))
    story.append(PageBreak())

    story.append(Paragraph("Trang 4 — Ý nghĩa / Kết luận & hướng phát triển", h))
    story.append(Paragraph(TEN_NGAN, small))
    for b in [
        "STEM: Khoa học cảm biến & thị giác; Công nghệ MQTT/LLM; Kỹ thuật mạch–firmware; Toán ngưỡng/cosine/rule.",
        "Ứng dụng: học cụ STEM, demo an ninh nhà ở, cảnh báo gas; không phụ thuộc chìa khóa vật lý.",
        "Hạn chế: STT kém khi xa/ồn; nhận diện phụ thuộc ánh sáng; cần Internet cho Xiaozhi cloud.",
        "Hướng phát triển: chống spoofing; nhật ký ra vào; khóa điện từ; kit giáo án nhà trường.",
    ]:
        story.append(Paragraph(f"• {b}", body))
    story.append(Spacer(1, 12))
    story.append(
        Paragraph(
            "Quy định poster CV 7292: không tên trường/học sinh/logo; không QR/link; chú thích nguồn dưới mọi hình.",
            small,
        )
    )
    doc.build(story)
    print("Saved", out)


# ── 09 Báo cáo STEM đầy đủ ─────────────────────────────────────────
def build_bao_cao_stem(local: dict[str, Path]):
    """Báo cáo STEM đầy đủ gửi khách — kết hợp Face AIoT docs + Xiaozhi."""
    doc = Document()
    setup_doc(doc)
    for section in doc.sections:
        footer = section.footer
        footer.is_linked_to_previous = False
        p = footer.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = p.add_run(f"{TEN_NGAN}  ·  Hồ sơ STEM/KHKT 2026–2027")
        set_run_font(run, size=10, italic=True, color=NAVY)

    add_p(doc, "CUỘC THI KHOA HỌC KỸ THUẬT / STEM DÀNH CHO HỌC SINH", align="center", bold=True, first_line=False, size=13)
    add_p(doc, "BÁO CÁO DỰ ÁN STEM", align="center", bold=True, size=18, first_line=False, color=NAVY, space_before=12)
    add_p(doc, TEN_DU_AN, align="center", bold=True, size=14, first_line=False, space_before=10, space_after=12)
    add_p(doc, f"Lĩnh vực: {LINH_VUC}", align="center", italic=True, size=12, first_line=False)
    add_p(doc, "Năm học: 2025 – 2026 / Dự thi 2026 – 2027", align="center", size=12, first_line=False, space_after=16)
    add_p(doc, "Thông tin nhóm dự án (điền đầy đủ khi nộp):", bold=True, first_line=False)
    for line in [
        "• Họ và tên học sinh: ................................................................",
        "• Lớp / Trường: ...........................................................................",
        "• Giáo viên hướng dẫn: ...................................................................",
        "• Số điện thoại liên hệ: .................................................................",
    ]:
        add_p(doc, line, first_line=False, size=12, space_after=2)

    doc.add_page_break()
    add_h(doc, "MỤC LỤC", size=14)
    for item in [
        "I. Tóm tắt dự án",
        "II. Lý do chọn đề tài",
        "III. Mục tiêu nghiên cứu",
        "IV. Đối tượng và phạm vi",
        "V. Nội dung và phương pháp",
        "VI. Thiết kế hệ thống",
        "VII. Phần cứng mô hình",
        "VIII. Phần mềm và AI (Face AIoT + Xiaozhi)",
        "IX. Kết quả thực nghiệm",
        "X. Ý nghĩa STEM và khả năng ứng dụng",
        "XI. Kết luận và hướng phát triển",
        "XII. Tài liệu tham khảo",
    ]:
        add_p(doc, item, first_line=False, space_after=2)

    doc.add_page_break()
    add_h(doc, "I. TÓM TẮT DỰ ÁN", size=14)
    add_p(
        doc,
        "Dự án xây dựng mô hình nhà thông minh AIoT gồm hai kênh điều khiển bổ sung nhau: "
        "(1) ứng dụng Face AIoT trên điện thoại đăng ký/nhận diện khuôn mặt realtime bằng NCNN, "
        "so khớp 1:N và gửi MQTT mở cửa; (2) trợ lý AI Xiaozhi trên ESP32-S3 hiểu lệnh tiếng Việt "
        "qua STT/LLM/TTS và MCP, điều khiển đèn–quạt–cửa/rèm, đọc cảm biến. Node ESP đọc DHT11, "
        "MQ gas, LDR/lửa; hỗ trợ MANUAL/AUTO. Sản phẩm phù hợp STEM: Khoa học–Công nghệ–Kỹ thuật–Toán.",
    )

    add_h(doc, "II. LÝ DO CHỌN ĐỀ TÀI", size=14)
    add_p(
        doc,
        "An ninh nhà ở, tiện nghi điều khiển và cảnh báo gas là nhu cầu thực tế. Giải pháp thương mại "
        "thường đắt hoặc hỗ trợ tiếng Việt hạn chế. Kết hợp Face AIoT với Xiaozhi giúp học sinh thực hành "
        "IoT, AI nhẹ trên di động, LLM và an toàn điện trong một đề tài thống nhất.",
    )

    add_h(doc, "III. MỤC TIÊU NGHIÊN CỨU", size=14)
    add_bullet(doc, "Xây dựng mô hình nhà thông minh điều khiển qua MQTT từ app và từ Xiaozhi.")
    add_bullet(doc, "Tích hợp nhận diện khuôn mặt realtime; mở cửa khi đạt ngưỡng confidence.")
    add_bullet(doc, "Thiết lập lệnh/kịch bản tiếng Việt; đo tỷ lệ đúng và độ trễ theo khoảng cách–tạp âm.")
    add_bullet(doc, "Hỗ trợ MANUAL/AUTO theo rule cảm biến; cảnh báo gas.")
    add_bullet(doc, "Đánh giá ổn định kết nối, an toàn điện và khả năng trình diễn STEM.")

    add_h(doc, "IV. ĐỐI TƯỢNG VÀ PHẠM VI", size=14)
    add_p(
        doc,
        "Đối tượng: mô hình bàn thí nghiệm; thành viên đã đăng ký khuôn mặt; người dùng nói lệnh thử nghiệm. "
        "Phạm vi: Face AIoT on-device + API identify; Xiaozhi cần Internet; chưa khóa điện tử công nghiệp "
        "hay camera cố định ngoài trời. Thời gian thực hiện trong khung hồ sơ KHKT.",
    )

    add_h(doc, "V. NỘI DUNG VÀ PHƯƠNG PHÁP", size=14)
    add_p(
        doc,
        "Quy trình thiết kế kỹ thuật: khảo sát → so sánh phương án → sơ đồ khối → chế tạo → "
        "lập trình firmware/app/Xiaozhi bridge → thử nghiệm và hiệu chỉnh ngưỡng (gas, nhiệt, cosine, STT).",
    )

    add_h(doc, "VI. THIẾT KẾ HỆ THỐNG", size=14)
    add_table(
        doc,
        ["Thành phần", "Công nghệ / thiết bị", "Vai trò"],
        [
            ["Face AIoT app", "Flutter + NCNN + FFI", "UI, nhận diện, điều khiển"],
            ["AI mặt", "YuNet/SCRFD + MobileFaceNet", "Detect + embedding on-device"],
            ["Xiaozhi", "ESP32-S3 + STT/LLM/TTS + MCP", "Giọng nói tiếng Việt"],
            ["Backend", "API + MongoDB + Node MCP bridge", "Auth, gallery, tool→MQTT"],
            ["Node IoT", "ESP32 / ESP8266", "Cảm biến + rơ-le + servo"],
            ["Kết nối", "MQTT WSS", "cmnd/* và tele/*"],
        ],
    )

    add_h(doc, "VII. PHẦN CỨNG MÔ HÌNH", size=14)
    add_image(
        doc,
        local.get("mo_hinh_thuc_te.png"),
        width_cm=14.5,
        caption="Hình 1. Mô hình nhà thông minh thực tế (Ảnh do học sinh tự chụp).",
    )
    add_table(
        doc,
        ["Chức năng (node 123)", "GPIO", "Ghi chú"],
        [
            ["Gas MQ-2", "34", "ADC"],
            ["Lửa", "19", "Digital"],
            ["DHT11", "27", "Nhiệt–ẩm"],
            ["Rơ-le đèn/quạt", "25 / 26", "Active-LOW"],
            ["Servo cửa / còi", "13 / 14", "PWM / GPIO"],
        ],
    )

    add_h(doc, "VIII. PHẦN MỀM VÀ AI", size=14)
    add_p(
        doc,
        "App Face AIoT: đăng nhập API, đăng ký nhiều mẫu mặt, unlock image-stream, điều khiển MANUAL/AUTO, "
        "cảnh báo gas (FCM trên Android). Xiaozhi: mở phiên nghe, STT, LLM chọn tool MCP, MQTT tới thiết bị, "
        "TTS phản hồi. Topic ví dụ: cmnd/123_led1/POWER, cmnd/123_door_livingroom1/POWER, tele/123_vitals/status.",
    )
    add_image(doc, local.get("ui_dieu_khien_nha.png"), width_cm=7.0, caption="Hình 2. Điều khiển nhà (Ảnh HS tự chụp màn hình).")
    add_image(doc, local.get("ui_dang_ky_mat.png"), width_cm=8.0, caption="Hình 3. Đăng ký khuôn mặt (Ảnh HS tự chụp màn hình).")
    add_image(doc, local.get("ui_mo_cua.png"), width_cm=7.0, caption="Hình 4. Mở cửa bằng nhận diện (Ảnh HS tự chụp màn hình).")

    add_h(doc, "IX. KẾT QUẢ THỰC NGHIỆM", size=14)
    add_table(
        doc,
        ["Hạng mục", "Kết quả"],
        [
            ["MQTT MANUAL/AUTO", "Thiết bị phản hồi đúng; rule LDR/nhiệt/gas hoạt động"],
            ["Nhận diện mở cửa", "Mở cửa khi đạt ngưỡng cosine; có cooldown"],
            ["Giọng nói 1 m, ồn thấp", "~93,3% đúng; độ trễ TB ~1,62 s"],
            ["Giọng nói 3 m / ồn cao", "~70% / ~60%; độ trễ tăng"],
            ["Kịch bản ngữ cảnh", "~80–90% tùy độ phức tạp"],
        ],
    )

    add_h(doc, "X. Ý NGHĨA STEM VÀ ỨNG DỤNG", size=14)
    add_p(
        doc,
        "Dự án thể hiện đủ bốn trụ cột STEM và có thể dùng làm học cụ nhà trường, demo an ninh nhà ở/phòng lab, "
        "cảnh báo gas hộ dùng bếp gas. Không phụ thuộc chìa khóa vật lý; Xiaozhi ưu tiên riêng tư hơn camera cố định.",
    )

    add_h(doc, "XI. KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN", size=14)
    add_p(
        doc,
        "Nhóm hoàn thành nguyên mẫu nhà thông minh Face AIoT + Xiaozhi vận hành được trên mô hình thật. "
        "Hướng tiếp: chống spoofing; nhật ký ra vào; khóa điện từ; cải thiện STT; bộ kit STEM kèm giáo án.",
    )

    add_h(doc, "XII. TÀI LIỆU THAM KHẢO", size=14)
    for r in [
        "1. Espressif — ESP32-S3 Technical Reference Manual / Datasheet.",
        "2. OASIS — MQTT Version 3.1.1 / 5.0.",
        "3. Tencent NCNN; MobileFaceNet / face embedding cosine matching.",
        "4. XiaoZhi AI — xiaozhi-esp32 (GitHub); Anthropic MCP specification.",
        "5. Flutter Camera / FFI documentation.",
        "6. Datasheet DHT11, MQ-2; mã nguồn dự án face_alot và cầu nối Xiaozhi.",
    ]:
        add_p(doc, r, first_line=False, size=12, space_after=2)

    add_p(doc, "Xin trân trọng cảm ơn Hội đồng giám khảo!", align="center", italic=True, first_line=False, space_before=16)
    add_p(doc, "Nhóm thực hiện (Ký và ghi rõ họ tên)", align="center", bold=True, first_line=False, space_before=12)

    out = OUT / "09_BAO_CAO_STEM_Face_AIoT_Xiaozhi.docx"
    doc.save(str(out))
    # đồng bộ bản docs gốc nếu có
    stem_src = DOCS / "BAO_CAO_STEM_NinhBinh_Face_AIoT_Nha_Thong_Minh.docx"
    if stem_src.exists():
        shutil.copy2(stem_src, OUT / "09b_BAO_CAO_STEM_Face_AIoT_mau_cu.docx")
    xiaozhi_src = ROOT / "report" / "Bao cao do an - Nha thong minh AI Xiaozhi.docx"
    if xiaozhi_src.exists():
        shutil.copy2(xiaozhi_src, OUT / "09c_Bao_cao_do_an_Nha_thong_minh_AI_Xiaozhi.docx")
    print("Saved", out)


# ── 11 Kế hoạch nghiên cứu ─────────────────────────────────────────
def build_ke_hoach(local: dict[str, Path]):
    """Kế hoạch nghiên cứu (mẫu gần EduSelf KE_HOACH) — Face AIoT + Xiaozhi."""
    doc = Document()
    setup_doc(doc)

    def section_banner(text: str):
        table = doc.add_table(rows=1, cols=1)
        table.style = "Table Grid"
        cell = table.rows[0].cells[0]
        cell.text = ""
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        run = p.add_run(text)
        set_run_font(run, size=13, bold=True, color=RGBColor(0xFF, 0xFF, 0xFF))
        shade_cell(cell, "1F4E79")
        doc.add_paragraph()

    add_p(doc, "SỞ GIÁO DỤC VÀ ĐÀO TẠO ……………………………", align="center", bold=True, first_line=False, size=13)
    add_p(doc, "TRƯỜNG ........................................", align="center", bold=True, first_line=False, size=13, space_after=8)
    add_p(doc, "CUỘC THI KHOA HỌC KỸ THUẬT / STEM DÀNH CHO HỌC SINH TRUNG HỌC", align="center", bold=True, first_line=False, size=13)
    add_p(doc, "NĂM HỌC 2025 – 2026 / DỰ THI 2026 – 2027", align="center", first_line=False, size=12, space_after=10)
    add_p(doc, "KẾ HOẠCH NGHIÊN CỨU", align="center", bold=True, first_line=False, size=18, color=NAVY, space_before=6, space_after=10)
    add_p(doc, f"Tên đề tài: {TEN_DU_AN}", first_line=False, bold=True, size=12, space_after=4)
    add_p(doc, f"Lĩnh vực: {LINH_VUC}", first_line=False, size=12, space_after=2)
    add_p(doc, "Học sinh: ................................................", first_line=False, size=12, space_after=2)
    add_p(doc, "Giáo viên hướng dẫn: ................................................", first_line=False, size=12, space_after=10)

    section_banner("I. GIỚI THIỆU VÀ TÍNH CẤP THIẾT CỦA ĐỀ TÀI")
    add_p(
        doc,
        "An ninh nhà ở, tiện nghi điều khiển thiết bị và cảnh báo khí gas là nhu cầu thực tế. "
        "Nhiều giải pháp thương mại còn đắt hoặc hỗ trợ tiếng Việt hạn chế. Dự án kết hợp "
        "ứng dụng Face AIoT (nhận diện khuôn mặt trên điện thoại) với trợ lý AI Xiaozhi "
        "(ESP32-S3, STT/LLM/TTS) để học sinh thực hành IoT, AI nhẹ trên di động, LLM và an toàn điện "
        "trong một đề tài STEM thống nhất.",
    )
    add_p(doc, "Tính cấp thiết:", bold=True, first_line=False, space_before=4)
    add_bullet(doc, "Mở cửa bằng nhận diện khuôn mặt on-device, không phụ thuộc chìa khóa vật lý.")
    add_bullet(doc, "Điều khiển đèn–quạt–cửa/rèm và hỏi cảm biến bằng giọng nói tiếng Việt.")
    add_bullet(doc, "Cảnh báo gas / rule AUTO theo cảm biến; nguồn điều khiển thấp áp, tải 220 V qua rơ-le cách ly.")
    add_bullet(doc, "Chi phí và độ phức tạp phù hợp học sinh trung học trình diễn STEM.")
    add_image(
        doc,
        local.get("mo_hinh_thuc_te.png"),
        width_cm=12.0,
        caption="Hình KH.1. Định hướng sản phẩm — mô hình nhà thông minh Face AIoT + Xiaozhi (Ảnh do học sinh tự chụp).",
    )

    section_banner("II. MỤC TIÊU VÀ GIẢ THUYẾT NGHIÊN CỨU")
    add_h(doc, "1. Mục tiêu nghiên cứu")
    add_p(
        doc,
        "Mục tiêu tổng quát: thiết kế, chế tạo và kiểm chứng mô hình nhà thông minh AIoT "
        "kết hợp nhận diện khuôn mặt (Face AIoT) và trợ lý giọng nói tiếng Việt (Xiaozhi), "
        "đạt độ ổn định và độ trễ phản hồi phù hợp điều kiện thí nghiệm STEM.",
    )
    add_p(doc, "Mục tiêu cụ thể:", bold=True, first_line=False)
    add_bullet(doc, "Xây dựng mô hình nhà thông minh điều khiển qua MQTT từ app và từ Xiaozhi.")
    add_bullet(doc, "Tích hợp nhận diện khuôn mặt realtime; mở cửa khi đạt ngưỡng confidence.")
    add_bullet(doc, "Thiết lập lệnh/kịch bản tiếng Việt; đo tỷ lệ đúng và độ trễ theo khoảng cách–tạp âm.")
    add_bullet(doc, "Hỗ trợ MANUAL/AUTO theo rule cảm biến; cảnh báo gas.")
    add_bullet(doc, "Đánh giá ổn định kết nối, an toàn điện và khả năng trình diễn STEM.")
    add_h(doc, "2. Giả thuyết nghiên cứu")
    add_p(
        doc,
        "Nếu kết hợp Face AIoT (NCNN on-device + MQTT) với Xiaozhi (ESP32-S3 + STT/LLM/TTS + MCP→MQTT) "
        "trên các node chấp hành dùng chung broker thì hệ thống sẽ điều khiển được thiết bị nhà thông minh "
        "bằng cả khuôn mặt và giọng nói tiếng Việt, với độ trễ phản hồi giọng nói hướng tới dưới 2 giây "
        "ở điều kiện chuẩn (1 m, tạp âm thấp), đồng thời giữ chi phí và mức riêng tư phù hợp STEM.",
    )

    section_banner("III. PHẠM VI NGHIÊN CỨU")
    add_bullet(doc, "Đối tượng: mô hình bàn thí nghiệm; thành viên đã đăng ký khuôn mặt; người dùng nói lệnh thử nghiệm.")
    add_bullet(doc, "Nội dung: Face AIoT on-device + API identify; Xiaozhi cần Internet; node ESP đọc DHT11, MQ gas, LDR/lửa; điều khiển rơ-le/servo.")
    add_bullet(doc, "Không bao gồm: khóa điện tử công nghiệp, camera cố định ngoài trời, tự host LLM.")
    add_bullet(doc, "Thời gian: khung hồ sơ KHKT năm học 2025–2026 / dự thi 2026–2027 (khoảng 01/08/2026 – nộp hồ sơ).")
    add_bullet(doc, "Địa điểm thực hiện: trường học và/hoặc tại nhà dưới giám sát GVHD.")

    section_banner("IV. PHƯƠNG PHÁP VÀ NỘI DUNG NGHIÊN CỨU")
    add_p(doc, "Phương pháp:", bold=True, first_line=False)
    add_bullet(doc, "Nghiên cứu tài liệu: ESP32-S3, MQTT, NCNN/MobileFaceNet, Xiaozhi STT/LLM/TTS, MCP.")
    add_bullet(doc, "So sánh phương án: chỉ app / Raspberry Pi+camera / Face AIoT+Xiaozhi+MQTT — chọn phương án 3.")
    add_bullet(doc, "Thiết kế kỹ thuật: sơ đồ khối, sơ đồ chân, topic MQTT, luồng Face và luồng Xiaozhi.")
    add_bullet(doc, "Chế tạo nguyên mẫu: lắp mô hình, nạp firmware, cấu hình Wi-Fi/MQTT, đăng ký mặt, kịch bản Xiaozhi.")
    add_bullet(doc, "Thực nghiệm – đo đạc: MANUAL/AUTO; nhận diện mở cửa; tỷ lệ đúng và độ trễ theo khoảng cách–tạp âm.")
    add_p(doc, "Nội dung chính:", bold=True, first_line=False, space_before=4)
    add_bullet(doc, "Nội dung 1: Khảo sát nhu cầu và lựa chọn giải pháp kỹ thuật.")
    add_bullet(doc, "Nội dung 2: Lắp mô hình, firmware AUTO/MANUAL, OLED, cảm biến.")
    add_bullet(doc, "Nội dung 3: App Face AIoT — auth, đăng ký mặt, unlock realtime → MQTT.")
    add_bullet(doc, "Nội dung 4: Xiaozhi STT/LLM/TTS, MCP→MQTT, kịch bản ngữ cảnh tiếng Việt.")
    add_bullet(doc, "Nội dung 5: Đo số liệu, hoàn thiện PL3, nhật ký, kê khai AI, poster và hồ sơ nộp.")

    section_banner("V. TIẾN ĐỘ / KẾ HOẠCH THỰC HIỆN")
    add_table(
        doc,
        ["Giai đoạn", "Thời gian", "Nội dung chính"],
        [
            ["1. Khảo sát & chọn phương án", "01–25/08/2026", "Khảo sát nhu cầu; so sánh 3 phương án; chốt Face AIoT + Xiaozhi"],
            ["2. Lắp mô hình & firmware", "26/08–30/09/2026", "Sơ đồ chân ESP; Wi-Fi/MQTT; rule AUTO/MANUAL; OLED"],
            ["3. Face AIoT app", "01–15/10/2026", "Auth, đăng ký mặt, unlock realtime, điều khiển nhà"],
            ["4. Xiaozhi & đo giọng nói", "16–31/10/2026", "STT/LLM/TTS, MCP→MQTT; đo tỷ lệ đúng / độ trễ"],
            ["5. Hồ sơ & hoàn thiện", "01–15/11/2026", "PL3, nhật ký, kê khai AI, poster, đối chiếu tiêu chí STEM"],
        ],
        col_widths=[4.5, 3.5, 8.0],
    )
    add_p(
        doc,
        "Ghi chú: Tiến độ chi tiết từng việc được ghi trong Phụ lục V — Nhật ký nghiên cứu "
        "(06_PL_V_Nhat_ky_nghien_cuu.docx). Người hướng dẫn xác nhận định kỳ ít nhất 01 lần/tháng.",
        italic=True,
        size=11,
        first_line=False,
    )

    section_banner("VI. BÁO CÁO KẾT QUẢ TÓM TẮT (không quá 300 từ)")
    add_p(
        doc,
        "Nhóm đã hoàn thành nguyên mẫu nhà thông minh Face AIoT tích hợp trợ lý AI Xiaozhi và kiểm chứng trên mô hình bàn thí nghiệm. "
        "Hai kênh điều khiển bổ sung nhau: (1) ứng dụng di động nhận diện khuôn mặt realtime bằng NCNN trên thiết bị, so khớp 1:N và gửi MQTT mở cửa khi đạt ngưỡng tin cậy; "
        "(2) Xiaozhi trên ESP32-S3 hiểu lệnh tiếng Việt qua STT/LLM/TTS và MCP, điều khiển đèn–quạt–cửa/rèm, đọc cảm biến môi trường. "
        "Node ESP đọc DHT11, MQ gas, LDR/lửa; hỗ trợ chế độ MANUAL và AUTO theo rule cảm biến, cảnh báo gas; nguồn điều khiển thấp áp, tải 220 V qua rơ-le cách ly. "
        "Kết quả thử nghiệm chính: MQTT MANUAL/AUTO phản hồi đúng trên thiết bị thật; nhận diện mở cửa hoạt động kèm cooldown; "
        "ở khoảng cách 1 m và tạp âm thấp, tỷ lệ thực thi lệnh giọng nói khoảng 93,3% với độ trễ trung bình khoảng 1,62 giây (hướng tới dưới 2 giây); "
        "ở 3 m hoặc tạp âm cao tỷ lệ giảm (khoảng 70% / 60%); kịch bản ngữ cảnh đạt khoảng 80–90% tùy độ phức tạp. "
        "Sản phẩm phù hợp trình diễn STEM, không phụ thuộc chìa khóa vật lý, Xiaozhi ưu tiên riêng tư hơn camera cố định. "
        "Hướng tiếp theo: chống spoofing khuôn mặt, nhật ký ra vào, khóa điện từ và cải thiện STT trong môi trường ồn.",
    )
    add_p(
        doc,
        "(Đoạn tóm tắt trên ≤ 300 từ; chi tiết số liệu xem báo cáo STEM / Phụ lục III kỹ thuật và nhật ký Phụ lục V.)",
        italic=True,
        size=11,
        first_line=False,
        space_after=6,
    )
    add_image(
        doc,
        local.get("ui_dieu_khien_nha.png"),
        width_cm=7.0,
        caption="Hình KH.2. Minh họa sản phẩm — giao diện Điều khiển nhà (Ảnh HS tự chụp màn hình).",
    )
    add_image(
        doc,
        local.get("ui_dang_ky_mat.png"),
        width_cm=8.0,
        caption="Hình KH.3. Minh họa sản phẩm — đăng ký khuôn mặt (Ảnh HS tự chụp màn hình).",
    )

    section_banner("VII. KINH PHÍ VÀ NGUỒN LỰC (DỰ KIẾN)")
    add_table(
        doc,
        ["Hạng mục", "Mô tả", "Ghi chú"],
        [
            ["Phần cứng", "ESP32-S3 (Xiaozhi), ESP32/ESP8266 node, OLED, DHT11, MQ gas, LDR, rơ-le, servo", "Tận dụng / mua linh kiện STEM"],
            ["Phần mềm", "Flutter, NCNN, firmware Arduino, Node.js MCP bridge, MQTT broker", "Mã nguồn mở / miễn phí"],
            ["AI dịch vụ", "STT/LLM/TTS phía máy chủ Xiaozhi (theo cấu hình dự án)", "Theo hạn mức tài khoản"],
            ["Thiết bị sẵn có", "Điện thoại, máy tính, nguồn 5 V", "Tận dụng"],
            ["In ấn hồ sơ", "Báo cáo, phiếu, poster theo quy định cuộc thi", "Theo hướng dẫn Sở/Bộ"],
        ],
        col_widths=[3.5, 8.5, 4.0],
    )

    section_banner("VIII. TÀI LIỆU THAM KHẢO")
    for r in [
        "1. Espressif — ESP32-S3 Technical Reference Manual / Datasheet.",
        "2. OASIS — MQTT Version 3.1.1 / 5.0.",
        "3. Tencent NCNN; MobileFaceNet / face embedding cosine matching.",
        "4. XiaoZhi AI — xiaozhi-esp32; Anthropic MCP specification.",
        "5. Flutter Camera / FFI documentation; datasheet DHT11, MQ-2.",
        "6. Công văn 7292/BGDĐT-GDPT và các phụ lục mẫu hồ sơ KHKT/STEM.",
    ]:
        add_p(doc, r, first_line=False, size=12, space_after=2)

    add_p(doc, "…………, ngày …… tháng …… năm 2026", align="right", first_line=False, space_before=14)
    add_table(
        doc,
        ["GIÁO VIÊN HƯỚNG DẪN", "HỌC SINH THỰC HIỆN"],
        [
            ["(Ký, ghi rõ họ tên)\n\n\n................................", "(Ký, ghi rõ họ tên)\n\n\n................................"],
        ],
        col_widths=[8.0, 8.0],
    )

    out = OUT / "11_KE_HOACH_NGHIEN_CUU_Face_AIoT_Xiaozhi.docx"
    doc.save(str(out))
    print("Saved", out)


# ── 10 copy PL VII gốc + CV PDF ────────────────────────────────────
def copy_references():
    src7 = PL_BASE / "CẬP NHẬT PHỤ LỤC CỦA BỘ" / "2027 Phu luc VII.docx"
    if src7.exists():
        shutil.copy2(src7, OUT / "10_PL_VII_Huong_dan_poster_mau_Bo.docx")
    cv = PL_BASE / "CV số 7292 BGDĐT-GDPT về Thi KHKT.pdf"
    if cv.exists():
        shutil.copy2(cv, OUT / "00b_CV_7292_BGDĐT_GDPT_Thi_KHKT.pdf")
    # official 2027 IV/V blanks for khách đối chiếu
    for name, dst in [
        ("2027 Phu luc IV.docx", "05b_PL_IV_2027_mau_trang_Bo.docx"),
        ("2027 Phu luc V.docx", "06b_PL_V_2027_mau_trang_Bo.docx"),
    ]:
        p = PL_BASE / "CẬP NHẬT PHỤ LỤC CỦA BỘ" / name
        if p.exists():
            shutil.copy2(p, OUT / dst)


def write_guide():
    text = f"""HƯỚNG DẪN HỒ SƠ GỬI KHÁCH — FACE AIOT + NHÀ THÔNG MINH AI XIAOZHI
================================================================
Theo phụ lục Công văn 7292/BGDĐT-GDPT và mẫu báo cáo STEM trong docs/

Tên dự án:
{TEN_DU_AN}

Lĩnh vực: {LINH_VUC}

DANH MỤC FILE TRONG FOLDER (đã điền nội dung kỹ thuật; để trống thông tin HS/trường để khách điền):
------------------------------------------------------------------------------------------------
00_HUONG_DAN_NOP_HO_SO.txt
00b_CV_7292_BGDĐT_GDPT_Thi_KHKT.pdf          → Công văn gốc (tham chiếu)

01_PL_IA_B_Dang_ky_du_thi.docx               → Đăng ký dự thi KHKT + STEM (đã điền tên dự án)
02_PL_II_Thuyet_minh_don_vi.docx             → Thuyết minh đơn vị (trường điền số liệu + ký)
03_PL3_Bao_cao_ket_qua_du_an_ky_thuat.docx   → Báo cáo kết quả dự án KỸ THUẬT (≤15 trang, không tên HS/trường)
04_PL_IV_Tieu_chi_STEM_tu_doi_chieu.docx     → Tự đối chiếu tiêu chí STEM
04b_PL_IV_Tieu_chi_STEM_mau_Bo.docx          → Mẫu tiêu chí Bộ (nếu có)
05_PL_IV_2027_Phieu_hoc_sinh_IVa_d.docx      → Phiếu IVa–IVd (đã điền tên dự án + gợi ý rủi ro/IVd mặt)
05b_PL_IV_2027_mau_trang_Bo.docx             → Mẫu trống Bộ
06_PL_V_Nhat_ky_nghien_cuu.docx              → Nhật ký + minh chứng (đã có tiến độ mẫu)
06b_PL_V_2027_mau_trang_Bo.docx              → Mẫu trống Bộ
07_PL7_Phieu_khai_bao_cong_nghe_so_AI.docx   → Kê khai công nghệ số / AI
08_PL8_Poster_dien_tu_04_trang.pdf           → Poster điện tử 04 trang (không tên HS/trường)
09_BAO_CAO_STEM_Face_AIoT_Xiaozhi.docx       → Báo cáo STEM đầy đủ (Face + Xiaozhi)
09b_...mau_cu.docx / 09c_...Xiaozhi.docx     → Bản tham chiếu gốc trong repo
10_PL_VII_Huong_dan_poster_mau_Bo.docx       → Hướng dẫn poster Bộ
11_KE_HOACH_NGHIEN_CUU_Face_AIoT_Xiaozhi.docx → Kế hoạch nghiên cứu (có Mục VI báo kết quả tóm tắt ≤300 từ)
anh_minh_hoa/                                → Ảnh dùng trong báo cáo/poster

VIỆC KHÁCH / GVHD CẦN ĐIỀN TRƯỚC KHI NỘP:
- Họ tên HS, ĐDCN, ngày sinh, lớp, trường, KQ học tập/rèn luyện, GVHD (PL IA/B, IVa, PL V, PL7)
- Số liệu đơn vị dự thi và chữ ký/đóng dấu (PL II)
- Ký IVb, IVd (người đăng ký khuôn mặt / phụ huynh nếu vị thành niên)
- Rà PL3 ≤ 15 trang; xuất PDF theo hướng dẫn Sở (nếu có)
- Poster: chỉ dùng bản không có tên HS/trường; không QR/link

Chạy lại toàn bộ:
  python docs/tao_ho_so_face_aiot_xiaozhi.py
"""
    path = OUT / "00_HUONG_DAN_NOP_HO_SO.txt"
    path.write_text(text, encoding="utf-8")
    print("Guide:", path)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    local = prepare_images()
    build_pl1()
    build_pl2()
    build_pl3(local)
    build_pl4_stem()
    build_pl4_phieu()
    build_pl5()
    build_pl7()
    build_pl8(local)
    build_bao_cao_stem(local)
    build_ke_hoach(local)
    copy_references()
    write_guide()
    print("\nDONE →", OUT)
    for p in sorted(OUT.rglob("*")):
        if p.is_file():
            print(f"  {p.relative_to(OUT)}  ({p.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
