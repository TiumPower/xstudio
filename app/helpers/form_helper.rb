module FormHelper
  # Ô chọn tệp có nhãn tiếng Việt. Input gốc bị giấu (chuỗi "Choose File / No
  # file chosen" của trình duyệt không đổi được bằng CSS), nút bấm và tên tệp
  # do file_input_controller vẽ.
  def vn_file_field(form, attribute, multiple: false, accept: nil, button_label: nil, empty_text: nil)
    tag.div(class: "flex items-center gap-2.5", data: { controller: "file-input" }) do
      safe_join([
        form.file_field(attribute,
                        multiple: multiple, accept: accept,
                        class: "x-file-native",
                        data: { file_input_target: "input", action: "change->file-input#render",
                                empty_text: empty_text || (multiple ? "Chưa chọn tệp nào" : "Chưa chọn tệp") }),
        tag.button(button_label || (multiple ? "Chọn tệp…" : "Chọn tệp…"),
                   type: "button", class: "x-btn x-btn-ghost x-btn-sm flex-none",
                   data: { action: "file-input#open" }),
        tag.span(class: "text-[12.5px] truncate", data: { file_input_target: "label" })
      ])
    end
  end

  # Biến thể cho form_tag (không có form builder).
  def vn_file_field_tag(name, multiple: false, accept: nil, button_label: nil, empty_text: nil)
    tag.div(class: "flex items-center gap-2.5", data: { controller: "file-input" }) do
      safe_join([
        file_field_tag(name, multiple: multiple, accept: accept, class: "x-file-native",
                       data: { file_input_target: "input", action: "change->file-input#render",
                               empty_text: empty_text || "Chưa chọn tệp nào" }),
        tag.button(button_label || "Chọn tệp…", type: "button",
                   class: "x-btn x-btn-ghost x-btn-sm flex-none", data: { action: "file-input#open" }),
        tag.span(class: "text-[12.5px] truncate", data: { file_input_target: "label" })
      ])
    end
  end
end
