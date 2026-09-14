# Dữ liệu mẫu — dựng lại đúng bối cảnh trong bản thiết kế (Xstudio).
# Chạy lại được nhiều lần: mọi bản ghi đều find_or_create.

puts "→ Workspace"
ws = Workspace.current
ws.update!(name: "Team Workspace", tagline: "Xstudio",
           about: "Đội phát triển & tư vấn phần mềm: (1) tự xây sản phẩm và tự đi bán, " \
                  "(2) tư vấn và triển khai chuyển đổi số cho khách hàng, trọng tâm dữ liệu và AI.")

puts "→ Danh mục thu chi"
TransactionCategory.seed_defaults!

puts "→ Thành viên"
PEOPLE = [
  { email: "na@xstudio.vn",     full_name: "Xuân Na",   job_title: "Trưởng nhóm · Quản trị", role: :admin },
  { email: "minh@xstudio.vn",   full_name: "Trần Minh", job_title: "Kỹ sư dữ liệu",          role: :member },
  { email: "ha@xstudio.vn",     full_name: "Lê Hà",     job_title: "Kỹ sư AI",               role: :member },
  { email: "vy@xstudio.vn",     full_name: "Ngô Vy",    job_title: "Thiết kế & Báo cáo",     role: :member },
  { email: "dung@xstudio.vn",   full_name: "Phạm Dũng", job_title: "Kinh doanh",             role: :member },
  { email: "khanh@xstudio.vn",  full_name: "Đỗ Khánh",  job_title: "Kỹ sư phân tích",        role: :member, invited: true }
].freeze

users = PEOPLE.map do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.assign_attributes(full_name: attrs[:full_name], job_title: attrs[:job_title], role: attrs[:role])
  if attrs[:invited]
    user.status = :invited
    user.generate_invitation_token if user.invitation_token.blank?
    user.password ||= "xstudio2026"
  else
    user.status = :active
    user.password = "xstudio2026"
    user.invitation_accepted_at ||= rand(60..240).days.ago
  end
  user.save!
  user
end
na, minh, ha, vy, dung, khanh = users
puts "   #{users.size} thành viên · mật khẩu demo: xstudio2026"

puts "→ Dự án"
PROJECTS = [
  { name: "Kho dữ liệu & Báo cáo bán lẻ", type: :digital_transformation, owner: 1, client: "Coopmart",
    status: :in_progress, desc: "Xây kho dữ liệu tập trung cho chuỗi 42 cửa hàng, chuẩn hoá dữ liệu POS — kho — khách hàng và bàn giao bộ báo cáo doanh thu theo 3 giai đoạn.",
    start: 200, due: 77, members: [1, 2, 3] },
  { name: "Nền tảng Xna Insight", type: :product_sales, owner: 0, client: "Sản phẩm nội bộ",
    status: :in_progress, desc: "Sản phẩm phân tích dữ liệu bán lẻ dạng SaaS. Bản thương mại đầu tiên nhắm chuỗi cửa hàng vừa.",
    start: 260, due: 92, members: [0, 4, 3] },
  { name: "Chatbot CSKH ngành dược", type: :digital_transformation, owner: 2, client: "Dược Hậu Giang",
    status: :in_progress, desc: "Trợ lý hội thoại trả lời câu hỏi sản phẩm và tra cứu đơn hàng, tích hợp tổng đài sẵn có.",
    start: 120, due: -9, members: [2, 1] },
  { name: "Gói bán lẻ SaaS v2", type: :product_sales, owner: 4, client: "Sản phẩm nội bộ",
    status: :planning, desc: "Đóng gói lại sản phẩm theo mô hình thuê tháng, bổ sung phân quyền và báo cáo tuỳ biến.",
    start: 30, due: 494, members: [4, 0] },
  { name: "Data Warehouse nhà máy Vinatex", type: :digital_transformation, owner: 1, client: "Vinatex · giai đoạn 2",
    status: :in_progress, desc: "Giai đoạn 2: mở rộng mô hình dữ liệu sang khối sản xuất, đo hiệu suất dây chuyền theo ca.",
    start: 330, due: 14, members: [1, 3] },
  { name: "Website thương hiệu & landing", type: :product_sales, owner: 3, client: "Sản phẩm nội bộ",
    status: :completed, desc: "Trang giới thiệu năng lực đội và các trang đích cho chiến dịch bán hàng.",
    start: 300, due: 60, members: [3, 4] },
  { name: "Tự động hoá báo cáo tài chính", type: :digital_transformation, owner: 0, client: "An Phát Holdings",
    status: :on_hold, desc: "Gom số liệu từ 4 hệ thống về một bộ báo cáo hợp nhất. Tạm dừng chờ khách hàng chốt mô hình.",
    start: 150, due: 120, members: [0, 1] },
  { name: "Trợ lý phân tích nội bộ", type: :product_sales, owner: 2, client: "Sản phẩm nội bộ",
    status: :planning, desc: "Thử nghiệm trợ lý hỏi đáp trên chính dữ liệu vận hành của đội.",
    start: 20, due: 200, members: [2, 3] },
  { name: "Chuẩn hoá dữ liệu khách hàng ngành F&B", type: :digital_transformation, owner: 3, client: "Golden Gate",
    status: :in_progress, desc: "Hợp nhất hồ sơ khách hàng từ 3 nguồn, xây bộ quy tắc khử trùng lặp.",
    start: 90, due: 46, members: [3, 2, 1] }
].freeze

projects = PROJECTS.map do |spec|
  p = Project.find_or_initialize_by(name: spec[:name])
  p.assign_attributes(
    project_type: spec[:type], status: spec[:status], client_name: spec[:client],
    description: spec[:desc], owner: users[spec[:owner]], created_by: na,
    start_date: spec[:start].days.ago.to_date, due_date: spec[:due].days.from_now.to_date
  )
  p.completed_at ||= 20.days.ago if spec[:status] == :completed
  p.save!
  spec[:members].each { |i| p.project_memberships.find_or_create_by!(user: users[i]) { |m| m.joined_at = p.start_date } }
  p
end
puts "   #{projects.size} dự án"

puts "→ Nhãn & công việc"
LABEL_POOL = [["dữ liệu", "#0E7490"], ["báo cáo", "#2E6BC0"], ["tích hợp", "#6D3BD4"],
              ["khách hàng", "#D98324"], ["ưu tiên", "#C8322B"], ["ETL", "#0E7A46"]].freeze

TASK_TITLES = [
  "Chuẩn hoá bảng danh mục sản phẩm từ 3 nguồn POS",
  "Dựng pipeline ETL đơn hàng theo ngày",
  "Mô hình sao cho phân tích doanh thu",
  "Kết nối nguồn dữ liệu kho hàng",
  "Khảo sát nhu cầu báo cáo của phòng kinh doanh",
  "Viết tài liệu bàn giao giai đoạn 1",
  "Bộ báo cáo doanh thu theo cửa hàng",
  "Kiểm thử chất lượng dữ liệu sau nạp",
  "Thiết lập lịch chạy hằng đêm",
  "Chốt wireframe báo cáo doanh thu",
  "Phác thảo gói giá SaaS v2",
  "Gửi kịch bản hội thoại cho khách",
  "Nghiệm thu môi trường production",
  "Tối ưu truy vấn bảng giao dịch",
  "Xây màn hình quản trị phân quyền",
  "Rà soát bảo mật trước khi bàn giao"
].freeze

if Task.count.zero?
  projects.each do |project|
    labels = LABEL_POOL.sample(3).map { |(name, color)| project.labels.find_or_create_by!(name: name) { |l| l.color = color } }
    columns = project.board_columns.ordered.to_a
    members = project.members.to_a
    count   = project.status_planning? ? rand(5..9) : rand(16..34)

    count.times do |i|
      column = if project.status_completed? then columns.last
               else columns.sample end
      due = [nil, rand(-12..40).days.from_now.to_date, rand(-12..40).days.from_now.to_date].sample

      task = project.tasks.create!(
        title: "#{TASK_TITLES.sample}#{i > TASK_TITLES.size ? " (#{i})" : ''}",
        board_column: column, assignee: members.sample, reporter: project.owner,
        priority: Task.priorities.keys.sample, due_date: due,
        start_date: due ? due - rand(3..14).days : nil,
        estimated_hours: [nil, 2, 4, 8, 16].sample
      )
      task.labels << labels.sample if rand < 0.5
      rand(0..4).times { |n| task.subtasks.create!(title: "Bước #{n + 1}", done: rand < 0.55) }
    end
  end
end
puts "   #{Task.count} công việc"

puts "→ Thu chi"
if Transaction.count.zero?
  income_cats  = TransactionCategory.kind_income.to_a
  expense_cats = TransactionCategory.kind_expense.to_a
  COUNTERPARTIES = ["Coopmart", "Vinatex", "Dược Hậu Giang", "Golden Gate", "An Phát Holdings",
                    "Amazon Web Services", "Nguyễn Quốc Anh", "VNG Cloud", "Atlassian", "Google Workspace"].freeze

  360.times do
    day = rand(0..330).days.ago.to_date
    is_income = rand < 0.38
    project = rand < 0.78 ? projects.sample : nil
    project = nil if is_income && project&.client_name == "Sản phẩm nội bộ" && rand < 0.4

    Transaction.create!(
      kind: is_income ? :income : :expense,
      amount: is_income ? rand(18..220) * 1_000_000 : rand(2..85) * 1_000_000,
      occurred_on: day,
      category: is_income ? income_cats.sample : expense_cats.sample,
      project: project,
      description: is_income ? ["Thanh toán giai đoạn 1", "Tạm ứng hợp đồng", "Doanh thu thuê bao tháng", "Thanh toán nghiệm thu"].sample
                             : ["Chi phí outsource frontend", "Thanh toán server AWS", "Giấy phép phần mềm", "Chi phí marketing", "Thuê văn phòng", "Đi lại gặp khách hàng"].sample,
      counterparty: COUNTERPARTIES.sample,
      payment_method: Transaction.payment_methods.keys.sample,
      created_by: users.sample
    )
  end
end
puts "   #{Transaction.count} giao dịch"

puts "→ Cây định hướng"
if StrategyTree.kept.none?
  tree = StrategyTree.create!(name: "Định hướng Xstudio", created_by: na,
                              description: "Các mảng lớn đội đang theo đuổi và những phần nhỏ bên trong.")
  root = tree.root

  BRANCHES = [
    { title: "Sản phẩm & Kinh doanh", icon: "📦", color: "#6D3BD4", status: :pursuing, owner: na,
      note: "Tự xây sản phẩm và tự bán. Ưu tiên gói SaaS cho doanh nghiệp vừa.",
      kids: [
        { title: "Nghiên cứu thị trường", status: :achieved, owner: na, note: "Đã xong báo cáo quy mô thị trường và 12 phỏng vấn khách hàng." },
        { title: "Kênh bán trực tiếp",    status: :pursuing, owner: dung, note: "Đội sale 2 người, tập trung giới thiệu qua đối tác." },
        { title: "Đóng gói SaaS",         status: :idea,     note: "Cân nhắc mô hình thuê tháng theo số người dùng." }
      ] },
    { title: "Chuyển đổi số (Data & AI)", icon: "🧠", color: "#0E7490", status: :pursuing, owner: minh,
      note: "Tư vấn và triển khai dữ liệu — AI cho khách hàng, trọng tâm ngành bán lẻ và sản xuất.",
      kids: [
        { title: "Xây dựng kho dữ liệu",      status: :pursuing, owner: minh, note: "Nền tảng bắt buộc trước khi làm phân tích và AI. Đang chuẩn hoá mô hình dữ liệu dùng chung cho 3 khách hàng bán lẻ." },
        { title: "Báo cáo & Trực quan hoá",   status: :pursuing, owner: vy,   note: "Giá trị nhìn thấy sớm, dễ thuyết phục khách hàng ký giai đoạn sau." },
        { title: "Ứng dụng AI cho khách hàng", status: :idea,    note: "Chưa chốt bài toán. Cần chọn 1–2 use case có ROI rõ ràng." }
      ] },
    { title: "Năng lực nội bộ", icon: "🛠", color: "#5A6B82", status: :paused, owner: ha,
      note: "Tạm gác tới Q1/2027 để tập trung nguồn lực cho hai mảng chính.",
      kids: [
        { title: "Tuyển dụng & đào tạo",  status: :pursuing, owner: ha, note: "Cần thêm 1 data engineer trong Q4." },
        { title: "Quy trình giao hàng",   status: :idea,     note: "Chuẩn hoá checklist bàn giao dự án." }
      ] }
  ].freeze

  BRANCHES.each do |spec|
    branch = tree.strategy_nodes.create!(
      parent: root, title: spec[:title], icon: spec[:icon], color: spec[:color],
      status: spec[:status], owner: spec[:owner], note: spec[:note],
      created_by: na, updated_by: na
    )
    spec[:kids].each do |kid|
      tree.strategy_nodes.create!(parent: branch, title: kid[:title], status: kid[:status],
                                  owner: kid[:owner], note: kid[:note], created_by: na, updated_by: na)
    end
  end

  StrategyTree.create!(name: "Cây sản phẩm 2027", created_by: na,
                       description: "Bản nháp định hướng sản phẩm cho năm sau.").tap do |t|
    t.strategy_nodes.create!(parent: t.root, title: "Gói phân tích bán lẻ", icon: "◆", color: "#6D3BD4",
                             status: :pursuing, owner: na, note: "Sản phẩm chủ lực năm sau.",
                             created_by: na, updated_by: na)
  end
end
puts "   #{StrategyTree.kept.count} cây · #{StrategyNode.kept.count} nút"

puts "→ Nhật ký hoạt động"
if Activity.count < 20
  Project.kept.limit(9).each do |p|
    Activity.log!(user: p.owner || na, action: "created", trackable: p, project: p,
                  summary: "đã tạo dự án #{p.name}")
  end
  Task.kept.order("RANDOM()").limit(18).each do |t|
    Activity.log!(user: t.reporter || na, action: "created", trackable: t, project: t.project,
                  summary: "đã tạo công việc #{t.code}")
  end
end

puts "\n✓ Xong. Đăng nhập: na@xstudio.vn / xstudio2026"
