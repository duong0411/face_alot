# -*- coding: utf-8 -*-
"""PHỤ LỤC 6 — Phiếu khai báo sử dụng công nghệ số, trí tuệ nhân tạo (CV 7292)."""
from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = Path(r"D:\duongpv\face_alot")
OUT_HOSO = ROOT / "HO_SO_GUI_KHACH_FaceAIoT_Xiaozhi"
OUT_DOCS = ROOT / "docs"
OUT_NAME = "06_PL6_Phieu_khai_bao_cong_nghe_so_AI.docx"

TEN_DU_AN = (
    "Nhà thông minh tích hợp nhận diện khuôn mặt và "
    "điều khiển IoT qua ứng dụng di động (Face AIoT)"
)
LINH_VUC = "Hệ thống nhúng và Phần mềm hệ thống / Khoa học máy tính – IoT – Trí tuệ nhân tạo"
HS1, HS1_LOP = "Nguyễn Tuấn Anh", "12A1"
HS2, HS2_LOP = "Lê Chí Quốc", "11A1"
GVHD = "Nguyễn Thị Viên"
TRUONG = "Trường THPT A Nguyễn Khuyến"
DON_VI = "Trường THPT A Nguyễn Khuyến — Sở GDĐT tỉnh Ninh Bình"


def set_run_font(run, size=13, bold=False, italic=False, name="Times New Roman"):
    run.font.name = name
    run.bold = bold
    run.italic = italic
    run.font.size = Pt(size)
    rPr = run._element.get_or_add_rPr()
    rFonts = rPr.find(qn("w:rFonts"))
    if rFonts is None:
        rFonts = OxmlElement("w:rFonts")
        rPr.append(rFonts)
    for attr in ("w:ascii", "w:hAnsi", "w:eastAsia", "w:cs"):
        rFonts.set(qn(attr), name)


def shade_cell(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), fill)
    tcPr.append(shd)


def add_p(doc, text="", *, center=False, bold=False, italic=False, size=13, after=6, before=0):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER if center else WD_ALIGN_PARAGRAPH.JUSTIFY
    p.paragraph_format.space_before = Pt(before)
    p.paragraph_format.space_after = Pt(after)
    p.paragraph_format.line_spacing = 1.15
    p.paragraph_format.first_line_indent = Cm(0)
    run = p.add_run(text)
    set_run_font(run, size=size, bold=bold, italic=italic)
    return p


def set_cell(cell, text, *, bold=False, size=11, center=False):
    cell.text = ""
    p = cell.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER if center else WD_ALIGN_PARAGRAPH.LEFT
    run = p.add_run(text)
    set_run_font(run, size=size, bold=bold)


def build():
    doc = Document()
    sec = doc.sections[0]
    sec.page_width = Cm(21.0)
    sec.page_height = Cm(29.7)
    sec.top_margin = Cm(2.0)
    sec.bottom_margin = Cm(2.0)
    sec.left_margin = Cm(2.5)
    sec.right_margin = Cm(2.0)

    normal = doc.styles["Normal"]
    normal.font.name = "Times New Roman"
    normal.font.size = Pt(13)

    add_p(doc, "PHỤ LỤC 6", center=True, bold=True, size=14, after=2)
    add_p(
        doc,
        "PHIẾU KHAI BÁO SỬ DỤNG CÔNG NGHỆ SỐ, TRÍ TUỆ NHÂN TẠO",
        center=True,
        bold=True,
        size=13,
        after=2,
    )
    add_p(
        doc,
        "(phải kê khai nếu có sử dụng công nghệ số, trí tuệ nhân tạo)",
        center=True,
        italic=True,
        size=12,
        after=12,
    )

    add_p(doc, "I. THÔNG TIN CHUNG", bold=True, size=13, after=8, before=4)
    for line in [
        f"1. Tên dự án dự thi: {TEN_DU_AN}",
        f"2. Lĩnh vực dự thi: {LINH_VUC}",
        f"3. Họ và tên học sinh/nhóm trưởng: {HS1} (Lớp {HS1_LOP})",
        f"4. Họ và tên thành viên (nếu có): {HS2} (Lớp {HS2_LOP})",
        f"5. Họ và tên người hướng dẫn nghiên cứu: {GVHD}",
        f"6. Cơ sở giáo dục: {TRUONG}",
        f"7. Đơn vị dự thi: {DON_VI}",
    ]:
        add_p(doc, line, after=4)

    add_p(
        doc,
        "II. KÊ KHAI SỬ DỤNG CÔNG NGHỆ SỐ, TRÍ TUỆ NHÂN TẠO",
        bold=True,
        size=13,
        after=8,
        before=10,
    )
    add_p(doc, "1. Công cụ sử dụng", bold=True, size=12, after=6)

    headers = [
        "TT",
        "Tên công cụ công nghệ số, trí tuệ nhân tạo",
        "Công việc/nội dung sử dụng công cụ công nghệ số, trí tuệ nhân tạo",
        "Mức độ sử dụng công cụ công nghệ số, trí tuệ nhân tạo",
        "Ghi chú",
    ]
    rows = [
        [
            "1",
            "Flutter + Dart FFI + NCNN (YuNet / MobileFaceNet)",
            "Ứng dụng Face AIoT: UI, detect/embedding khuôn mặt on-device, gửi lệnh mở cửa MQTT",
            "Chính (cốt lõi sản phẩm)",
            "HS thực hiện; mô hình nhẹ chạy trên điện thoại",
        ],
        [
            "2",
            "AI Xiaozhi (ESP32-S3) + STT / LLM / TTS",
            "Điều khiển nhà bằng giọng nói tiếng Việt; phản hồi loa; gọi tool MCP",
            "Chính (cốt lõi sản phẩm)",
            "Máy chủ AI Xiaozhi; không dùng camera trên Xiaozhi",
        ],
        [
            "3",
            "MCP (JSON-RPC) + Node.js bridge + MQTT",
            "Ánh xạ tool Xiaozhi → topic cmnd/esp32_* (đèn, bơm, quạt, cửa, đọc cảm biến)",
            "Chính",
            "Chip ID firmware: esp32",
        ],
        [
            "4",
            "Arduino / ESP32 firmware (SmartHome_ESP32)",
            "Node chấp hành: DHT11, MQ gas, HC-SR04, mưa/đất, OLED, rơ-le, servo, AUTO/MANUAL",
            "Chính",
            "Wi-Fi portal double-reset",
        ],
        [
            "5",
            "Backend API + MongoDB + MQTT broker",
            "Auth, gallery khuôn mặt 1:N, identify; broker WSS realtime",
            "Chính",
            "Docker / cloud",
        ],
        [
            "6",
            "Công cụ soạn thảo / AI hội thoại hỗ trợ (Cursor, ChatGPT… nếu có)",
            "Gợi ý khung báo cáo, bảng nhật ký, chỉnh code firmware/app theo yêu cầu kỹ thuật",
            "Hỗ trợ biên soạn / lập trình",
            "HS chịu trách nhiệm nội dung & số liệu; không dùng AI bịa kết quả đo",
        ],
        [
            "7",
            "Excel / sơ đồ khối / ảnh minh họa",
            "Bảng đo thử nghiệm, sơ đồ chân, hình mô hình và UI",
            "Hỗ trợ",
            "Chú thích nguồn ảnh do HS tự chụp",
        ],
    ]

    table = doc.add_table(rows=1 + len(rows), cols=5)
    table.style = "Table Grid"
    table.autofit = True
    for i, h in enumerate(headers):
        set_cell(table.rows[0].cells[i], h, bold=True, size=10, center=True)
        shade_cell(table.rows[0].cells[i], "D9E2F3")
    for r_i, row in enumerate(rows):
        for c_i, val in enumerate(row):
            set_cell(table.rows[r_i + 1].cells[c_i], val, size=10, center=(c_i == 0))

    add_p(doc, "", after=4)
    add_p(doc, "2. Minh chứng sử dụng trí tuệ nhân tạo", bold=True, size=12, after=6)
    add_p(
        doc,
        "Nếu Dự án có sử dụng trí tuệ nhân tạo (AI) hoặc công cụ chạy trên nền AI, vui lòng "
        "cung cấp Nhật ký câu lệnh (Prompt Log) chứa các câu lệnh và phản hồi từ AI hoặc công cụ "
        "chạy trên nền AI được sử dụng (đính kèm trang phụ nếu cần). Xóa các câu lệnh có chứa "
        "thông tin nhận dạng cá nhân. Nếu không có quyền truy cập vào nhật ký câu lệnh, vui lòng "
        "cung cấp tóm tắt các câu lệnh và phản hồi liên quan đến dự án.",
        after=8,
        size=12,
    )

    add_p(doc, "Tên công cụ: AI Xiaozhi (STT/LLM/TTS) + MCP bridge; AI hội thoại hỗ trợ soạn thảo (nếu có).", after=6)
    add_p(doc, "Nhật ký câu lệnh / tóm tắt các câu lệnh và phản hồi:", bold=True, after=4)

    prompts = [
        "A. Trợ lý giọng nói Xiaozhi (sản phẩm):",
        "• Câu lệnh người dùng: «Mở cửa và đọc nhiệt độ.»",
        "• Phản hồi hệ thống: LLM gọi tool control_door(action=open) và read_temperature / "
        "read_home_status → bridge publish MQTT cmnd/esp32_door_livingroom1/POWER=ON và đọc "
        "tele/esp32_vitals (nhiệt độ) → TTS trả lời bằng tiếng Việt.",
        "• Câu lệnh: «Tôi đi ngủ.» → kịch bản ngữ cảnh: tắt đèn, kiểm tra cảm biến, phản hồi loa.",
        "",
        "B. AI hội thoại hỗ trợ biên soạn / lập trình (nếu dùng):",
        "• Yêu cầu: gợi ý khung báo cáo dự án kỹ thuật (vấn đề – thiết kế – chế tạo – kết quả) "
        "theo CV 7292/BGDĐT-GDPT và mẫu STEM tỉnh Ninh Bình.",
        "• Phản hồi: khung mục; nhóm tự viết lại bằng số liệu và thử nghiệm thực tế của dự án.",
        "• Yêu cầu: gợi ý bảng pinout SmartHome_ESP32 (GPIO đèn/bơm/quạt, HC-SR04, gas, OLED) "
        "và topic MQTT chip esp32.",
        "• Phản hồi: bảng chân/topic; nhóm đối chiếu với firmware đã nạp và log MQTT thực tế.",
        "• Cam kết: không dùng AI để bịa số liệu đo; mô hình nhận diện và Xiaozhi chạy theo "
        "cấu hình đã kiểm thử dưới sự giám sát GVHD.",
    ]
    for line in prompts:
        add_p(doc, line, after=2, size=12)

    add_p(doc, "", after=10)
    # Chữ ký 2 cột
    sig = doc.add_table(rows=4, cols=2)
    sig.autofit = True
    left = [
        "Người hướng dẫn nghiên cứu",
        "(Ký, ghi rõ họ tên)",
        "",
        GVHD,
    ]
    right = [
        "………, ngày …… tháng …… năm 202…",
        "Học sinh/Trưởng nhóm",
        "(Ký, ghi rõ họ tên)",
        f"{HS1}\n{HS2}",
    ]
    for i in range(4):
        set_cell(sig.rows[i].cells[0], left[i], bold=(i == 0), size=12, center=True)
        set_cell(sig.rows[i].cells[1], right[i], bold=(i in (0, 1)), size=12, center=True)

    add_p(doc, "", after=8)
    add_p(
        doc,
        "Cam kết: Học sinh chịu trách nhiệm về tính trung thực của dữ liệu, kết quả và nội dung trình bày.",
        italic=True,
        size=12,
        after=4,
    )

    OUT_HOSO.mkdir(parents=True, exist_ok=True)
    OUT_DOCS.mkdir(parents=True, exist_ok=True)
    p1 = OUT_HOSO / OUT_NAME
    p2 = OUT_DOCS / OUT_NAME
    doc.save(p1)
    doc.save(p2)
    print("Wrote:", p1)
    print("Wrote:", p2)
    return p1, p2


if __name__ == "__main__":
    build()
