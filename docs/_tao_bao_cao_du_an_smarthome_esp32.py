# -*- coding: utf-8 -*-
"""Báo cáo dự án nhà thông minh — firmware SmartHome_ESP32 + Face AIoT + Xiaozhi.

Yêu cầu trình bày: tóm tắt ≤ 300 từ; toàn báo cáo thuyết minh khoảng 10–15 trang
(Times New Roman 13, giãn dòng 1.5, lề trái 3 cm / phải–trên–dưới 2 cm).
"""
from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = Path(r"D:\duongpv\face_alot")
DOCS = ROOT / "docs"
IMG = DOCS / "images"
OUT_HOSO = ROOT / "HO_SO_GUI_KHACH_FaceAIoT_Xiaozhi"
OUT_NAME = "12_BAO_CAO_DU_AN_Nha_Thong_Minh_SmartHome_ESP32.docx"

LINH_VUC = "Khoa học máy tính — IoT — Trí tuệ nhân tạo ứng dụng"
HS1, HS1_LOP = "Nguyễn Tuấn Anh", "12A1"
HS2, HS2_LOP = "Lê Chí Quốc", "11A1"
GVHD = "Nguyễn Thị Viên"
TRUONG = "Trường THPT A Nguyễn Khuyến"
SO_GDDT = "SỞ GIÁO DỤC VÀ ĐÀO TẠO TỈNH NINH BÌNH"
NAVY = RGBColor(0x1F, 0x4E, 0x79)
GRAY = RGBColor(0x55, 0x55, 0x55)

# Tóm tắt ≤ 300 từ (đếm theo khoảng trắng)
TOM_TAT = (
    "Dự án Face AIoT xây dựng mô hình nhà thông minh kết hợp ba kênh điều khiển: "
    "nhận diện khuôn mặt trên điện thoại để mở cửa qua MQTT; điều khiển thủ công hoặc "
    "tự động trên ứng dụng theo cảm biến; và trợ lý giọng nói tiếng Việt Xiaozhi "
    "(ESP32-S3) gọi công cụ MCP để điều khiển cùng node chấp hành. "
    "Node dùng firmware SmartHome_ESP32 (Chip ID MQTT esp32) với OLED, DHT11, "
    "cảm biến quang, MQ gas, HC-SR04 lọc Kalman, mưa và đất, còi, rơ-le đèn–bơm–quạt, "
    "servo cửa; hỗ trợ AUTO/MANUAL và Wi-Fi portal cấu hình mạng. "
    "Broker MQTT WSS nối app, bridge Xiaozhi và board. "
    "Sản phẩm phục vụ STEM tỉnh Ninh Bình: cảm biến, AI nhẹ, IoT và an toàn điện. "
    "Nhóm đã kiểm chứng luồng mở cửa bằng khuôn mặt, rule AUTO và lệnh giọng nói "
    "trên mô hình bàn thí nghiệm dưới sự giám sát giáo viên hướng dẫn."
)


def set_run_font(run, size=13, bold=False, italic=False, color=None, name="Times New Roman"):
    run.font.name = name
    run.bold = bold
    run.italic = italic
    run.font.size = Pt(size)
    if color is not None:
        run.font.color.rgb = color
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


def setup_doc():
    doc = Document()
    for section in doc.sections:
        section.page_width = Cm(21.0)
        section.page_height = Cm(29.7)
        section.top_margin = Cm(2.0)
        section.bottom_margin = Cm(2.0)
        section.left_margin = Cm(3.0)
        section.right_margin = Cm(2.0)
        footer = section.footer
        footer.is_linked_to_previous = False
        p = footer.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run("Báo cáo dự án Face AIoT — SmartHome ESP32    ·    Trang ")
        set_run_font(r, size=10, italic=True, color=NAVY)
        run = p.add_run()
        set_run_font(run, size=10, italic=True, color=NAVY)
        fld_begin = OxmlElement("w:fldChar")
        fld_begin.set(qn("w:fldCharType"), "begin")
        instr = OxmlElement("w:instrText")
        instr.set(qn("xml:space"), "preserve")
        instr.text = " PAGE "
        fld_end = OxmlElement("w:fldChar")
        fld_end.set(qn("w:fldCharType"), "end")
        run._r.append(fld_begin)
        run._r.append(instr)
        run._r.append(fld_end)

    normal = doc.styles["Normal"]
    normal.font.name = "Times New Roman"
    normal.font.size = Pt(13)
    rPr = normal.element.get_or_add_rPr()
    rFonts = rPr.find(qn("w:rFonts"))
    if rFonts is None:
        rFonts = OxmlElement("w:rFonts")
        rPr.append(rFonts)
    for attr in ("w:ascii", "w:hAnsi", "w:eastAsia", "w:cs"):
        rFonts.set(qn(attr), "Times New Roman")
    pf = normal.paragraph_format
    pf.line_spacing = 1.5
    pf.space_after = Pt(6)
    return doc


def add_p(doc, text="", *, align="justify", bold=False, italic=False, size=13,
          before=0, after=6, indent=True, color=None, center=False):
    p = doc.add_paragraph()
    if center or align == "center":
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    elif align == "left":
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    else:
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p.paragraph_format.space_before = Pt(before)
    p.paragraph_format.space_after = Pt(after)
    p.paragraph_format.line_spacing = 1.5
    if indent and align == "justify" and text:
        p.paragraph_format.first_line_indent = Cm(1.0)
    run = p.add_run(text)
    set_run_font(run, size=size, bold=bold, italic=italic, color=color)
    return p


def add_h(doc, text, level=1):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    p.paragraph_format.space_before = Pt(14 if level == 1 else 10)
    p.paragraph_format.space_after = Pt(8)
    p.paragraph_format.first_line_indent = Cm(0)
    run = p.add_run(text)
    set_run_font(run, size=14 if level == 1 else 13, bold=True, color=NAVY)
    return p


def add_fig(doc, path: Path, caption: str, width_cm=13.5):
    if not path.exists():
        add_p(doc, f"[Thiếu ảnh: {path.name}]", italic=True, color=GRAY, indent=False)
        return
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.first_line_indent = Cm(0)
    run = p.add_run()
    run.add_picture(str(path), width=Cm(width_cm))
    cap = doc.add_paragraph()
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap.paragraph_format.space_after = Pt(10)
    cap.paragraph_format.first_line_indent = Cm(0)
    r = cap.add_run(caption)
    set_run_font(r, size=11, italic=True, color=GRAY)


def add_table(doc, headers, rows, font_size=11):
    table = doc.add_table(rows=1 + len(rows), cols=len(headers))
    table.style = "Table Grid"
    for i, h in enumerate(headers):
        cell = table.rows[0].cells[i]
        cell.text = ""
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = p.add_run(h)
        set_run_font(run, size=font_size, bold=True, color=RGBColor(0xFF, 0xFF, 0xFF))
        shade_cell(cell, "1F4E79")
    for r_i, row in enumerate(rows):
        for c_i, val in enumerate(row):
            cell = table.rows[r_i + 1].cells[c_i]
            cell.text = ""
            p = cell.paragraphs[0]
            run = p.add_run(str(val))
            set_run_font(run, size=font_size)
            if r_i % 2 == 1:
                shade_cell(cell, "F2F2F2")
    doc.add_paragraph()


def word_count(text: str) -> int:
    return len(text.replace("\n", " ").split())


def build():
    assert word_count(TOM_TAT) <= 300, f"Tóm tắt vượt 300 từ: {word_count(TOM_TAT)}"

    doc = setup_doc()

    # ── Bìa ──────────────────────────────────────────────
    add_p(doc, SO_GDDT, center=True, bold=True, size=14, indent=False, after=2)
    add_p(doc, TRUONG.upper(), center=True, bold=True, size=13, indent=False, after=2)
    add_p(
        doc,
        "CUỘC THI KHOA HỌC KỸ THUẬT / NGÀY HỘI STEM CẤP TỈNH\nNĂM HỌC 2026 – 2027",
        center=True,
        bold=True,
        size=12,
        indent=False,
        after=16,
    )
    add_p(doc, "BÁO CÁO DỰ ÁN", center=True, bold=True, size=18, indent=False, after=6, color=NAVY)
    add_p(
        doc,
        "NHÀ THÔNG MINH TÍCH HỢP NHẬN DIỆN KHUÔN MẶT\n"
        "VÀ ĐIỀU KHIỂN IoT QUA ỨNG DỤNG DI ĐỘNG\n"
        "(Face AIoT)\n"
        "— Firmware SmartHome ESP32 & trợ lý giọng nói Xiaozhi —",
        center=True,
        bold=True,
        size=14,
        indent=False,
        after=16,
    )
    add_p(doc, f"Lĩnh vực: {LINH_VUC}", center=True, italic=True, size=12, indent=False)
    add_p(doc, "Địa điểm: Tỉnh Ninh Bình", center=True, size=12, indent=False, after=4)
    add_p(
        doc,
        "Theo Quyết định cử SP dự thi KHKT/STEM cấp tỉnh (THPT A Nguyễn Khuyến)",
        center=True,
        size=11,
        indent=False,
        after=20,
    )

    add_p(doc, "Thông tin nhóm dự án:", bold=True, indent=False, after=4)
    for line in [
        f"• Học sinh: {HS1} (Lớp {HS1_LOP}); {HS2} (Lớp {HS2_LOP})",
        f"• Giáo viên hướng dẫn: {GVHD}",
        f"• Cơ sở giáo dục: {TRUONG}",
        "• Sản phẩm kỹ thuật: mô hình nhà thông minh ESP32 (chip MQTT esp32), "
        "app Face AIoT (Flutter/NCNN), cầu MCP Xiaozhi → MQTT",
    ]:
        add_p(doc, line, indent=False, after=2, size=12)

    add_p(
        doc,
        "Ghi chú trình bày: Báo cáo thuyết minh khoảng 10–15 trang; phần I. Tóm tắt không quá 300 từ.",
        italic=True,
        size=11,
        indent=False,
        after=6,
        color=GRAY,
    )

    doc.add_page_break()

    # ── Mục lục ──────────────────────────────────────────
    add_h(doc, "MỤC LỤC")
    for item in [
        "I. Tóm tắt dự án (≤ 300 từ)",
        "II. Lý do chọn đề tài",
        "III. Mục tiêu nghiên cứu",
        "IV. Đối tượng và phạm vi",
        "V. Nội dung và phương pháp",
        "VI. Kiến trúc hệ thống",
        "VII. Phần cứng — firmware SmartHome_ESP32",
        "VIII. Phần mềm ứng dụng Face AIoT & Xiaozhi",
        "IX. Kết quả thử nghiệm",
        "X. Thảo luận hạn chế và bài học kỹ thuật",
        "XI. Ý nghĩa STEM và khả năng ứng dụng",
        "XII. Kết luận và hướng phát triển",
        "XIII. Tài liệu tham khảo",
        "Phụ lục A. Bảng chân và topic MQTT (tóm tắt)",
    ]:
        add_p(doc, item, indent=False, after=2)

    doc.add_page_break()

    # ── I. Tóm tắt ≤ 300 từ ──────────────────────────────
    add_h(doc, "I. TÓM TẮT DỰ ÁN")
    add_p(doc, TOM_TAT)
    add_p(
        doc,
        f"(Số từ phần tóm tắt: {word_count(TOM_TAT)} / 300)",
        italic=True,
        size=11,
        indent=False,
        color=GRAY,
        after=8,
    )

    # ── II ───────────────────────────────────────────────
    add_h(doc, "II. LÝ DO CHỌN ĐỀ TÀI")
    add_p(
        doc,
        "An ninh cửa ra vào, theo dõi môi trường trong nhà và điều khiển thiết bị bằng "
        "tiếng Việt là nhu cầu thiết thực với nhiều gia đình. Giải pháp thương mại thường "
        "đắt, khóa chặt hệ sinh thái hoặc hỗ trợ tiếng Việt còn hạn chế. Trong khi đó, "
        "học sinh trung học hoàn toàn có thể tiếp cận linh kiện ESP32, cảm biến giá rẻ và "
        "lập trình mobile để dựng một mô hình nhà thông minh có thể trình diễn và đo đạc."
    )
    add_p(
        doc,
        "Nhóm chọn kết hợp ba hướng bổ sung nhau: (1) nhận diện khuôn mặt on-device trên "
        "điện thoại để mở cửa khi đạt ngưỡng tin cậy — người dùng chủ động mở app, không "
        "cần camera cố định trong nhà; (2) điều khiển MANUAL/AUTO theo cảm biến trên cùng "
        "board ESP32; (3) trợ lý Xiaozhi không dùng camera, hiểu câu lệnh tiếng Việt tự nhiên "
        "qua LLM rồi gọi tool MCP xuống MQTT. Cách tiếp cận này ưu tiên riêng tư, chi phí "
        "thấp và tính STEM rõ ràng (cảm biến – mạng – AI nhẹ – an toàn điện)."
    )
    add_p(
        doc,
        "Đề tài được Trường THPT A Nguyễn Khuyến cử tham dự Cuộc thi khoa học kỹ thuật / "
        "Ngày hội STEM cấp tỉnh năm học 2026–2027 theo Quyết định kèm danh sách dự án "
        "«Nhà thông minh tích hợp nhận diện khuôn mặt và điều khiển IoT qua ứng dụng "
        "di động (Face AIoT)», học sinh Nguyễn Tuấn Anh (12A1), Lê Chí Quốc (11A1), "
        "giáo viên hướng dẫn Nguyễn Thị Viên."
    )

    # ── III ──────────────────────────────────────────────
    add_h(doc, "III. MỤC TIÊU NGHIÊN CỨU")
    add_p(
        doc,
        "Mục tiêu chung: thiết kế, chế tạo và kiểm chứng nguyên mẫu nhà thông minh AIoT "
        "trên firmware SmartHome_ESP32, kết nối app Face AIoT và Xiaozhi MCP, đạt độ ổn định "
        "đủ để thuyết trình và giải thích hạn chế trước hội đồng.",
    )
    add_p(doc, "Mục tiêu cụ thể:", bold=True, indent=False, after=4)
    for t in [
        "1. Chế tạo mô hình bàn thí nghiệm với ESP32, cảm biến và actuator ổn định MQTT "
        "(Chip ID esp32).",
        "2. Tích hợp app Face AIoT: đăng ký khuôn mặt, nhận diện realtime, mở cửa khi đạt "
        "ngưỡng cosine / confidence.",
        "3. Hỗ trợ MANUAL và AUTO: tối → đèn; hết nước / đất khô → bơm; mưa → dừng bơm; "
        "nhiệt cao / gas → quạt; gas → còi (và mở cửa nếu bật rule).",
        "4. Kết nối Xiaozhi (STT/LLM/TTS) qua MCP bridge để điều khiển và đọc cảm biến "
        "bằng giọng nói tiếng Việt.",
        "5. Đo / quan sát độ trễ lệnh, tỷ lệ thực thi đúng theo khoảng cách và tạp âm; "
        "ghi nhận nguyên nhân sai.",
    ]:
        add_p(doc, t, indent=False)

    add_p(doc, "Câu hỏi nghiên cứu:", bold=True, indent=False, before=6, after=4)
    add_p(
        doc,
        "Làm thế nào tích hợp nhận diện khuôn mặt trên di động, rule cảm biến trên ESP32 "
        "và trợ lý giọng nói Xiaozhi trên cùng broker MQTT mà vẫn giữ Chip ID, topic và "
        "an toàn điện nhất quán? Độ tin cậy thực thi lệnh thay đổi thế nào khi khoảng cách "
        "nói hoặc tạp âm tăng?",
    )

    # ── IV ───────────────────────────────────────────────
    add_h(doc, "IV. ĐỐI TƯỢNG VÀ PHẠM VI")
    add_p(
        doc,
        "Đối tượng nghiên cứu là mô hình nhà thông minh quy mô bàn thí nghiệm và luồng "
        "điều khiển end-to-end từ người dùng (app / giọng nói) đến actuator. Người dùng "
        "được hiểu là thành viên đã đăng ký khuôn mặt trong gallery (luồng Face) hoặc "
        "người kích hoạt phiên nghe Xiaozhi (luồng giọng nói)."
    )
    add_p(
        doc,
        "Phạm vi phần cứng: board ESP32 chạy firmware SmartHome_ESP32 với Chip ID MQTT "
        "esp32 (khác bản ESP8266 mã 123 trong một số tài liệu cũ). Phạm vi phần mềm: "
        "ứng dụng Flutter Android/iOS, backend auth/identify + MongoDB, MQTT broker WSS, "
        "bridge Node.js MCP. Phạm vi thử nghiệm: phòng học / phòng thí nghiệm, khoảng "
        "cách nói khoảng 1–3 m, vài mức tạp âm; bộ lệnh tiếng Việt đã chuẩn bị."
    )
    add_p(
        doc,
        "Ngoài phạm vi: khóa điện tử công nghiệp, camera ngoài trời cố định, chống giả "
        "mạo khuôn mặt mức sản phẩm thương mại, và tối ưu năng lượng pin cho thiết bị "
        "di động ngoài đời thực. Mọi thao tác rơ-le 220 V đều có giám sát giáo viên hướng dẫn.",
    )

    # ── V ────────────────────────────────────────────────
    add_h(doc, "V. NỘI DUNG VÀ PHƯƠNG PHÁP")
    add_h(doc, "5.1. Nội dung chính", level=2)
    add_p(
        doc,
        "Nhóm lần lượt: khảo sát nhu cầu và tiêu chí; so sánh phương án App / Raspberry Pi "
        "+ camera / Face AIoT + Xiaozhi; lắp mô hình và sơ đồ chân; lập trình firmware "
        "AUTO/MANUAL, portal Wi-Fi, telemetry; hoàn thiện app đăng ký mặt và smart control; "
        "cấu hình Xiaozhi + MCP → MQTT; đo thử và hoàn thiện hồ sơ thuyết minh.",
    )
    add_h(doc, "5.2. Phương pháp", level=2)
    add_p(
        doc,
        "Áp dụng quy trình thiết kế kỹ thuật: nghiên cứu tài liệu (ESP32, MQTT, NCNN, "
        "Xiaozhi, MCP) → thiết kế sơ đồ khối → chế tạo nguyên mẫu → tích hợp phần mềm → "
        "thử nghiệm vòng kín → hiệu chỉnh ngưỡng (gas, mực nước 1–10 cm, cosine nhận diện, "
        "doorHoldSec). Kết quả được đối chiếu đồng thời trên OLED, app và trạng thái "
        "thiết bị thật để giảm sai số quan sát.",
    )
    add_table(
        doc,
        ["Tiêu chí", "Chỉ app điện thoại", "RPi + camera cố định", "Face AIoT + Xiaozhi + ESP32"],
        [
            ["Tiếng Việt tự nhiên", "Trung bình", "Phụ thuộc phần mềm", "Tốt (LLM + STT/TTS)"],
            ["Riêng tư", "Tùy app", "Thấp hơn (camera cố định)", "Cao hơn (Xiaozhi không camera)"],
            ["Chi phí phần cứng", "Trung bình–cao", "Cao", "Thấp–trung bình"],
            ["Mở cửa không chìa", "Cần thao tác", "Tùy thị giác", "Nhận diện trên app + MQTT"],
            ["Điều khiển khi không cầm máy", "Kém", "Tùy kịch bản", "Tốt (nói trực tiếp Xiaozhi)"],
        ],
    )

    # ── VI ───────────────────────────────────────────────
    add_h(doc, "VI. KIẾN TRÚC HỆ THỐNG")
    add_p(
        doc,
        "Hệ thống gồm bốn tầng: (1) thiết bị biên ESP32 đọc cảm biến và điều khiển actuator; "
        "(2) broker MQTT WSS làm cầu realtime; (3) backend API + MongoDB lưu tài khoản và "
        "gallery khuôn mặt; (4) kênh người dùng gồm app Flutter (AI on-device + UI) và "
        "Xiaozhi ESP32-S3 (micro → máy chủ AI → MCP bridge → MQTT).",
    )
    add_table(
        doc,
        ["Thành phần", "Công nghệ / thiết bị", "Vai trò"],
        [
            ["Board IoT", "ESP32 — firmware SmartHome_ESP32", "Cảm biến, actuator, OLED, MQTT chip esp32"],
            ["Cảm biến", "DHT11, MQ gas, quang, HC-SR04, mưa, đất", "Môi trường & mực nước (Kalman)"],
            ["Actuator", "Relay đèn/bơm/quạt, servo cửa, còi", "Điều khiển & cảnh báo"],
            ["App mobile", "Flutter + Dart FFI + NCNN", "UI, nhận diện, smart control"],
            ["AI mặt", "YuNet / MobileFaceNet (NCNN)", "Detect + embedding on-device"],
            ["Giọng nói", "Xiaozhi ESP32-S3 + LLM + MCP", "STT → tool → MQTT → TTS"],
            ["Backend", "API + MongoDB + MQTT WSS", "Auth, gallery, broker realtime"],
        ],
    )
    add_p(
        doc,
        "Luồng mở cửa bằng khuôn mặt: camera stream trên app → convert khung hình → "
        "FaceNcnn.infer (detect + embedding) → API identify so khớp 1:N → nếu accepted thì "
        "publish cmnd/esp32_door_livingroom1/POWER=ON → ESP32 quay servo, giữ doorHoldSec "
        "rồi đóng. Luồng Xiaozhi: người dùng kích hoạt nghe → micro I2S → STT/LLM → "
        "tools/call (ví dụ control_door, read_temperature) → bridge Node.js publish MQTT "
        "cùng chip esp32 → TTS phản hồi loa.",
    )
    add_p(
        doc,
        "Điểm then chốt kỹ thuật là thống nhất Chip ID và tên topic giữa firmware, app và "
        "MCP. Nếu backend MCP vẫn phát lệnh cmnd/123_* trong khi board lắng nghe esp32_*, "
        "lệnh sẽ không tới thiết bị dù MQTT vẫn «online» — đây là lỗi cấu hình đã được "
        "nhóm kiểm tra khi tích hợp.",
    )

    doc.add_page_break()

    # ── VII ──────────────────────────────────────────────
    add_h(doc, "VII. PHẦN CỨNG — FIRMWARE SmartHome_ESP32")
    add_fig(
        doc,
        IMG / "mo_hinh_thuc_te.png",
        "Hình 1. Mô hình nhà thông minh thực tế (Ảnh do học sinh tự chụp).",
        width_cm=14.5,
    )
    add_p(
        doc,
        "Mô hình lắp trong khung dễ quan sát linh kiện khi thuyết trình. Nguồn điều khiển "
        "thấp áp 5 V / 3.3 V; tải 220 V đi qua module rơ-le cách ly. Firmware quản lý chế độ "
        "MANUAL (lệnh MQTT/app/Xiaozhi) và AUTO (rule cảm biến), hiển thị trạng thái trên OLED.",
    )

    add_h(doc, "7.1. Sơ đồ chân chính", level=2)
    add_table(
        doc,
        ["Linh kiện", "GPIO ESP32", "Ghi chú"],
        [
            ["OLED SSD1306 I2C", "SDA 21 / SCL 22", "Trạng thái / rule"],
            ["DHT11", "GPIO4", "Nhiệt độ – độ ẩm"],
            ["Quang (D0)", "GPIO27", "AUTO đèn khi tối"],
            ["Gas MQ (D0)", "GPIO26", "Còi liên tục khi cảnh báo (rule)"],
            ["Còi (buzzer)", "GPIO25", "Gas / hết nước AUTO"],
            ["Relay bơm / đèn", "GPIO32 / GPIO33", "ACTIVE HIGH; IN1=bơm, IN2=đèn"],
            ["Relay quạt", "GPIO19", "Nhiệt cao / gas"],
            ["Đất (A0) / mưa (D0)", "GPIO34 / GPIO35", "Rule bơm"],
            ["HC-SR04 TRIG/ECHO", "GPIO13 / GPIO14", "Mực nước 1–10 cm + Kalman"],
            ["Servo cửa SG90", "GPIO18", "Topic esp32_door_livingroom1"],
        ],
    )

    add_h(doc, "7.2. Rule AUTO và an toàn", level=2)
    add_p(
        doc,
        "Khi AUTO: trời tối theo cảm biến quang → bật đèn; mực nước thấp hoặc đất khô → "
        "bật bơm, nhưng nếu mưa thì dừng bơm; nhiệt cao hoặc gas → bật quạt; gas vượt "
        "ngưỡng và bật rule còi → còi kêu liên tục trong lúc cảnh báo; có thể mở cửa theo "
        "rule gasOpenDoor. Khoảng cách nước cấu hình trên app trong dải 1–10 cm. MANUAL "
        "cho phép người dùng/Xiaozhi bật tắt thiết bị trực tiếp qua MQTT.",
    )
    add_p(
        doc,
        "Wi-Fi portal: double-reset board → SoftAP tên SmartHome → cấu hình tại "
        "http://192.168.4.1. Khi đổi sang mạng mới, cần double-reset để vào portal; "
        "board không tự mở portal chỉ vì SSID cũ mất kết nối theo cơ chế mặc định của firmware.",
    )

    add_h(doc, "7.3. Topic MQTT (Chip ID = esp32)", level=2)
    add_table(
        doc,
        ["Thiết bị / dữ liệu", "Topic chính"],
        [
            ["Đèn", "cmnd/esp32_led1/POWER · tele/esp32_led1/status"],
            ["Bơm", "cmnd/esp32_pump/POWER · tele/esp32_pump/status"],
            ["Quạt", "cmnd/esp32_fan_livingroom/POWER"],
            ["Cửa", "cmnd/esp32_door_livingroom1/POWER"],
            ["Vitals (T/H/gas/…)", "tele/esp32_vitals/status"],
            ["Mode / Rules", "cmnd/esp32_mode/POWER · cmnd/esp32_rules/SET"],
        ],
    )

    # ── VIII ─────────────────────────────────────────────
    add_h(doc, "VIII. PHẦN MỀM ỨNG DỤNG FACE AIOT & XIAOZHI")
    add_h(doc, "8.1. Ứng dụng Face AIoT", level=2)
    add_fig(
        doc,
        IMG / "ui_dieu_khien_nha.png",
        "Hình 2. Giao diện Điều khiển nhà (Ảnh do học sinh tự chụp màn hình).",
        width_cm=13.5,
    )
    add_p(
        doc,
        "Ứng dụng Flutter hiển thị vitals (nhiệt, ẩm, gas, mực nước…), cho phép chuyển "
        "MANUAL/AUTO, chỉnh rule (gồm khoảng cách nước 1–10 cm) và điều khiển thiết bị. "
        "Module nhận diện dùng NCNN qua Dart FFI: detect khuôn mặt và trích embedding "
        "MobileFaceNet ngay trên điện thoại, sau đó gửi vector để identify 1:N trên backend. "
        "Cách làm này giảm phụ thuộc máy chủ ở bước extract đặc trưng và hạn chế gửi ảnh thô.",
    )
    add_fig(doc, IMG / "ui_dang_ky_mat.png", "Hình 3. Đăng ký khuôn mặt thành viên.", 12.0)
    add_fig(doc, IMG / "ui_mo_cua.png", "Hình 4. Mở cửa bằng nhận diện khuôn mặt.", 12.0)
    add_p(
        doc,
        "Đăng ký khuôn mặt được thực hiện có sự đồng ý của người được ghi nhận (Phiếu IVd "
        "trong hồ sơ). Dữ liệu gallery lưu phục vụ nhận diện; nhóm cam kết không dùng vào "
        "mục đích ngoài dự án STEM và không công khai ảnh nhận dạng cá nhân trên poster.",
    )

    add_h(doc, "8.2. Xiaozhi MCP bridge", level=2)
    add_p(
        doc,
        "Bo Xiaozhi (ESP32-S3) thu tiếng, đẩy lên máy chủ AI để STT → LLM hiểu ý định → TTS. "
        "LLM gọi tool qua MCP (JSON-RPC). Bridge Node.js (Docker) ánh xạ tool như "
        "control_door, control_light/pump, read_temperature / read_home_status sang topic "
        "MQTT chip esp32. Ví dụ người dùng nói «Mở cửa và đọc nhiệt độ» thì hệ thống cần "
        "gọi cả control_door và tool đọc nhiệt, rồi TTS trả lời số đo từ telemetry.",
    )
    add_table(
        doc,
        ["Tool MCP (ví dụ)", "Hành vi mong đợi", "MQTT / dữ liệu"],
        [
            ["control_door", "Mở/đóng cửa phòng khách", "cmnd/esp32_door_livingroom1/POWER"],
            ["control_light / pump", "Bật tắt đèn / bơm", "cmnd/esp32_led1|pump/POWER"],
            ["read_temperature", "Đọc nhiệt độ hiện tại", "Cache tele/esp32_vitals"],
            ["read_home_status", "Tóm tắt trạng thái nhà", "mode, T/H, gas, cửa, rule"],
        ],
    )

    # ── IX ───────────────────────────────────────────────
    add_h(doc, "IX. KẾT QUẢ THỬ NGHIỆM")
    add_p(
        doc,
        "Nhóm thử theo các hạng mục chức năng và quan sát trên OLED, app và thiết bị thật. "
        "Số liệu dưới đây mang tính kết quả quan sát trên nguyên mẫu bàn thí nghiệm; khi "
        "thuyết trình nhóm trình bày cùng điều kiện đo và nguyên nhân sai.",
    )
    add_table(
        doc,
        ["Hạng mục", "Cách thử", "Kết quả quan sát"],
        [
            ["MQTT MANUAL", "App / Xiaozhi bật tắt đèn–bơm–cửa", "Board phản hồi đúng topic esp32_*"],
            ["AUTO quang / nước / gas", "Che quang; cạn nước; kích gas", "Đèn/bơm/còi–quạt theo rule"],
            ["Nhận diện mở cửa", "Đăng ký mặt → nhìn camera", "Mở cửa khi đạt confidence"],
            ["Giọng nói 1 m, ồn thấp", "Lặp lệnh tiếng Việt", "Tỷ lệ đúng cao; độ trễ hướng tới <2 s"],
            ["Giọng nói xa / ồn", "≈3 m hoặc tạp âm cao", "Tỷ lệ giảm; cần nói rõ / gần mic"],
            ["Kịch bản «Tôi đi ngủ»", "Lệnh ngữ cảnh đa thiết bị", "Chuỗi tool ổn định khi mạng tốt"],
            ["Portal Wi-Fi", "Double-reset → SoftAP SmartHome", "Vào 192.168.4.1 cấu hình được"],
        ],
    )
    add_p(
        doc,
        "Ở điều kiện chuẩn (khoảng 1 m, tạp âm thấp), độ trễ từ lúc nói đến khi thiết bị "
        "phản hồi thường hướng tới dưới 2 giây nếu Wi-Fi và máy chủ AI ổn định. Khi khoảng "
        "cách tăng hoặc tạp âm cao, tỷ lệ nhận diện ý định giảm; người dùng cần nói rõ hơn "
        "hoặc đứng gần micro. Luồng Face phụ thuộc ánh sáng khuôn mặt và ngưỡng cosine.",
    )

    # ── X ────────────────────────────────────────────────
    add_h(doc, "X. THẢO LUẬN HẠN CHẾ VÀ BÀI HỌC KỸ THUẬT")
    add_p(
        doc,
        "Thứ nhất, phụ thuộc mạng: cả MQTT và Xiaozhi đều cần Wi-Fi ổn định; mất mạng làm "
        "mất điều khiển từ xa dù rule AUTO local trên board vẫn có thể chạy một phần. "
        "Thứ hai, lệch Chip ID giữa MCP và firmware khiến «có MQTT nhưng không có lệnh» — "
        "cần kiểm tra log publish topic. Thứ ba, nhận diện khuôn mặt vẫn có thể sai khi thiếu "
        "sáng, góc nghiêng hoặc ảnh giả (chưa chống spoofing). Thứ tư, an toàn điện: không "
        "để học sinh thao tác 220 V khi không có GVHD; ưu tiên demo tải thấp áp khi có thể.",
    )
    add_p(
        doc,
        "Bài học nhóm rút ra: đo đạc phải ghi rõ điều kiện; ưu tiên giải thích «vì sao sai» "
        "song song với tỷ lệ đúng; giữ đồng bộ tài liệu pinout, README firmware và cấu hình "
        "MCP; kê khai trung thực công nghệ số / AI theo Phụ lục 6.",
    )

    # ── XI ───────────────────────────────────────────────
    add_h(doc, "XI. Ý NGHĨA STEM VÀ KHẢ NĂNG ỨNG DỤNG")
    add_p(
        doc,
        "Khoa học: nguyên lý cảm biến nhiệt–ẩm–gas–siêu âm, lọc nhiễu Kalman, ngưỡng "
        "so khớp cosine. Công nghệ: MQTT, NCNN on-device, LLM/MCP, Flutter. Kỹ thuật: "
        "thiết kế mạch điều khiển 5 V, rơ-le cách ly, firmware AUTO/MANUAL, portal Wi-Fi. "
        "Toán: hysteresis rule, thống kê tỷ lệ đúng và độ trễ trung bình.",
    )
    add_p(
        doc,
        "Khả năng ứng dụng tại trường và cộng đồng: học cụ IoT–AI cho STEM; demo mở cửa "
        "không chìa khóa vật lý; cảnh báo gas / hết nước trên mô hình; trải nghiệm điều khiển "
        "tiếng Việt không phụ thuộc trợ lý nước ngoài. Mô hình có thể tái sử dụng trong "
        "câu lạc bộ tin học / điện tử của trường.",
    )

    # ── XII ──────────────────────────────────────────────
    add_h(doc, "XII. KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN")
    add_p(
        doc,
        "Nguyên mẫu chứng minh tính khả thi của nhà thông minh AIoT trên ESP32 (chip esp32) "
        "kết hợp Face AIoT và Xiaozhi: ba kênh điều khiển cùng broker MQTT, có thể đo đạc "
        "và trình bày hạn chế một cách trung thực. Mục tiêu độ trễ và tỷ lệ đúng đạt mức "
        "khả quan ở điều kiện chuẩn; hiệu năng giảm khi xa mic hoặc mạng kém — đúng với "
        "giả thuyết kỹ thuật ban đầu.",
    )
    add_p(
        doc,
        "Hướng phát triển: chống giả mạo ảnh khuôn mặt; nhật ký ra vào; khóa điện từ; "
        "đồng bộ Chip ID giữa mọi MCP endpoint và firmware; mở rộng kịch bản ngữ cảnh; "
        "tối ưu UI app và tài liệu lắp ráp cho học sinh lớp sau.",
    )

    # ── XIII ─────────────────────────────────────────────
    add_h(doc, "XIII. TÀI LIỆU THAM KHẢO")
    for ref in [
        "1. Espressif Systems — ESP32 Technical Reference Manual / Datasheet.",
        "2. OASIS — MQTT Version 3.1.1 / MQTT Version 5.0.",
        "3. Tencent NCNN; MobileFaceNet / YuNet (nhận diện nhẹ trên thiết bị).",
        "4. Dự án mã nguồn mở XiaoZhi AI (xiaozhi-esp32); đặc tả Model Context Protocol (MCP).",
        "5. Flutter Camera / Dart FFI; tài liệu kỹ thuật DHT11, MQ gas, HC-SR04, SSD1306.",
        "6. Công văn 7292/BGDĐT-GDPT về tổ chức cuộc thi KHKT dành cho học sinh trung học.",
        "7. Kế hoạch số 186/KH-SGDĐT ngày 14/10/2026 của Sở GDĐT Ninh Bình về KHKT/STEM cấp tỉnh.",
        "8. Firmware SmartHome_ESP32 và server/xiaozhi_mcp_bridge trong kho mã dự án Face AIoT.",
        "9. Quyết định cử dự án tham dự KHKT/STEM cấp tỉnh năm học 2026–2027 "
        "(Trường THPT A Nguyễn Khuyến).",
    ]:
        add_p(doc, ref, indent=False, after=2, size=12)

    # ── Phụ lục A ────────────────────────────────────────
    add_h(doc, "PHỤ LỤC A. BẢNG CHÂN VÀ TOPIC MQTT (TÓM TẮT)")
    add_p(
        doc,
        "Phụ lục này nhắc lại nhanh các chân và topic đã trình bày ở Mục VII để tiện "
        "đối chiếu khi lắp ráp và kiểm thử. Chi tiết đầy đủ xem README firmware "
        "SmartHome_ESP32 trong kho mã.",
        italic=True,
    )
    add_table(
        doc,
        ["Nhóm", "Chi tiết"],
        [
            ["Chip MQTT", "esp32"],
            ["Portal Wi-Fi", "Double-reset → AP SmartHome → http://192.168.4.1"],
            ["Đèn / Bơm / Quạt / Cửa", "GPIO33 / 32 / 19 / 18"],
            ["Cảm biến chính", "DHT11:4 · Quang:27 · Gas:26 · SR04:13/14 · Đất:34 · Mưa:35"],
            ["OLED", "SDA21 · SCL22"],
            ["Còi", "GPIO25"],
        ],
        font_size=11,
    )

    add_p(doc, "", after=12)
    add_p(
        doc,
        f"Nhóm thực hiện: {HS1}, {HS2} — GVHD: {GVHD} — {TRUONG}",
        center=True,
        italic=True,
        size=12,
        indent=False,
    )
    add_p(
        doc,
        "— Hết báo cáo dự án —",
        center=True,
        italic=True,
        size=12,
        indent=False,
        after=4,
    )

    OUT_HOSO.mkdir(parents=True, exist_ok=True)
    p1 = OUT_HOSO / OUT_NAME
    p2 = DOCS / OUT_NAME
    doc.save(p1)
    doc.save(p2)
    print("Wrote:", p1)
    print("Wrote:", p2)
    print("TOM_TAT_WORDS:", word_count(TOM_TAT))
    return p1, p2


if __name__ == "__main__":
    build()
