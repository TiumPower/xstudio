module FormHelper
  # Ô chọn tệp có nhãn tiếng Việt. Input gốc bị giấu (chuỗi "Choose File / No
  # file chosen" của trình duyệt không đổi được bằng CSS), nút bấm và danh sách
  # tệp đã chọn do file_input_controller vẽ.
  def vn_file_field(form, attribute, multiple: false, accept: nil, button_label: nil, empty_text: nil)
    file_picker(button_label: button_label) do
      form.file_field(attribute, multiple: multiple, accept: accept, class: "x-file-native",
                      data: file_data(multiple: multiple, empty_text: empty_text))
    end
  end

  # Biến thể cho form_tag (không có form builder).
  def vn_file_field_tag(name, multiple: false, accept: nil, button_label: nil, empty_text: nil)
    file_picker(button_label: button_label) do
      file_field_tag(name, multiple: multiple, accept: accept, class: "x-file-native",
                     data: file_data(multiple: multiple, empty_text: empty_text))
    end
  end

  private

  def file_data(multiple:, empty_text:)
    { file_input_target: "input", action: "change->file-input#render",
      empty_text: empty_text || (multiple ? "Chưa chọn tệp nào" : "Chưa chọn tệp") }
  end

  def file_picker(button_label:)
    tag.div(class: "x-filepick", data: { controller: "file-input" }) do
      safe_join([
        yield,
        tag.button(type: "button", class: "x-btn x-btn-ghost x-btn-sm flex-none",
                   data: { action: "file-input#open" }) do
          safe_join([paperclip_icon, button_label || "Chọn tệp…"])
        end,
        tag.span(class: "x-filepick-list", data: { file_input_target: "label" })
      ])
    end
  end

  # Cái kẹp giấy vẽ tay, cùng lối với các icon khác trong app (stroke theo màu chữ).
  def paperclip_icon
    tag.svg(width: 13, height: 13, viewBox: "0 0 16 16", fill: "none", stroke: "currentColor",
            "stroke-width": 1.6, "stroke-linecap": "round", "stroke-linejoin": "round",
            class: "flex-none") do
      tag.path(d: "M10.8 4.2 5.5 9.5a1.6 1.6 0 0 0 2.3 2.3l5.3-5.3a3.2 3.2 0 0 0-4.6-4.6L3.2 7.2a4.8 4.8 0 0 0 6.8 6.8l4.2-4.2")
    end
  end
end
