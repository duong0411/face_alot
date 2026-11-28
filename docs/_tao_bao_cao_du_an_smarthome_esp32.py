# -*- coding: utf-8 -*-
"""Báo cáo dự án nhà thông minh — firmware SmartHome_ESP32 + Face AIoT + Xiaozhi."""
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

TEN_DU_AN = (
    "Nhà thông minh tích hợp nhận diện khuôn mặt và "
    "điều khiển IoT qua ứng dụng di động (Face AIoT)"
)
LINH_VUC = "Khoa học máy tính — IoT — Trí tuệ nhân tạo ứng dụng"
HS1, HS1_LOP = "Nguyễn Tuấn Anh", "12A1"
HS2, HS2_LOP = "Lê Chí Quốc", "11A1"
GVHD = "Nguyễn Thị Viên"
TRUONG = "Trường THPT A Nguyễn Khuyến"
SO_GDDT = "SỞ GIÁO DỤC VÀ ĐÀO TẠO TỈNH NINH BÌNH"
NAVY = RGBColor(0x1F, 0x4E, 0x79)
GRAY = RGBColor(0x55, 0x55, 0x55)


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


def add_fig(doc, path: Path, caption: str, width_cm=14.0):
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


def add_table(doc, headers, rows):
    table = doc.add_table(rows=1 + len(rows), cols=len(headers))
    table.style = "Table Grid"
    for i, h in enumerate(headers):
        cell = table.rows[0].cells[i]
        cell.text = ""
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = p.add_run(h)
        set_run_font(run, size=11, bold=True, color=RGBColor(0xFF, 0xFF, 0xFF))
        shade_cell(cell, "1F4E79")
    for r_i, row in enumerate(rows):
        for c_i, val in enumerate(row):
            cell = table.rows[r_i + 1].cells[c_i]
            cell.text = ""
            p = cell.paragraphs[0]
            run = p.add_run(str(val))
            set_run_font(run, size=11)
            if r_i % 2 == 1:
                shade_cell(cell, "F2F2F2")
    doc.add_paragraph()


def build():
    doc = setup_doc()

    # Bìa
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
    add_p(doc, "Theo Quyết định cử SP dự thi KHKT/STEM cấp tỉnh (THPT A Nguyễn Khuyến)", center=True, size=11, indent=False, after=20)

    add_p(doc, "Thông tin nhóm dự án:", bold=True, indent=False, after=4)
    for line in [
        f"• Học sinh: {HS1} (Lớp {HS1_LOP}); {HS2} (Lớp {HS2_LOP})",
        f"• Giáo viên hướng dẫn: {GVHD}",
        f"• Cơ sở giáo dục: {TRUONG}",
        "• Sản phẩm kỹ thuật: mô hình nhà thông minh ESP32 (chip MQTT esp32), "
        "app Face AIoT (Flutter/NCNN), cầu MCP Xiaozhi → MQTT",
    ]:
        add_p(doc, line, indent=False, after=2, size=12)

    doc.add_page_break()

    add_h(doc, "MỤC LỤC")
    for item in [
        "I. Tóm tắt dự án",
        "II. Lý do chọn đề tài",
        "III. Mục tiêu nghiên cứu",
        "IV. Đối tượng và phạm vi",
        "V. Nội dung và phương pháp",
        "VI. Kiến trúc hệ thống",
        "VII. Phần cứng — firmware SmartHome_ESP32",
        "VIII. Phần mềm ứng dụng Face AIoT & Xiaozhi",
        "IX. Kết quả thử nghiệm",
        "X. Ý nghĩa STEM và khả năng ứng dụng",
        "XI. Kết luận và hướng phát triển",
        "XII. Tài liệu tham khảo",
    ]:
        add_p(doc, item, indent=False, after=2)

    doc.add_page_break()

    add_h(doc, "I. TÓM TẮT DỰ ÁN")
    add_p(
        doc,
        "Dự án Face AIoT xây dựng mô hình nhà thông minh kết hợp ba kênh điều khiển: "
        "(1) nhận diện khuôn mặt trên điện thoại mở cửa qua MQTT; (2) điều khiển thủ công/"
        "tự động trên app theo cảm biến; (3) trợ lý giọng nói tiếng Việt Xiaozhi (ESP32-S3) "
        "gọi công cụ MCP để điều khiển cùng node chấp hành."
    )
    add_p(
        doc,
        "Node chấp hành dùng firmware SmartHome_ESP32 (Chip ID MQTT: esp32): OLED, DHT11, "
        "cảm biến quang, MQ gas, HC-SR04 (lọc Kalman), mưa/đất, còi, rơ-le đèn–bơm–quạt, "
        "servo cửa; chế độ AUTO/MANUAL và Wi-Fi portal cấu hình mạng. Broker MQTT WSS "
        "kết nối app, bridge Xiaozhi và board. Sản phẩm phù hợp STEM tỉnh Ninh Bình: "
        "cảm biến–AI nhẹ–IoT–an toàn điện."
    )

    add_h(doc, "II. LÝ DO CHỌN ĐỀ TÀI")
    add_p(
        doc,
        "Nhu cầu mở cửa không chìa, theo dõi môi trường và điều khiển thiết bị bằng tiếng Việt "
        "ngày càng rõ trong đời sống. Giải pháp thương mại thường đắt hoặc hỗ trợ tiếng Việt hạn chế. "
        "Học sinh có thể chế tạo mô hình chi phí thấp trên ESP32, kết hợp nhận diện khuôn mặt "
        "on-device (riêng tư hơn camera cố định) và Xiaozhi không dùng camera."
    )
    add_p(
        doc,
        "Đề tài được Trường THPT A Nguyễn Khuyến cử tham dự Cuộc thi KHKT / Ngày hội STEM "
        "cấp tỉnh năm học 2026–2027 (theo Quyết định kèm danh sách dự án Face AIoT)."
    )

    add_h(doc, "III. MỤC TIÊU NGHIÊN CỨU")
    for t in [
        "1. Chế tạo mô hình nhà thông minh trên ESP32 với firmware SmartHome_ESP32 ổn định MQTT.",
        "2. Tích hợp app Face AIoT: đăng ký/nhận diện khuôn mặt → mở cửa khi đạt ngưỡng tin cậy.",
        "3. Hỗ trợ MANUAL/AUTO (tối→đèn; hết nước/đất khô→bơm; mưa→dừng bơm; nhiệt/gas→quạt/còi).",
        "4. Kết nối Xiaozhi MCP để điều khiển và đọc cảm biến bằng giọng nói tiếng Việt.",
        "5. Đánh giá độ trễ lệnh, tỷ lệ thực thi đúng và hạn chế (ồn, khoảng cách, mạng).",
    ]:
        add_p(doc, t, indent=False)

    add_h(doc, "IV. ĐỐI TƯỢNG VÀ PHẠM VI")
    add_p(
        doc,
        "Đối tượng: mô hình bàn thí nghiệm; người dùng là thành viên đã đăng ký khuôn mặt. "
        "Phạm vi phần cứng: chip MQTT esp32 (khác bản ESP8266 mã 123 cũ). Phạm vi phần mềm: "
        "app Flutter Android/iOS, backend identify, bridge MCP. Không nghiên cứu khóa điện tử "
        "công nghiệp hay camera ngoài trời."
    )

    add_h(doc, "V. NỘI DUNG VÀ PHƯƠNG PHÁP")
    add_p(doc, "• Nghiên cứu linh kiện: DHT11, MQ gas, HC-SR04, mưa/đất, OLED, rơ-le, servo SG90.", indent=False)
    add_p(doc, "• Lập trình firmware AUTO/MANUAL, portal Wi-Fi double-reset, telemetry MQTT.", indent=False)
    add_p(doc, "• Xây dựng app: auth, gallery mặt, unlock realtime, smart control.", indent=False)
    add_p(doc, "• Cấu hình Xiaozhi STT/LLM/TTS + MCP tools → topic cmnd/esp32_*.", indent=False)
    add_p(doc, "• Thử nghiệm vòng kín: che quang → đèn; cạn nước → bơm/còi; nhận diện → mở cửa; giọng nói → MQTT.", indent=False)
    add_p(
        doc,
        "Phương pháp: thiết kế kỹ thuật (so sánh App / RPi+camera / FaceAIoT+Xiaozhi) → chế tạo → "
        "tích hợp → đo đạc → hiệu chỉnh ngưỡng (gas, mực nước 1–10 cm, cosine nhận diện).",
        indent=True,
    )

    add_h(doc, "VI. KIẾN TRÚC HỆ THỐNG")
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
        "Luồng mở cửa bằng khuôn mặt: camera app → NCNN → API identify → "
        "publish cmnd/esp32_door_livingroom1/POWER → servo mở, giữ doorHoldSec rồi đóng. "
        "Luồng Xiaozhi: micro → STT/LLM → tools/call → bridge Node.js → cùng broker MQTT."
    )

    add_h(doc, "VII. PHẦN CỨNG — FIRMWARE SmartHome_ESP32")
    add_fig(
        doc,
        IMG / "mo_hinh_thuc_te.png",
        "Hình 1. Mô hình nhà thông minh thực tế (Ảnh do học sinh tự chụp).",
        width_cm=15.0,
    )
    add_h(doc, "7.1. Sơ đồ chân (tóm tắt theo README firmware)", level=2)
    add_table(
        doc,
        ["Linh kiện", "GPIO ESP32", "Ghi chú"],
        [
            ["OLED SSD1306 I2C", "SDA 21 / SCL 22", "Trạng thái / rule"],
            ["DHT11", "GPIO4", "Nhiệt độ – độ ẩm"],
            ["Quang (D0)", "GPIO27", "AUTO đèn khi tối"],
            ["Gas MQ (D0)", "GPIO26", "Còi liên tục khi cảnh báo (rule)"],
            ["Còi", "GPIO25", "Gas / hết nước AUTO"],
            ["Relay bơm / đèn", "GPIO32 / GPIO33", "ACTIVE HIGH; IN1=bơm, IN2=đèn"],
            ["Relay quạt", "GPIO19", "Nhiệt cao / gas"],
            ["Đất (A0) / mưa (D0)", "GPIO34 / GPIO35", "Rule bơm"],
            ["HC-SR04 TRIG/ECHO", "GPIO13 / GPIO14", "Mực nước 1–10 cm + Kalman"],
            ["Servo cửa SG90", "GPIO18", "Topic esp32_door_livingroom1"],
        ],
    )
    add_h(doc, "7.2. Topic MQTT chính (Chip ID = esp32)", level=2)
    add_table(
        doc,
        ["Thiết bị / dữ liệu", "Topic"],
        [
            ["Đèn", "cmnd/esp32_led1/POWER · tele/esp32_led1/status"],
            ["Bơm", "cmnd/esp32_pump/POWER · tele/esp32_pump/status"],
            ["Quạt", "cmnd/esp32_fan_livingroom/POWER"],
            ["Cửa", "cmnd/esp32_door_livingroom1/POWER"],
            ["Vitals (T/H/gas/…)", "tele/esp32_vitals/status"],
            ["Mode / Rules", "cmnd/esp32_mode/POWER · cmnd/esp32_rules/SET"],
        ],
    )
    add_p(
        doc,
        "Wi-Fi: double-reset → SoftAP SmartHome → portal http://192.168.4.1 để cấu hình mạng mới "
        "(không tự vào portal khi chỉ đổi SSID đã lưu thất bại theo cơ chế mặc định; cần double-reset)."
    )

    add_h(doc, "VIII. PHẦN MỀM ỨNG DỤNG FACE AIOT & XIAOZHI")
    add_fig(doc, IMG / "ui_dieu_khien_nha.png", "Hình 2. Giao diện Điều khiển nhà (Ảnh do HS tự chụp màn hình).", 14.0)
    add_fig(doc, IMG / "ui_dang_ky_mat.png", "Hình 3. Đăng ký khuôn mặt thành viên.", 12.0)
    add_fig(doc, IMG / "ui_mo_cua.png", "Hình 4. Mở cửa bằng nhận diện khuôn mặt.", 12.0)
    add_p(
        doc,
        "App Face AIoT (Flutter) hiển thị vitals, điều khiển MANUAL, cấu hình rule AUTO "
        "(khoảng cách nước 1–10 cm). Nhận diện on-device giảm phụ thuộc máy chủ cho bước "
        "extract đặc trưng. Xiaozhi MCP bridge Docker ánh xạ tool control_door, "
        "read_temperature/read_home_status, control_light/pump… sang MQTT chip esp32."
    )

    add_h(doc, "IX. KẾT QUẢ THỬ NGHIỆM")
    add_table(
        doc,
        ["Hạng mục", "Cách thử", "Kết quả quan sát"],
        [
            ["MQTT MANUAL", "App / Xiaozhi bật tắt đèn–bơm–cửa", "Board phản hồi đúng topic esp32_*"],
            ["AUTO quang / nước / gas", "Che quang; cạn nước; kích gas", "Đèn/bơm/còi–quạt theo rule"],
            ["Nhận diện mở cửa", "Đăng ký mặt → nhìn camera", "Mở cửa khi đạt confidence"],
            ["Giọng nói 1 m, ồn thấp", "Lặp lệnh tiếng Việt", "Tỷ lệ đúng cao; độ trễ hướng tới <2 s"],
            ["Giọng nói xa / ồn", "3 m hoặc tạp âm cao", "Tỷ lệ giảm; cần nói rõ / gần mic"],
            ["Kịch bản «Tôi đi ngủ»", "Lệnh ngữ cảnh đa thiết bị", "Thực thi chuỗi tool ổn định khi mạng tốt"],
        ],
    )
    add_p(
        doc,
        "Khi thuyết trình, nhóm ưu tiên giải thích nguyên nhân sai (ồn, xa mic, thiếu sáng, "
        "Wi-Fi/MQTT đứt, lệch Chip ID) song song với tỷ lệ đúng — đúng tinh thần dự án kỹ thuật."
    )

    add_h(doc, "X. Ý NGHĨA STEM VÀ KHẢ NĂNG ỨNG DỤNG")
    add_p(
        doc,
        "Khoa học: cảm biến, lọc Kalman, ngưỡng cosine. Công nghệ: MQTT, NCNN, LLM/MCP. "
        "Kỹ thuật: mạch 5 V điều khiển, rơ-le cách ly tải 220 V, firmware. Toán: rule, hysteresis, "
        "thống kê tỷ lệ/độ trễ. Ứng dụng: học cụ IoT–AI tại trường; demo mở cửa không chìa; "
        "cảnh báo gas/hết nước trên mô hình."
    )

    add_h(doc, "XI. KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN")
    add_p(
        doc,
        "Nguyên mẫu chứng minh tính khả thi của nhà thông minh AIoT trên ESP32 (chip esp32) "
        "kết hợp Face AIoT và Xiaozhi. Hướng phát triển: chống giả mạo ảnh; nhật ký ra vào; "
        "khóa điện từ; đồng bộ Chip ID giữa backend MCP và firmware; mở rộng kịch bản ngữ cảnh."
    )

    add_h(doc, "XII. TÀI LIỆU THAM KHẢO")
    for ref in [
        "1. Espressif — ESP32 Technical Reference / Datasheet.",
        "2. OASIS — MQTT Version 3.1.1 / 5.0.",
        "3. Tencent NCNN; MobileFaceNet (embedding cosine).",
        "4. Dự án mã nguồn mở XiaoZhi AI (xiaozhi-esp32); đặc tả MCP (JSON-RPC).",
        "5. Flutter Camera / Dart FFI; tài liệu DHT11, MQ, HC-SR04.",
        "6. Công văn 7292/BGDĐT-GDPT và Kế hoạch số 186/KH-SGDĐT ngày 14/10/2026 "
        "(Sở GDĐT Ninh Bình) về KHKT/STEM cấp tỉnh.",
        "7. Firmware SmartHome_ESP32 và bridge server/xiaozhi_mcp_bridge trong kho mã dự án.",
    ]:
        add_p(doc, ref, indent=False, after=2, size=12)

    add_p(doc, "", after=12)
    add_p(
        doc,
        f"Nhóm thực hiện: {HS1}, {HS2} — GVHD: {GVHD} — {TRUONG}",
        center=True,
        italic=True,
        size=12,
        indent=False,
    )

    OUT_HOSO.mkdir(parents=True, exist_ok=True)
    p1 = OUT_HOSO / OUT_NAME
    p2 = DOCS / OUT_NAME
    doc.save(p1)
    doc.save(p2)
    print("Wrote:", p1)
    print("Wrote:", p2)
    return p1, p2


if __name__ == "__main__":
    build()
