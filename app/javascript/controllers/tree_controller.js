import { Controller } from "@hotwired/stimulus"

// Canvas cây định hướng (FR-TREE-*).
// Vẽ bằng SVG, tự bố trí bằng thuật toán tidy-tree (Reingold–Tilford rút gọn),
// kéo–thả bằng Pointer Events, ngăn xếp lệnh cho Hoàn tác/Làm lại.
const NODE_W = 196
const NODE_H = 62
const GAP_X  = 62
const GAP_Y  = 14

export default class extends Controller {
  static targets = [
    "stage", "canvasWrap", "canvas", "outline", "panel", "panelBody", "panelTemplate",
    "zoomBar", "zoomLabel", "minimap", "minimapSvg", "empty", "hint", "search",
    "statusFilter", "ownerFilter", "aiCounter",
    "pasteOverlay", "pasteInput", "pastePreview", "pasteCount",
    "deleteOverlay", "deleteTitle", "deleteCount", "deleteCount2", "events"
  ]
  static values = {
    data: Object, view: String, maxLevel: Number, maxDepth: Number,
    urls: Object, aiEnabled: Boolean, aiRemaining: Number, members: Array, focus: String,
    currentUser: Number
  }

  // ---- Vòng đời ---------------------------------------------------------
  connect() {
    this.root = this.dataValue && this.dataValue.id ? this.dataValue : null
    this.collapsed = new Set()
    this.selectedId = null
    this.scale = 1
    this.pan = { x: 0, y: 0 }
    this.undoStack = []
    this.redoStack = []
    this.searchHits = []
    this.searchIndex = -1

    this.seedCollapsed(this.root)
    this.bindGlobalKeys()
    this.bindPanZoom()
    this.watchRemoteChanges()
    this.render()

    if (this.focusValue) {
      const node = this.findNode(Number(this.focusValue))
      if (node) { this.select(node.id); this.centerOn(node.id) }
    } else {
      requestAnimationFrame(() => this.fit())
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    this.eventObserver?.disconnect()
  }

  // ---- FR-TREE-41 — thay đổi của người khác hiện sang trong vài giây --------
  watchRemoteChanges() {
    if (!this.hasEventsTarget) return

    this.eventObserver = new MutationObserver((records) => {
      records.forEach((record) => {
        record.addedNodes.forEach((element) => {
          if (!element.dataset || element.dataset.treeEvent === undefined) return
          const actorId = Number(element.dataset.actorId)
          const nodeId  = Number(element.dataset.nodeId)
          const title   = element.dataset.nodeTitle
          const actor   = element.dataset.actorName
          element.remove()
          if (actorId === this.currentUserValue) return // thao tác của chính mình

          // Nếu đang sửa đúng nút vừa bị người khác đổi thì cảnh báo, đừng
          // âm thầm nạp đè lên những gì người dùng đang gõ dở.
          if (nodeId === this.selectedId && this.panelHasFocus()) {
            this.toast(`Nút “${title}” vừa được ${actor || "người khác"} cập nhật. Tải lại để xem bản mới.`, "warn")
            return
          }
          clearTimeout(this.remoteTimer)
          this.remoteTimer = setTimeout(() => this.reload(), 700)
        })
      })
    })
    this.eventObserver.observe(this.eventsTarget, { childList: true })
  }

  panelHasFocus() {
    return this.panelBodyTarget.contains(document.activeElement)
  }

  seedCollapsed(node, depth = 0) {
    if (!node) return
    if (node.collapsed || depth >= this.maxLevelValue) this.collapsed.add(node.id)
    node.children.forEach((child) => this.seedCollapsed(child, depth + 1))
  }

  // ---- Bố trí -----------------------------------------------------------
  visibleChildren(node) {
    return this.collapsed.has(node.id) ? [] : node.children
  }

  // Bước giãn cách giữa các nút anh em, đo theo trục mà chúng xếp cạnh nhau:
  // sơ đồ ngang xếp dọc (cao nút), cây dọc xếp ngang (rộng nút).
  siblingStep() {
    return this.viewValue === "vertical" ? NODE_W + 24 : NODE_H + GAP_Y
  }

  // Tidy tree: mỗi lá chiếm một ô trên trục anh em, nút cha nằm giữa các con.
  layout() {
    const nodes = []
    const edges = []
    const step = this.siblingStep()
    let cursor = 0

    const walk = (node, depth) => {
      const kids = this.visibleChildren(node)
      let offset
      if (kids.length === 0) {
        offset = cursor * step
        cursor += 1
      } else {
        const positions = kids.map((kid) => walk(kid, depth + 1))
        offset = (positions[0] + positions[positions.length - 1]) / 2
      }
      nodes.push({ node, offset, depth })
      kids.forEach((kid) => edges.push({ from: node.id, to: kid.id }))
      return offset
    }

    if (this.root) walk(this.root, 0)
    this.positions = new Map(nodes.map((n) => [n.node.id, n]))
    this.edges = edges
    return nodes
  }

  // Đổi (offset theo trục anh em, depth) thành toạ độ màn hình cho từng chế độ xem.
  coords(item) {
    return this.viewValue === "vertical"
      ? { x: item.offset, y: item.depth * (NODE_H + 46) }
      : { x: item.depth * (NODE_W + GAP_X), y: item.offset }
  }

  // ---- Vẽ ---------------------------------------------------------------
  render() {
    this.emptyTarget.classList.toggle("hidden", Boolean(this.root && this.root.children.length))

    // Bảng phím tắt chỉ có nghĩa trên canvas; ở chế độ danh sách nó che mất nội dung.
    if (this.hasHintTarget) this.hintTarget.classList.toggle("hidden", this.viewValue === "outline")

    if (this.viewValue === "outline") {
      this.canvasWrapTarget.classList.add("hidden")
      this.zoomBarTarget.classList.add("hidden")
      this.minimapTarget.classList.add("hidden")
      this.outlineTarget.classList.remove("hidden")
      this.renderOutline()
      return
    }

    this.outlineTarget.classList.add("hidden")
    this.canvasWrapTarget.classList.remove("hidden")
    this.zoomBarTarget.classList.remove("hidden")

    const placed = this.layout()
    if (placed.length === 0) { this.canvasTarget.innerHTML = ""; return }

    const vertical = this.viewValue === "vertical"
    const coords = (item) => this.coords(item)

    const xs = placed.map((p) => coords(p).x)
    const ys = placed.map((p) => coords(p).y)
    this.bounds = {
      minX: Math.min(...xs) - 40, maxX: Math.max(...xs) + NODE_W + 100,
      minY: Math.min(...ys) - 40, maxY: Math.max(...ys) + NODE_H + 40
    }

    const svgNS = "http://www.w3.org/2000/svg"
    const svg = this.canvasTarget
    svg.innerHTML = ""
    const viewport = document.createElementNS(svgNS, "g")
    viewport.setAttribute("data-viewport", "")
    svg.appendChild(viewport)
    this.viewport = viewport

    const linkLayer = document.createElementNS(svgNS, "g")
    const nodeLayer = document.createElementNS(svgNS, "g")
    viewport.appendChild(linkLayer)
    viewport.appendChild(nodeLayer)

    this.edges.forEach((edge) => {
      const a = coords(this.positions.get(edge.from))
      const b = coords(this.positions.get(edge.to))
      const child = this.findNode(edge.to)
      const path = document.createElementNS(svgNS, "path")
      path.setAttribute("d", vertical
        ? `M${a.x + NODE_W / 2},${a.y + NODE_H} C${a.x + NODE_W / 2},${a.y + NODE_H + 30} ${b.x + NODE_W / 2},${b.y - 30} ${b.x + NODE_W / 2},${b.y}`
        : `M${a.x + NODE_W},${a.y + NODE_H / 2} C${a.x + NODE_W + 34},${a.y + NODE_H / 2} ${b.x - 34},${b.y + NODE_H / 2} ${b.x},${b.y + NODE_H / 2}`)
      path.setAttribute("fill", "none")
      path.setAttribute("stroke", child.color)
      path.setAttribute("stroke-opacity", "0.4")
      path.setAttribute("stroke-width", "1.5")
      linkLayer.appendChild(path)
    })

    placed.forEach((item) => nodeLayer.appendChild(this.nodeElement(item, coords(item))))

    this.applyTransform()
    this.renderMinimap()
    this.applyFilter()
  }

  nodeElement(item, point) {
    const svgNS = "http://www.w3.org/2000/svg"
    const node = item.node
    const group = document.createElementNS(svgNS, "g")
    group.setAttribute("transform", `translate(${point.x},${point.y})`)
    group.setAttribute("data-node-id", node.id)
    group.setAttribute("class", "x-tree-node")
    group.style.cursor = "pointer"
    group.appendChild(this.hoverBridge())

    const selected = this.selectedId === node.id
    const isRoot = node.parentId === null

    const box = document.createElementNS(svgNS, "rect")
    box.setAttribute("width", NODE_W)
    box.setAttribute("height", NODE_H)
    box.setAttribute("rx", "10")
    box.setAttribute("fill", isRoot ? "#0B1C33" : "#FFFFFF")
    box.setAttribute("stroke", selected ? "#2E6BC0" : (isRoot ? "#17395F" : "#E6EAF1"))
    box.setAttribute("stroke-width", selected ? "2" : "1")
    if (selected) box.setAttribute("filter", "drop-shadow(0 4px 12px rgba(46,107,192,.22))")
    group.appendChild(box)

    if (!isRoot) {
      const edge = document.createElementNS(svgNS, "rect")
      edge.setAttribute("width", "3")
      edge.setAttribute("height", NODE_H)
      edge.setAttribute("rx", "1.5")
      edge.setAttribute("fill", node.color)
      group.appendChild(edge)
    }

    if (isRoot) {
      group.appendChild(this.text("GỐC", 14, 20, { size: 9, weight: 700, fill: "#6B87AC", spacing: "1.4" }))
      group.appendChild(this.text(this.truncate(node.title, 22), 14, 38, { size: 13.5, weight: 700, fill: "#FFFFFF" }))
      group.appendChild(this.text(`${this.countAll(node)} nút`, 14, 52, { size: 10.5, fill: "#6B87AC" }))
      return this.wire(group, node)
    }

    let textX = 12
    if (node.icon) {
      group.appendChild(this.text(node.icon, 14, 24, { size: 13 }))
      textX = 32
    }
    group.appendChild(this.text(this.truncate(node.title, node.icon ? 19 : 23), textX, 24, { size: 13, weight: 600, fill: "#0D1B2E" }))

    const chipW = Math.max(52, node.statusLabel.length * 6.2 + 14)
    const chip = document.createElementNS(svgNS, "rect")
    chip.setAttribute("x", "12"); chip.setAttribute("y", "36")
    chip.setAttribute("width", chipW); chip.setAttribute("height", "17"); chip.setAttribute("rx", "8.5")
    chip.setAttribute("fill", node.statusColor); chip.setAttribute("fill-opacity", "0.12")
    group.appendChild(chip)
    group.appendChild(this.text(node.statusLabel, 12 + chipW / 2, 48, { size: 10, weight: 600, fill: node.statusColor, anchor: "middle" }))

    if (node.ownerInitials) {
      const dot = document.createElementNS(svgNS, "circle")
      dot.setAttribute("cx", NODE_W - 20); dot.setAttribute("cy", "44"); dot.setAttribute("r", "10")
      dot.setAttribute("fill", node.ownerColor || "#8A98AC")
      group.appendChild(dot)
      group.appendChild(this.text(node.ownerInitials, NODE_W - 20, 47.5, { size: 8.5, weight: 700, fill: "#FFFFFF", anchor: "middle" }))
    }

    if (node.children.length && this.collapsed.has(node.id)) {
      const badge = document.createElementNS(svgNS, "g")
      badge.setAttribute("transform", `translate(${NODE_W + 62}, ${NODE_H / 2 - 10})`)
      badge.style.cursor = "pointer"
      const circle = document.createElementNS(svgNS, "circle")
      circle.setAttribute("cx", "10"); circle.setAttribute("cy", "10"); circle.setAttribute("r", "10")
      circle.setAttribute("fill", "#FFFFFF"); circle.setAttribute("stroke", node.color); circle.setAttribute("stroke-width", "1.2")
      badge.appendChild(circle)
      badge.appendChild(this.text(String(this.countAll(node) - 1), 10, 13.5, { size: 9.5, weight: 700, fill: node.color, anchor: "middle" }))
      badge.addEventListener("click", (event) => { event.stopPropagation(); this.toggleCollapse(node.id) })
      group.appendChild(badge)
    }

    group.appendChild(this.hoverActions(node))
    return this.wire(group, node)
  }

  // SRS 7.4 — rê chuột vào một nút thì hiện nút lệnh bên phải:
  // + thêm nút con · ✨ gợi ý AI. Đây là cách tạo nhánh nhanh nhất.
  //
  // Hai điều phải giữ:
  //  1) Xếp NGANG, không xếp dọc — xếp dọc thì nút thứ ba tràn xuống đè nút bên dưới.
  //  2) Có một vùng trong suốt phủ cả nút lẫn cụm nút lệnh. Thiếu nó, con trỏ
  //     đi qua khoảng hở là mất :hover, cụm nút trở lại pointer-events:none và
  //     không bấm được.
  hoverActions(node) {
    const svgNS = "http://www.w3.org/2000/svg"
    const wrap = document.createElementNS(svgNS, "g")
    wrap.setAttribute("class", "x-node-actions")
    wrap.setAttribute("transform", `translate(${NODE_W + 6}, ${NODE_H / 2 - 11})`)

    const buttons = [
      { label: "+", title: "Thêm nút con", size: 15, run: () => { this.selectedId = node.id; this.addChild() } }
    ]
    if (this.aiEnabledValue) {
      buttons.push({
        label: "✨", title: "Gợi ý nhánh con bằng AI", size: 10,
        run: () => { this.select(node.id); this.runSuggest("children") }
      })
    }

    buttons.forEach((button, index) => {
      const g = document.createElementNS(svgNS, "g")
      g.setAttribute("transform", `translate(${index * 25}, 0)`)
      g.style.cursor = "pointer"

      const circle = document.createElementNS(svgNS, "circle")
      circle.setAttribute("cx", "11"); circle.setAttribute("cy", "11"); circle.setAttribute("r", "10.5")
      circle.setAttribute("fill", "#FFFFFF")
      circle.setAttribute("stroke", "#D6DEE9")
      g.appendChild(circle)

      g.appendChild(this.text(button.label, 11, button.label === "+" ? 16 : 14.5,
                              { size: button.size, weight: 600, fill: "#46566C", anchor: "middle" }))

      const title = document.createElementNS(svgNS, "title")
      title.textContent = button.title
      g.appendChild(title)

      g.addEventListener("click", (event) => { event.stopPropagation(); button.run() })
      g.addEventListener("pointerdown", (event) => event.stopPropagation())
      wrap.appendChild(g)
    })

    return wrap
  }

  // Vùng bắt hover trong suốt, phủ cả nút lẫn cụm nút lệnh bên phải.
  hoverBridge() {
    const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect")
    rect.setAttribute("x", "0"); rect.setAttribute("y", "-6")
    rect.setAttribute("width", NODE_W + 62); rect.setAttribute("height", NODE_H + 12)
    rect.setAttribute("fill", "transparent")
    return rect
  }

  text(content, x, y, options = {}) {
    const element = document.createElementNS("http://www.w3.org/2000/svg", "text")
    element.setAttribute("x", x); element.setAttribute("y", y)
    element.setAttribute("font-size", options.size || 12)
    element.setAttribute("font-weight", options.weight || 400)
    element.setAttribute("fill", options.fill || "#0D1B2E")
    element.setAttribute("font-family", '"Be Vietnam Pro", system-ui, sans-serif')
    if (options.anchor) element.setAttribute("text-anchor", options.anchor)
    if (options.spacing) element.setAttribute("letter-spacing", options.spacing)
    element.style.pointerEvents = "none"
    element.textContent = content
    return element
  }

  truncate(value, max) {
    return value.length > max ? `${value.slice(0, max - 1)}…` : value
  }

  countAll(node) {
    return 1 + node.children.reduce((sum, child) => sum + this.countAll(child), 0)
  }

  wire(group, node) {
    group.addEventListener("click", (event) => { event.stopPropagation(); this.select(node.id) })
    group.addEventListener("dblclick", (event) => { event.stopPropagation(); this.inlineEdit(node) })
    group.addEventListener("pointerdown", (event) => this.startDrag(event, node))
    return group
  }

  // ---- Danh sách phân cấp ------------------------------------------------
  renderOutline() {
    const lines = []
    const walk = (node, depth) => {
      const kids = node.children
      const collapsed = this.collapsed.has(node.id)
      const toggle = kids.length
        ? `<span class="x-outline-toggle" data-outline-toggle="${node.id}" title="${collapsed ? "Mở" : "Thu gọn"}">
             <svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor"
                  stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
                  style="transform:rotate(${collapsed ? 0 : 90}deg);transition:transform .12s">
               <path d="M4 2.5L8 6l-4 3.5"/>
             </svg>
           </span>`
        : `<span class="x-outline-bullet"></span>`

      lines.push(`
        <div class="x-outline-row ${this.selectedId === node.id ? "is-selected" : ""}"
             style="margin-left:${depth * 24}px" data-outline-id="${node.id}">
          ${toggle}
          ${node.icon ? `<span class="flex-none">${node.icon}</span>` : ""}
          <span class="flex-1 min-w-0 truncate text-[13.5px] ${depth === 0 ? "font-bold" : "font-medium"}">${this.escape(node.title)}</span>
          ${node.parentId ? `<span class="x-chip flex-none" style="background:${node.statusColor}1A;color:${node.statusColor}">${node.statusLabel}</span>` : ""}
          ${node.ownerName ? `<span class="x-muted flex-none hidden sm:block">${this.escape(node.ownerName)}</span>` : ""}
          <button type="button" class="x-outline-add" data-outline-add="${node.id}" title="Thêm nút con">
            <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
              <path d="M8 3.5v9M3.5 8h9"/>
            </svg>
          </button>
        </div>`)
      if (!collapsed) kids.forEach((kid) => walk(kid, depth + 1))
    }
    if (this.root) walk(this.root, 0)

    this.outlineTarget.innerHTML = `<div class="max-w-[760px] mx-auto">${lines.join("")}</div>`
    this.outlineTarget.querySelectorAll("[data-outline-id]").forEach((row) => {
      const id = Number(row.dataset.outlineId)

      row.querySelector("[data-outline-toggle]")?.addEventListener("click", (event) => {
        event.stopPropagation()
        this.toggleCollapse(id)
      })
      row.querySelector("[data-outline-add]")?.addEventListener("click", (event) => {
        event.stopPropagation()
        this.selectedId = id
        this.addChild()
      })
      row.addEventListener("click", () => this.select(id))
      row.addEventListener("dblclick", () => {
        const node = this.findNode(id)
        if (node) this.inlineEdit(node)
      })
    })
  }

  escape(value) {
    const div = document.createElement("div")
    div.textContent = value
    return div.innerHTML
  }

  // ---- Chọn & panel ------------------------------------------------------
  select(id) {
    this.selectedId = id
    this.renderPanel()
    if (this.viewValue === "outline") this.renderOutline()
    else this.render()
  }

  closePanel() {
    this.selectedId = null
    this.panelBodyTarget.innerHTML = '<p class="x-muted text-center py-10">Chọn một nút để xem và sửa chi tiết.</p>'
    this.render()
  }

  renderPanel() {
    const node = this.findNode(this.selectedId)
    if (!node) return

    const fragment = this.panelTemplateTarget.content.cloneNode(true)
    const field = (name) => fragment.querySelector(`[data-field="${name}"]`)
    field("title").value = node.title
    field("status").value = node.status
    field("owner_id").value = node.ownerId || ""
    field("icon").value = node.icon || ""
    field("color").value = node.ownColor || node.color
    field("note").value = node.note || ""

    fragment.querySelector('[data-slot="meta"]').textContent =
      node.updatedBy ? `Sửa gần nhất bởi ${node.updatedBy} · ${node.updatedAt}` : `Cập nhật ${node.updatedAt}`

    const ai = fragment.querySelector('[data-slot="ai"]')
    if (!this.aiEnabledValue) ai.remove()
    else fragment.querySelector('[data-slot="aiRemaining"]').textContent = this.aiRemainingValue

    this.panelBodyTarget.innerHTML = ""
    this.panelBodyTarget.appendChild(fragment)
  }

  // ---- Lưu ---------------------------------------------------------------
  async saveField(event) {
    const node = this.findNode(this.selectedId)
    if (!node) return
    const name = event.target.dataset.field
    const value = event.target.value
    const before = { title: node.title, status: node.status, owner_id: node.ownerId, icon: node.icon, color: node.ownColor, note: node.note }

    const response = await this.request(this.urlsValue.node.replace("__ID__", node.id), "PATCH", { strategy_node: { [name]: value } })
    if (!response) return

    this.pushUndo({
      redo: () => this.request(this.urlsValue.node.replace("__ID__", node.id), "PATCH", { strategy_node: { [name]: value } }),
      undo: () => this.request(this.urlsValue.node.replace("__ID__", node.id), "PATCH", { strategy_node: { [name]: before[name] } })
    })
    this.reload()
  }

  async addChild() {
    const node = this.findNode(this.selectedId) || this.root
    if (!node) return
    if (node.depth + 1 > this.maxDepthValue) {
      return this.toast(`Đã đạt giới hạn ${this.maxDepthValue} cấp. Không thể thêm nút con ở đây.`, "bad")
    }
    const title = await window.xPrompt("Thêm nút con", "", {
      hint: `Nằm trong “${node.title}”`, placeholder: "Tên nhánh…", okLabel: "Thêm", maxLength: 120
    })
    if (title === null) return
    this.collapsed.delete(node.id)
    await this.request(this.urlsValue.nodes, "POST", { parent_id: node.id, strategy_node: { title: title || "Nút mới" } })
    this.reload()
  }

  addFirst() { this.selectedId = this.root?.id; this.addChild() }

  async addSibling() {
    const node = this.findNode(this.selectedId)
    if (!node || node.parentId === null) return this.addChild()
    const parent = this.findNode(node.parentId)
    const title = await window.xPrompt("Thêm nút cùng cấp", "", {
      hint: parent ? `Nằm trong “${parent.title}”` : null, placeholder: "Tên nhánh…", okLabel: "Thêm", maxLength: 120
    })
    if (title === null) return
    await this.request(this.urlsValue.nodes, "POST", { parent_id: node.parentId, strategy_node: { title: title || "Nút mới" } })
    this.reload()
  }

  async outdent() {
    const node = this.findNode(this.selectedId)
    if (!node || node.parentId === null) return
    const parent = this.findNode(node.parentId)
    if (!parent || parent.parentId === null) return this.toast("Nút đã ở cấp cao nhất.", "warn")
    await this.request(this.urlsValue.move.replace("__ID__", node.id), "PATCH", { parent_id: parent.parentId })
    this.reload()
  }

  async duplicate() {
    const node = this.findNode(this.selectedId)
    if (!node || node.parentId === null) return this.toast("Không nhân bản được nút gốc.", "warn")
    await this.request(this.urlsValue.dup.replace("__ID__", node.id), "POST", {})
    this.reload()
  }

  async inlineEdit(node) {
    const title = await window.xPrompt("Sửa tiêu đề", node.title, { okLabel: "Lưu", maxLength: 120 })
    if (title === null || title === "" || title === node.title) return
    const before = node.title
    await this.request(this.urlsValue.node.replace("__ID__", node.id), "PATCH", { strategy_node: { title: title.trim() } })
    this.pushUndo({
      redo: () => this.request(this.urlsValue.node.replace("__ID__", node.id), "PATCH", { strategy_node: { title: title.trim() } }),
      undo: () => this.request(this.urlsValue.node.replace("__ID__", node.id), "PATCH", { strategy_node: { title: before } })
    })
    this.reload()
  }

  // ---- Xoá ---------------------------------------------------------------
  async remove() {
    const node = this.findNode(this.selectedId)
    if (!node) return
    if (node.parentId === null) return this.toast("Không xoá được nút gốc.", "warn")

    const count = this.countAll(node) - 1
    if (count === 0) {
      const ok = await window.xConfirm(`Xoá nút “${node.title}”?`, { destructive: true })
      if (!ok) return
      return this.performDelete("cascade")
    }
    this.deleteTitleTarget.textContent = node.title
    this.deleteCountTarget.textContent = count
    this.deleteCount2Target.textContent = count + 1
    this.deleteOverlayTarget.classList.remove("hidden")
  }

  closeDelete(event) {
    if (event && event.target !== event.currentTarget && !event.target.closest("[data-action*='closeDelete']")) return
    this.deleteOverlayTarget.classList.add("hidden")
  }

  deleteCascade() { this.deleteOverlayTarget.classList.add("hidden"); this.performDelete("cascade") }
  deletePromote() { this.deleteOverlayTarget.classList.add("hidden"); this.performDelete("promote") }

  async performDelete(mode) {
    const node = this.findNode(this.selectedId)
    if (!node) return
    await this.request(`${this.urlsValue.node.replace("__ID__", node.id)}?mode=${mode}`, "DELETE", {})
    this.selectedId = node.parentId
    this.reload()
  }

  // ---- Thu gọn / mở rộng -------------------------------------------------
  toggleCollapse(id) {
    if (this.collapsed.has(id)) this.collapsed.delete(id)
    else this.collapsed.add(id)
    this.render()
  }

  expandAll() { this.collapsed.clear(); this.render() }

  collapseAll() {
    this.collapsed.clear()
    const walk = (node, depth) => {
      if (depth >= 1 && node.children.length) this.collapsed.add(node.id)
      node.children.forEach((child) => walk(child, depth + 1))
    }
    if (this.root) walk(this.root, 0)
    this.render()
  }

  setLevel(event) {
    this.maxLevelValue = Number(event.target.value)
    this.collapsed.clear()
    this.seedCollapsed(this.root)
    this.render()
    const url = new URL(window.location)
    url.searchParams.set("level", this.maxLevelValue)
    window.history.replaceState({}, "", url)
  }

  // ---- Kéo thả -----------------------------------------------------------
  startDrag(event, node) {
    if (node.parentId === null || event.button !== 0) return
    event.stopPropagation()

    const origin = { x: event.clientX, y: event.clientY }
    let moved = false
    let target = null
    const group = event.currentTarget

    const onMove = (moveEvent) => {
      if (!moved && Math.hypot(moveEvent.clientX - origin.x, moveEvent.clientY - origin.y) < 5) return
      if (!moved) {
        moved = true
        group.style.opacity = "0.8"
        group.querySelector("rect").setAttribute("filter", "drop-shadow(0 8px 20px rgba(13,27,46,.2))")
      }
      const under = document.elementFromPoint(moveEvent.clientX, moveEvent.clientY)?.closest("[data-node-id]")
      const id = under ? Number(under.dataset.nodeId) : null

      this.canvasTarget.querySelectorAll("[data-node-id] rect:first-of-type").forEach((r) => r.removeAttribute("stroke-dasharray"))
      target = null
      if (id && id !== node.id && !this.isDescendant(node, id)) {
        const candidate = this.findNode(id)
        const span = this.subtreeDepth(node) - node.depth
        if (candidate.depth + 1 + span <= this.maxDepthValue) {
          target = candidate
          under.querySelector("rect").setAttribute("stroke-dasharray", "5 3")
          under.querySelector("rect").setAttribute("stroke", "#2E6BC0")
        } else {
          document.body.style.cursor = "not-allowed"
        }
      }
    }

    const onUp = async () => {
      document.removeEventListener("pointermove", onMove)
      document.removeEventListener("pointerup", onUp)
      document.body.style.cursor = ""
      group.style.opacity = ""

      if (moved && target) {
        const from = node.parentId
        const ok = await this.request(this.urlsValue.move.replace("__ID__", node.id), "PATCH", { parent_id: target.id })
        if (ok) {
          this.pushUndo({
            redo: () => this.request(this.urlsValue.move.replace("__ID__", node.id), "PATCH", { parent_id: target.id }),
            undo: () => this.request(this.urlsValue.move.replace("__ID__", node.id), "PATCH", { parent_id: from })
          })
        }
        this.reload()
      } else if (moved) {
        this.render()
      }
    }

    document.addEventListener("pointermove", onMove)
    document.addEventListener("pointerup", onUp)
  }

  isDescendant(node, id) {
    if (node.id === id) return true
    return node.children.some((child) => this.isDescendant(child, id))
  }

  subtreeDepth(node) {
    return node.children.length === 0 ? node.depth : Math.max(...node.children.map((c) => this.subtreeDepth(c)))
  }

  // ---- Pan / Zoom --------------------------------------------------------
  bindPanZoom() {
    const wrap = this.canvasWrapTarget
    let panning = false
    let start = null

    wrap.addEventListener("pointerdown", (event) => {
      if (event.target.closest("[data-node-id]")) return
      panning = true
      start = { x: event.clientX - this.pan.x, y: event.clientY - this.pan.y }
      wrap.style.cursor = "grabbing"
    })
    document.addEventListener("pointermove", (event) => {
      if (!panning) return
      this.pan = { x: event.clientX - start.x, y: event.clientY - start.y }
      this.applyTransform()
    })
    document.addEventListener("pointerup", () => { panning = false; wrap.style.cursor = "" })

    wrap.addEventListener("wheel", (event) => {
      if (!event.ctrlKey && !event.metaKey) return
      event.preventDefault()
      this.zoomBy(event.deltaY < 0 ? 1.1 : 0.9)
    }, { passive: false })

    wrap.addEventListener("click", (event) => {
      if (!event.target.closest("[data-node-id]")) this.closePanel()
    })
  }

  applyTransform() {
    if (!this.viewport) return
    this.viewport.setAttribute("transform", `translate(${this.pan.x},${this.pan.y}) scale(${this.scale})`)
    this.zoomLabelTarget.textContent = `${Math.round(this.scale * 100)}%`
  }

  zoomBy(factor) {
    this.scale = Math.min(2, Math.max(0.25, this.scale * factor))
    this.applyTransform()
  }

  zoomIn()  { this.zoomBy(1.15) }
  zoomOut() { this.zoomBy(0.87) }

  fit() {
    if (!this.bounds) return
    const rect = this.canvasWrapTarget.getBoundingClientRect()
    const width = this.bounds.maxX - this.bounds.minX
    const height = this.bounds.maxY - this.bounds.minY
    this.scale = Math.min(2, Math.max(0.25, Math.min(rect.width / width, rect.height / height) * 0.94))
    this.pan = {
      x: rect.width / 2 - (this.bounds.minX + width / 2) * this.scale,
      y: rect.height / 2 - (this.bounds.minY + height / 2) * this.scale
    }
    this.applyTransform()
  }

  home() {
    if (this.root) { this.select(this.root.id); this.centerOn(this.root.id) }
  }

  centerOn(id) {
    const item = this.positions?.get(id)
    if (!item) return
    const rect = this.canvasWrapTarget.getBoundingClientRect()
    const point = this.coords(item)
    this.pan = { x: rect.width / 2 - (point.x + NODE_W / 2) * this.scale, y: rect.height / 2 - (point.y + NODE_H / 2) * this.scale }
    this.applyTransform()
  }

  renderMinimap() {
    if (!this.bounds) return
    const width = this.bounds.maxX - this.bounds.minX
    const height = this.bounds.maxY - this.bounds.minY
    const rect = this.canvasWrapTarget.getBoundingClientRect()
    const bigger = width * this.scale > rect.width || height * this.scale > rect.height
    this.minimapTarget.classList.toggle("hidden", !bigger)
    if (!bigger) return

    const svg = this.minimapSvgTarget
    svg.setAttribute("viewBox", `${this.bounds.minX} ${this.bounds.minY} ${width} ${height}`)
    svg.innerHTML = [...this.positions.values()].map((item) => {
      const point = this.coords(item)
      return `<rect x="${point.x}" y="${point.y}" width="${NODE_W}" height="${NODE_H}" rx="8" fill="${item.node.color}" fill-opacity="0.55"/>`
    }).join("")
  }

  // ---- Tìm kiếm & lọc ----------------------------------------------------
  search() {
    const query = this.searchTarget.value.trim().toLowerCase()
    this.canvasTarget.querySelectorAll("[data-node-id]").forEach((g) => g.querySelector("rect").removeAttribute("stroke-dasharray"))
    if (!query) { this.searchHits = []; this.searchIndex = -1; this.applyFilter(); return }

    this.searchHits = []
    const walk = (node) => {
      if (node.title.toLowerCase().includes(query)) {
        this.searchHits.push(node.id)
        let parent = this.findParent(node.id)
        while (parent) { this.collapsed.delete(parent.id); parent = this.findParent(parent.id) }
      }
      node.children.forEach(walk)
    }
    if (this.root) walk(this.root)
    this.searchIndex = this.searchHits.length ? 0 : -1
    this.render()
    this.highlightHits()
    if (this.searchIndex >= 0) this.centerOn(this.searchHits[0])
  }

  searchNext(event) {
    if (event.key !== "Enter" || this.searchHits.length === 0) return
    event.preventDefault()
    this.searchIndex = (this.searchIndex + 1) % this.searchHits.length
    this.centerOn(this.searchHits[this.searchIndex])
    this.highlightHits()
  }

  highlightHits() {
    this.canvasTarget.querySelectorAll("[data-node-id]").forEach((group) => {
      const id = Number(group.dataset.nodeId)
      const box = group.querySelector("rect")
      if (this.searchHits.includes(id)) {
        box.setAttribute("stroke", "#D98324")
        box.setAttribute("stroke-width", id === this.searchHits[this.searchIndex] ? "2.5" : "1.8")
      }
    })
  }

  filter() { this.applyFilter() }

  applyFilter() {
    const status = this.statusFilterTarget.value
    const owner  = this.ownerFilterTarget.value
    this.canvasTarget.querySelectorAll("[data-node-id]").forEach((group) => {
      const node = this.findNode(Number(group.dataset.nodeId))
      if (!node || node.parentId === null) return
      const matches = (!status || node.status === status) && (!owner || String(node.ownerId) === owner)
      group.style.opacity = matches ? "1" : "0.3"
    })
  }

  // ---- ✨ AI -------------------------------------------------------------
  suggest(event) { this.runSuggest("children", event) }
  suggestSubtree(event) { this.runSuggest("subtree", event) }
  suggestForRoot() { this.select(this.root.id); this.runSuggest("children") }

  async runSuggest(mode) {
    const node = this.findNode(this.selectedId) || this.root
    if (!node) return
    if (this.selectedId !== node.id) this.select(node.id)

    const results = this.panelBodyTarget.querySelector('[data-slot="aiResults"]')
    if (!results) return this.toast("Chọn một nút rồi bấm gợi ý.", "warn")

    const instruction = this.panelBodyTarget.querySelector('[data-slot="aiInstruction"]')?.value || ""
    this.aiAbort = new AbortController()
    results.innerHTML = `
      <div class="space-y-2">
        ${[1, 2, 3, 4].map(() => '<div class="h-9 rounded-lg animate-pulse" style="background:var(--bg)"></div>').join("")}
        <button class="x-btn x-btn-ghost x-btn-sm x-btn-block" data-cancel>Huỷ</button>
      </div>`
    results.querySelector("[data-cancel]").addEventListener("click", () => {
      this.aiAbort.abort()
      results.innerHTML = '<p class="x-muted">Đã huỷ. Cây không thay đổi.</p>'
    })

    try {
      const response = await fetch(this.urlsValue.suggest.replace("__ID__", node.id), {
        method: "POST", signal: this.aiAbort.signal,
        headers: this.headers(),
        body: JSON.stringify({ mode, instruction })
      })
      const payload = await response.json()
      if (!response.ok) {
        results.innerHTML = `<div class="x-toast x-toast-bad text-[12.5px]">${this.escape(payload.error || "Không gọi được AI.")}</div>`
        return
      }
      this.aiRemainingValue = payload.remaining
      if (this.hasAiCounterTarget) this.aiCounterTarget.textContent = payload.remaining
      const badge = this.panelBodyTarget.querySelector('[data-slot="aiRemaining"]')
      if (badge) badge.textContent = payload.remaining
      this.renderSuggestions(results, payload, node)
    } catch (error) {
      if (error.name === "AbortError") return
      results.innerHTML = '<div class="x-toast x-toast-bad text-[12.5px]">Mạng có vấn đề. Cây của bạn không thay đổi.</div>'
    }
  }

  renderSuggestions(container, payload, node) {
    const items = payload.suggestions || []
    if (items.length === 0) {
      container.innerHTML = '<p class="x-muted">AI không đưa ra gợi ý nào mới.</p>'
      return
    }

    container.innerHTML = `
      <div class="space-y-1.5 mb-3">
        ${items.map((item, index) => `
          <label class="flex items-start gap-2 p-2 rounded-lg hover:bg-[var(--bg)] cursor-pointer">
            <input type="checkbox" class="x-check mt-0.5" data-suggest-index="${index}" checked>
            <span class="flex-1 min-w-0">
              <input type="text" value="${this.escape(item.title)}" data-suggest-title="${index}"
                     class="w-full bg-transparent text-[13px] font-medium border-0 p-0 focus:outline-none">
              <span class="block text-[11.5px] mt-0.5" style="color:var(--ink-3)">${this.escape(item.reason || "")}</span>
              ${item.children?.length ? `<span class="x-chip mt-1">+${item.children.length} nút con</span>` : ""}
            </span>
          </label>`).join("")}
      </div>
      <div class="flex items-center gap-2">
        <button class="x-btn x-btn-primary x-btn-sm flex-1" data-apply>Thêm vào cây (<span data-count>${items.length}</span>)</button>
        <button class="x-btn x-btn-ghost x-btn-sm" data-again>Gợi ý lại</button>
      </div>`

    const boxes = () => [...container.querySelectorAll("[data-suggest-index]")]
    const refresh = () => { container.querySelector("[data-count]").textContent = boxes().filter((b) => b.checked).length }
    boxes().forEach((box) => box.addEventListener("change", refresh))

    container.querySelector("[data-again]").addEventListener("click", () => this.runSuggest(payload.mode))
    container.querySelector("[data-apply]").addEventListener("click", async () => {
      const chosen = boxes().filter((b) => b.checked).map((b) => {
        const index = Number(b.dataset.suggestIndex)
        return { ...items[index], title: container.querySelector(`[data-suggest-title="${index}"]`).value }
      })
      if (chosen.length === 0) return this.toast("Chưa chọn gợi ý nào.", "warn")

      this.collapsed.delete(node.id)
      await this.request(this.urlsValue.apply.replace("__ID__", node.id), "POST",
                         { items: chosen, log_id: payload.log_id })
      this.reload()
    })
  }

  // ---- Dán hàng loạt -----------------------------------------------------
  openPaste() {
    if (!this.findNode(this.selectedId)) return this.toast("Chọn một nút để dán vào.", "warn")
    this.pasteInputTarget.value = ""
    this.pastePreviewTarget.innerHTML = '<p class="x-muted">Dán nội dung để xem cấu trúc sẽ được tạo.</p>'
    this.pasteCountTarget.textContent = ""
    this.pasteOverlayTarget.classList.remove("hidden")
    this.pasteInputTarget.focus()
  }

  closePaste(event) {
    if (event && event.target !== event.currentTarget && !event.target.closest("[data-action*='closePaste']")) return
    this.pasteOverlayTarget.classList.add("hidden")
  }

  async previewPaste() {
    const text = this.pasteInputTarget.value
    if (!text.trim()) { this.pastePreviewTarget.innerHTML = '<p class="x-muted">Dán nội dung để xem cấu trúc.</p>'; return }

    clearTimeout(this.pasteTimer)
    this.pasteTimer = setTimeout(async () => {
      const response = await fetch(this.urlsValue.paste, {
        method: "POST", headers: this.headers(),
        body: JSON.stringify({ parent_id: this.selectedId, text, preview: "1" })
      })
      const payload = await response.json()
      const render = (items, depth) => items.map((item) =>
        `<div style="margin-left:${depth * 16}px" class="py-0.5">${depth ? "└ " : "• "}${this.escape(item.title)}</div>` +
        render(item.children || [], depth + 1)).join("")
      this.pastePreviewTarget.innerHTML = payload.items?.length ? render(payload.items, 0)
        : '<p class="x-muted">Không nhận ra cấu trúc nào.</p>'
      this.pasteCountTarget.textContent = payload.count ? `${payload.count} nút sẽ được tạo` : ""
    }, 260)
  }

  async applyPaste() {
    const text = this.pasteInputTarget.value
    if (!text.trim()) return
    this.collapsed.delete(this.selectedId)
    await this.request(this.urlsValue.paste, "POST", { parent_id: this.selectedId, text })
    this.pasteOverlayTarget.classList.add("hidden")
    this.reload()
  }

  // ---- Xuất PNG ----------------------------------------------------------
  exportPng() {
    if (this.viewValue === "outline") return this.toast("Chuyển sang chế độ sơ đồ để xuất ảnh.", "warn")

    const clone = this.canvasTarget.cloneNode(true)
    const width = this.bounds.maxX - this.bounds.minX
    const height = this.bounds.maxY - this.bounds.minY
    clone.setAttribute("width", width)
    clone.setAttribute("height", height)
    clone.querySelector("[data-viewport]").setAttribute("transform", `translate(${-this.bounds.minX},${-this.bounds.minY})`)

    const background = document.createElementNS("http://www.w3.org/2000/svg", "rect")
    background.setAttribute("width", width); background.setAttribute("height", height); background.setAttribute("fill", "#F7F9FC")
    clone.insertBefore(background, clone.firstChild)

    const blob = new Blob([new XMLSerializer().serializeToString(clone)], { type: "image/svg+xml;charset=utf-8" })
    const url = URL.createObjectURL(blob)
    const image = new Image()
    image.onload = () => {
      const canvas = document.createElement("canvas")
      canvas.width = width * 2
      canvas.height = height * 2
      const context = canvas.getContext("2d")
      context.scale(2, 2)
      context.drawImage(image, 0, 0)
      URL.revokeObjectURL(url)
      canvas.toBlob((png) => {
        const link = document.createElement("a")
        link.href = URL.createObjectURL(png)
        link.download = "cay-dinh-huong.png"
        link.click()
      })
    }
    image.src = url
  }

  presentation() {
    document.querySelector("aside.x-nav")?.classList.toggle("hidden")
    document.querySelector("header.x-topbar")?.classList.toggle("hidden")
    this.panelTarget.classList.toggle("hidden")
    setTimeout(() => this.fit(), 60)
  }

  // ---- Phím tắt ----------------------------------------------------------
  bindGlobalKeys() {
    this.onKey = (event) => {
      const tag = event.target.tagName
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || event.target.isContentEditable) return
      if (!this.selectedId && !["f", "F"].includes(event.key)) return

      const node = this.findNode(this.selectedId)

      if (event.key === "Tab" && !event.shiftKey) { event.preventDefault(); this.addChild() }
      else if (event.key === "Tab" && event.shiftKey) { event.preventDefault(); this.outdent() }
      else if (event.key === "Enter") { event.preventDefault(); this.addSibling() }
      else if (event.key === " ") { event.preventDefault(); if (node?.children.length) this.toggleCollapse(node.id) }
      else if (event.key === "Delete" || event.key === "Backspace") { event.preventDefault(); this.remove() }
      else if (event.key === "F2") { event.preventDefault(); if (node) this.inlineEdit(node) }
      else if (event.key === "f" || event.key === "F") { this.presentation() }
      else if ((event.metaKey || event.ctrlKey) && event.key === "z" && !event.shiftKey) { event.preventDefault(); this.undo() }
      else if ((event.metaKey || event.ctrlKey) && (event.key === "y" || (event.key === "z" && event.shiftKey))) { event.preventDefault(); this.redo() }
      else if (event.key.startsWith("Arrow")) { event.preventDefault(); this.moveSelection(event.key) }
    }
    document.addEventListener("keydown", this.onKey)
  }

  moveSelection(key) {
    const node = this.findNode(this.selectedId)
    if (!node) return
    const parent = this.findParent(node.id)

    if (key === "ArrowRight") {
      if (this.collapsed.has(node.id)) return this.toggleCollapse(node.id)
      if (node.children.length) this.select(node.children[0].id)
    } else if (key === "ArrowLeft") {
      if (!this.collapsed.has(node.id) && node.children.length) return this.toggleCollapse(node.id)
      if (parent) this.select(parent.id)
    } else if (parent) {
      const siblings = parent.children
      const index = siblings.findIndex((s) => s.id === node.id)
      const next = key === "ArrowDown" ? index + 1 : index - 1
      if (siblings[next]) this.select(siblings[next].id)
    }
  }

  // ---- Hoàn tác / Làm lại -------------------------------------------------
  pushUndo(command) {
    this.undoStack.push(command)
    if (this.undoStack.length > 25) this.undoStack.shift()
    this.redoStack = []
  }

  async undo() {
    const command = this.undoStack.pop()
    if (!command) return this.toast("Không còn thao tác nào để hoàn tác.", "warn")
    await command.undo()
    this.redoStack.push(command)
    this.reload()
  }

  async redo() {
    const command = this.redoStack.pop()
    if (!command) return
    await command.redo()
    this.undoStack.push(command)
    this.reload()
  }

  // ---- Tiện ích ----------------------------------------------------------
  findNode(id, node = this.root) {
    if (!node || id == null) return null
    if (node.id === Number(id)) return node
    for (const child of node.children) {
      const found = this.findNode(id, child)
      if (found) return found
    }
    return null
  }

  findParent(id, node = this.root) {
    if (!node) return null
    if (node.children.some((child) => child.id === Number(id))) return node
    for (const child of node.children) {
      const found = this.findParent(id, child)
      if (found) return found
    }
    return null
  }

  headers() {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
    }
  }

  async request(url, method, body) {
    try {
      const response = await fetch(url, { method, headers: this.headers(), body: JSON.stringify(body) })
      const payload = await response.json().catch(() => ({}))
      if (!response.ok) { this.toast(payload.error || "Không lưu được thay đổi.", "bad"); return null }
      return payload
    } catch (error) {
      this.toast("Mất kết nối. Thay đổi chưa được lưu.", "bad")
      return null
    }
  }

  reload() {
    const url = new URL(window.location)
    if (this.selectedId) url.searchParams.set("node", this.selectedId)
    url.searchParams.set("level", this.maxLevelValue)
    window.Turbo.visit(url.toString(), { action: "replace" })
  }

  toast(message, tone = "bad") {
    const box = document.createElement("div")
    box.className = `x-toast x-toast-${tone} fixed bottom-5 left-1/2 -translate-x-1/2 z-[90] max-w-[420px] shadow-lg`
    box.textContent = message
    document.body.appendChild(box)
    setTimeout(() => box.remove(), 5000)
  }
}
