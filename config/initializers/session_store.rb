# Phiên đăng nhập không đặt hạn thực tế.
#
# Cookie bắt buộc phải có thời điểm hết hạn, nên "không giới hạn" ở đây nghĩa
# là 10 năm — dài hơn tuổi thọ dự kiến của chính hệ thống. Mỗi lần truy cập,
# Devise gia hạn tiếp (extend_remember_period), nên người dùng đang dùng đều
# thì không bao giờ bị đá ra.
Rails.application.config.session_store :cookie_store,
                                       key: "_xstudio_session",
                                       expire_after: 10.years,
                                       same_site: :lax,
                                       secure: Rails.env.production?
