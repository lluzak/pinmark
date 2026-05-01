// app/javascript/controllers/annotation_overlay_controller.js
import { Controller } from "@hotwired/stimulus"

const ACTIVE_FLAG = "design_annotate"
const MODE_FLAG = "design_annotate_mode"
const COLLAPSED_FLAG = "design_annotate_panel_collapsed"
// URLs are relative to the engine mount path. The default mount in the
// install generator is /dev/design_annotations.
const CREATE_URL = "/dev/design_annotations/annotations"
const INDEX_URL = "/dev/design_annotations/annotations"
const DELETE_URL = (id) => `/dev/design_annotations/annotations/${encodeURIComponent(id)}`

export default class extends Controller {
  static targets = ["panel", "popoverTemplate", "popoverInput", "popoverHeader", "popoverDebug", "modeButton"]

  connect() {
    this.tree = this._readBootstrapTree()
    this.nodesById = this._indexTree(this.tree)
    this._enrichDom()

    const url = new URL(window.location.href)
    if (url.searchParams.get("annotate") === "1") {
      localStorage.setItem(ACTIVE_FLAG, "1")
      this._setCookie(ACTIVE_FLAG, "1")
    }

    this.serverComments = []
    this.active = localStorage.getItem(ACTIVE_FLAG) === "1"
    this.targetMode = localStorage.getItem(MODE_FLAG) === "component" ? "component" : "element"
    this._panelCollapsed = localStorage.getItem(COLLAPSED_FLAG) === "1"
    this._renderModeButton()
    if (this.active) this._activate()
    this._setToggleLabel(this.active)
    this._renderPanel()
    this._fetchServerComments().then(() => { this._renderPanel(); this._renderMarkers() })

    let rafId = null
    this._onResize = () => {
      if (rafId) return
      rafId = requestAnimationFrame(() => { rafId = null; this._renderMarkers() })
    }
    window.addEventListener("resize", this._onResize)
  }

  disconnect() {
    this._deactivate()
    if (this._onResize) window.removeEventListener("resize", this._onResize)
    this._clearMarkers()
    this._markersEl?.remove()
    this._markersEl = null
  }

  toggle() {
    this.active = !this.active
    if (this.active) {
      localStorage.setItem(ACTIVE_FLAG, "1")
      this._setCookie(ACTIVE_FLAG, "1")
      this._activate()
    } else {
      localStorage.removeItem(ACTIVE_FLAG)
      this._setCookie(ACTIVE_FLAG, "", -1)
      this._deactivate()
    }
  }

  refresh() {
    this._fetchServerComments().then(() => { this._renderPanel(); this._renderMarkers() })
  }

  savePopover() {
    if (!this._popover) return
    const textarea = this._popover.querySelector("textarea")
    if (!textarea) { this._closePopover(); return }
    const { nodeId, selector } = this._popoverContext

    const value = textarea.value.trim()
    if (value.length === 0) {
      this._closePopover()
      return
    }

    const excerpt = this._textExcerpt(this._currentHighlight)

    const payload = {
      path: window.location.pathname,
      capturedAt: new Date().toISOString(),
      tree: this.tree,
      replace_match: true,
      comments: [{
        node_id: nodeId,
        selector,
        comment: value,
        component: this.nodesById[nodeId]?.component || "(page-level)",
        source: this.nodesById[nodeId]?.source || null,
        text_excerpt: excerpt,
        captured_at: new Date().toISOString(),
      }],
    }

    fetch(CREATE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    })
      .then((r) => r.json())
      .then(() => this._fetchServerComments())
      .then(() => { this._renderPanel(); this._renderMarkers() })
      .catch((err) => alert(`Save failed: ${err.message || err}`))

    this._closePopover()
  }

  cancelPopover() {
    this._closePopover()
  }

  cycleTargetMode() {
    this.targetMode = this.targetMode === "component" ? "element" : "component"
    localStorage.setItem(MODE_FLAG, this.targetMode)
    this._renderModeButton()
  }

  _renderModeButton() {
    if (!this.hasModeButtonTarget) return
    const isElement = this.targetMode === "element"
    this.modeButtonTarget.textContent = isElement ? "Mode: Element" : "Mode: Component"
    this.modeButtonTarget.classList.toggle("is-element", isElement)
  }

  // --- private ---

  _activate() {
    this._onMove = (e) => this._highlightFromEvent(e)
    this._onClick = (e) => this._maybeOpenPopover(e)
    this._onMouseDown = (e) => this._marqueeMaybeStart(e)
    this._onMouseUp = (e) => this._marqueeMaybeEnd(e)
    document.addEventListener("mousemove", this._onMove, true)
    document.addEventListener("click", this._onClick, true)
    document.addEventListener("mousedown", this._onMouseDown, true)
    document.addEventListener("mouseup", this._onMouseUp, true)
    this.panelTarget.classList.add("is-open")
    this._setToggleLabel(true)
    this._ensureLabel()
  }

  _deactivate() {
    if (this._onMove) document.removeEventListener("mousemove", this._onMove, true)
    if (this._onClick) document.removeEventListener("click", this._onClick, true)
    if (this._onMouseDown) document.removeEventListener("mousedown", this._onMouseDown, true)
    if (this._onMouseUp) document.removeEventListener("mouseup", this._onMouseUp, true)
    this._clearMarquee()
    this._clearHighlight()
    this.panelTarget?.classList.remove("is-open")
    this._setToggleLabel(false)
    this._labelEl?.remove()
    this._labelEl = null
  }

  // --- marquee select ---

  _marqueeMaybeStart(e) {
    if (!this.active) return
    if (!e.shiftKey) return
    if (e.button !== 0) return
    if (this.element.contains(e.target)) return
    if (e.target.closest("#design-annotation-activator")) return

    e.preventDefault()
    e.stopPropagation()

    this._marqueeState = {
      startX: e.clientX + window.scrollX,
      startY: e.clientY + window.scrollY,
    }

    const box = document.createElement("div")
    box.className = "design-annotation-marquee"
    document.body.appendChild(box)
    this._marqueeBox = box

    this._marqueeMoveHandler = (ev) => this._marqueeUpdate(ev)
    document.addEventListener("mousemove", this._marqueeMoveHandler, true)
  }

  _marqueeUpdate(e) {
    if (!this._marqueeState || !this._marqueeBox) return
    e.preventDefault()
    const curX = e.clientX + window.scrollX
    const curY = e.clientY + window.scrollY
    const left = Math.min(this._marqueeState.startX, curX)
    const top = Math.min(this._marqueeState.startY, curY)
    const width = Math.abs(curX - this._marqueeState.startX)
    const height = Math.abs(curY - this._marqueeState.startY)
    this._marqueeBox.style.left = `${left}px`
    this._marqueeBox.style.top = `${top}px`
    this._marqueeBox.style.width = `${width}px`
    this._marqueeBox.style.height = `${height}px`
  }

  _marqueeMaybeEnd(e) {
    if (!this._marqueeState) return
    e.preventDefault()
    e.stopPropagation()

    const start = this._marqueeState
    const endX = e.clientX + window.scrollX
    const endY = e.clientY + window.scrollY
    const rect = {
      left: Math.min(start.startX, endX),
      top: Math.min(start.startY, endY),
      right: Math.max(start.startX, endX),
      bottom: Math.max(start.startY, endY),
    }
    rect.width = rect.right - rect.left
    rect.height = rect.bottom - rect.top

    this._clearMarquee()

    if (rect.width < 5 || rect.height < 5) return // accidental click

    const target = this._pickElementFromMarquee(rect)
    if (!target) return

    const phlexId = target.dataset.designAnnotationId
    target.scrollIntoView({ behavior: "smooth", block: "nearest" })
    this._currentHighlight = target
    target.classList.add("design-annotation-highlight")
    setTimeout(() => target.classList.remove("design-annotation-highlight"), 1200)

    const tr = target.getBoundingClientRect()
    this._openPopover(tr.left, tr.top, phlexId, null)
  }

  _clearMarquee() {
    if (this._marqueeBox) {
      this._marqueeBox.remove()
      this._marqueeBox = null
    }
    if (this._marqueeMoveHandler) {
      document.removeEventListener("mousemove", this._marqueeMoveHandler, true)
      this._marqueeMoveHandler = null
    }
    this._marqueeState = null
  }

  _pickElementFromMarquee(marquee) {
    const candidates = Array.from(document.querySelectorAll("[data-design-annotation-id]"))
      .map((el) => {
        const r = el.getBoundingClientRect()
        const docRect = {
          left: r.left + window.scrollX,
          top: r.top + window.scrollY,
          right: r.right + window.scrollX,
          bottom: r.bottom + window.scrollY,
        }
        const intersects = !(docRect.right < marquee.left || docRect.left > marquee.right ||
                             docRect.bottom < marquee.top || docRect.top > marquee.bottom)
        const containedInMarquee = docRect.left >= marquee.left && docRect.top >= marquee.top &&
                                   docRect.right <= marquee.right && docRect.bottom <= marquee.bottom
        const containsMarquee = docRect.left <= marquee.left && docRect.top <= marquee.top &&
                                docRect.right >= marquee.right && docRect.bottom >= marquee.bottom
        const area = (docRect.right - docRect.left) * (docRect.bottom - docRect.top)
        return { el, area, intersects, containedInMarquee, containsMarquee }
      })
      .filter((c) => c.intersects)

    const containedInMarquee = candidates.filter((c) => c.containedInMarquee)
    if (containedInMarquee.length > 0) {
      // Largest fully-contained = highest-in-hierarchy fitting visible
      return containedInMarquee.sort((a, b) => b.area - a.area)[0].el
    }

    const containingMarquee = candidates.filter((c) => c.containsMarquee)
    if (containingMarquee.length > 0) {
      // Smallest enclosing ancestor
      return containingMarquee.sort((a, b) => a.area - b.area)[0].el
    }

    return null
  }

  _ensureLabel() {
    if (this._labelEl) return
    const el = document.createElement("div")
    el.className = "design-annotation-label"
    el.style.display = "none"
    this.element.appendChild(el)
    this._labelEl = el
  }

  _updateLabel(targetEl, isTagMode, componentEl) {
    if (!this._labelEl) return
    const nodeId = componentEl?.dataset.designAnnotationId
    const componentName = nodeId ? this.nodesById[nodeId]?.component : null
    let text
    if (isTagMode && componentEl) {
      const selector = this._domPathRelativeTo(componentEl, targetEl)
      text = `${selector} inside ${componentName || "(unknown)"}`
    } else if (isTagMode) {
      const selector = this._domPathRelativeTo(document.body, targetEl)
      text = `${selector} (page-level)`
    } else {
      text = componentName || "(unknown)"
    }
    this._labelEl.textContent = text
    this._labelEl.classList.toggle("is-tag", isTagMode)

    const r = targetEl.getBoundingClientRect()
    const margin = 4
    let top = r.top - 22
    if (top < margin) top = r.bottom + 4
    let left = r.left
    const vw = window.innerWidth
    if (left + 200 > vw - margin) left = Math.max(margin, vw - 200 - margin)
    this._labelEl.style.left = `${left}px`
    this._labelEl.style.top = `${top}px`
    this._labelEl.style.display = "block"
  }

  _setToggleLabel(active) {
    const btn = this.element.querySelector(".design-annotation-toggle")
    if (!btn) return
    btn.classList.toggle("is-active", active)
    btn.textContent = active ? "Stop annotating" : "Annotate"
  }

  _highlightFromEvent(e) {
    const altMode = e.altKey
    const target = document.elementFromPoint(e.clientX, e.clientY)
    if (!target) return
    if (this.element.contains(target)) {
      this._clearHighlight()
      return
    }
    if (target.closest("#design-annotation-activator")) {
      this._clearHighlight()
      return
    }
    const componentEl = target.closest("[data-design-annotation-id]")
    const wantsTag = this.targetMode === "element" ? !altMode : altMode

    let isTagMode, next
    if (componentEl) {
      isTagMode = wantsTag && componentEl.contains(target) && target !== componentEl
      next = isTagMode ? target : componentEl
    } else if (wantsTag) {
      // Free element targeting: highlight any element on the page even when
      // it's outside any annotated component (e.g. layout wrapper divs).
      isTagMode = true
      next = target
    } else {
      this._clearHighlight()
      return
    }

    if (next === this._currentHighlight) {
      // Same primary highlight target, but tag-mode might have flipped
      if (isTagMode && componentEl && componentEl !== next) {
        if (this._currentContextHighlight !== componentEl) {
          this._currentContextHighlight?.classList.remove("design-annotation-highlight-context")
          componentEl.classList.add("design-annotation-highlight-context")
          this._currentContextHighlight = componentEl
        }
      } else if (this._currentContextHighlight) {
        this._currentContextHighlight.classList.remove("design-annotation-highlight-context")
        this._currentContextHighlight = null
      }
      this._updateLabel(next, isTagMode, componentEl)
      return
    }

    this._clearHighlight()
    next.classList.add(isTagMode ? "design-annotation-highlight-tag" : "design-annotation-highlight")
    this._currentHighlight = next

    if (isTagMode && componentEl && componentEl !== next) {
      componentEl.classList.add("design-annotation-highlight-context")
      this._currentContextHighlight = componentEl
    }

    this._currentHighlightComponent = componentEl
    this._updateLabel(next, isTagMode, componentEl)
  }

  _clearHighlight() {
    if (this._currentHighlight) {
      this._currentHighlight.classList.remove(
        "design-annotation-highlight",
        "design-annotation-highlight-tag"
      )
    }
    if (this._currentContextHighlight) {
      this._currentContextHighlight.classList.remove("design-annotation-highlight-context")
    }
    this._currentHighlight = null
    this._currentContextHighlight = null
    this._currentHighlightComponent = null
    if (this._labelEl) this._labelEl.style.display = "none"
  }

  _maybeOpenPopover(e) {
    if (!this.active) return
    if (this.element.contains(e.target)) return
    if (e.target.closest("#design-annotation-activator")) return
    const componentEl = e.target.closest("[data-design-annotation-id]")
    const wantsTag = this.targetMode === "element" ? !e.altKey : e.altKey

    let nodeId, selector
    if (componentEl) {
      const altMode = wantsTag && e.target !== componentEl
      nodeId = componentEl.dataset.designAnnotationId
      selector = altMode ? this._domPathRelativeTo(componentEl, e.target) : null
    } else if (wantsTag) {
      // Page-level free target: no annotated ancestor.
      nodeId = null
      selector = this._domPathRelativeTo(document.body, e.target)
    } else {
      return
    }

    e.preventDefault()
    e.stopPropagation()
    this._openPopover(e.clientX, e.clientY, nodeId, selector)
  }

  _openPopover(x, y, nodeId, selector) {
    this._closePopover()

    if (!this.hasPopoverTemplateTarget || !this.popoverTemplateTarget.content.firstElementChild) {
      console.warn("[design-annotation] popover template missing")
      return
    }

    const node = this.popoverTemplateTarget.content.firstElementChild.cloneNode(true)
    const textarea = node.querySelector("textarea")
    if (!textarea) return

    textarea.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey && !e.ctrlKey && !e.metaKey && !e.altKey) {
        e.preventDefault()
        this.savePopover()
      } else if (e.key === "Escape") {
        e.preventDefault()
        this.cancelPopover()
      }
    })

    const path = window.location.pathname
    const existing = (this.serverComments || []).find(
      (c) => c.node_id === nodeId
        && (c.selector || null) === selector
        && (c.page_path || null) === path
    )
    if (existing) textarea.value = existing.comment
    this._fillPopoverDetails(node, nodeId, selector)

    // Render off-screen first to measure
    node.style.left = "-9999px"
    node.style.top = "-9999px"
    this.element.appendChild(node)
    this._popover = node

    // Anchor to the highlighted element when possible; fall back to click coords
    const anchor =
      this._currentHighlight ||
      (selector && this._currentHighlight) ||
      document.querySelector(`[data-design-annotation-id="${CSS.escape(nodeId)}"]`)

    const margin = 8
    const popoverRect = node.getBoundingClientRect()
    const vw = window.innerWidth
    const vh = window.innerHeight

    let left, top
    if (anchor) {
      const a = anchor.getBoundingClientRect()
      left = a.right + margin
      top = a.top
      if (left + popoverRect.width > vw - margin) {
        left = Math.max(margin, a.left - popoverRect.width - margin)
      }
      if (top + popoverRect.height > vh - margin) {
        top = Math.max(margin, vh - popoverRect.height - margin)
      }
      if (top < margin) top = margin
    } else {
      left = Math.min(Math.max(margin, x + margin), vw - popoverRect.width - margin)
      top = Math.min(Math.max(margin, y + margin), vh - popoverRect.height - margin)
    }

    node.style.left = `${left}px`
    node.style.top = `${top}px`

    this._popoverContext = { nodeId, selector }
    textarea.focus()
  }

  _closePopover() {
    this._popover?.remove()
    this._popover = null
    this._popoverContext = null
  }

  _fillPopoverDetails(popoverNode, nodeId, selector) {
    const node = nodeId ? this.nodesById[nodeId] : null

    const header = popoverNode.querySelector('[data-annotation-overlay-target="popoverHeader"]')
    if (header) {
      header.textContent = ""
      const title = document.createElement("div")
      title.textContent = node ? node.component : "(page-level element)"
      header.appendChild(title)

      if (node) {
        const src = document.createElement("span")
        src.className = "mcp-source"
        src.textContent = node.source
        header.appendChild(src)
      }

      if (selector) {
        const sel = document.createElement("span")
        sel.className = "mcp-selector"
        sel.textContent = selector
        header.appendChild(sel)
      }
    }

    const debug = popoverNode.querySelector('[data-annotation-overlay-target="popoverDebug"]')
    if (debug) {
      debug.textContent = ""
      const tree = document.createElement("pre")
      const lines = []
      lines.push(`node_id: ${nodeId || "(none — page-level element)"}`)
      lines.push(`component: ${node ? node.component : "(none)"}`)
      lines.push(`source: ${node ? node.source : "(none)"}`)
      if (selector) {
        const label = node ? "selector (relative to component)" : "selector (relative to <body>)"
        lines.push(`${label}: ${selector}`)
      }
      if (node) {
        lines.push("")
        lines.push("Component ancestry (root → leaf):")
        const ancestry = this._componentAncestry(nodeId)
        ancestry.forEach((n, i) => {
          lines.push(`${"  ".repeat(i)}└ ${n.component}  (${n.id}, ${n.source})`)
        })
      }
      tree.textContent = lines.join("\n")
      debug.appendChild(tree)
    }
  }

  _componentAncestry(nodeId) {
    const chain = []
    let current = this.nodesById[nodeId]
    while (current) {
      chain.unshift(current)
      current = current.parent_id ? this.nodesById[current.parent_id] : null
    }
    return chain
  }

  _renderPanel() {
    const comments = this.serverComments || []
    const pending = comments.filter((c) => c.status !== "addressed")
    const addressed = comments.filter((c) => c.status === "addressed")
    const ordered = [...pending, ...addressed]
    this.panelTarget.innerHTML = ""
    this.panelTarget.classList.toggle("is-collapsed", !!this._panelCollapsed)

    const headerRow = document.createElement("div")
    headerRow.className = "design-annotation-panel-header"

    const heading = document.createElement("strong")
    heading.textContent = `Annotations (${pending.length} pending`
    if (addressed.length > 0) heading.textContent += ` • ${addressed.length} resolved`
    heading.textContent += ")"
    headerRow.appendChild(heading)

    const collapseBtn = document.createElement("button")
    collapseBtn.type = "button"
    collapseBtn.className = "design-annotation-panel-collapse"
    collapseBtn.textContent = this._panelCollapsed ? "+" : "−"
    collapseBtn.title = this._panelCollapsed ? "Expand panel" : "Collapse panel"
    collapseBtn.addEventListener("click", () => {
      this._panelCollapsed = !this._panelCollapsed
      if (this._panelCollapsed) {
        localStorage.setItem(COLLAPSED_FLAG, "1")
      } else {
        localStorage.removeItem(COLLAPSED_FLAG)
      }
      this._renderPanel()
    })
    headerRow.appendChild(collapseBtn)

    this.panelTarget.appendChild(headerRow)

    if (this._panelCollapsed) return

    ordered.forEach((c) => {
      const isResolved = c.status === "addressed"
      const row = document.createElement("div")
      row.style.borderTop = "1px solid #333"
      row.style.padding = "6px 0"
      if (isResolved) row.style.opacity = ".55"

      const titleLine = document.createElement("div")
      titleLine.textContent = c.component || "(unknown)"
      if (c.selector) {
        const code = document.createElement("code")
        code.textContent = ` ${c.selector}`
        titleLine.appendChild(code)
      }
      if (isResolved) {
        const badge = document.createElement("span")
        badge.textContent = " ✓ resolved"
        badge.style.color = "#34d399"
        badge.style.fontSize = "10px"
        badge.style.marginLeft = "4px"
        titleLine.appendChild(badge)
      }
      row.appendChild(titleLine)

      const sourceLine = document.createElement("div")
      sourceLine.style.opacity = ".7"
      sourceLine.textContent = c.source || ""
      row.appendChild(sourceLine)

      const pathLine = document.createElement("div")
      pathLine.style.opacity = ".6"
      pathLine.style.fontSize = "11px"
      pathLine.textContent = c.page_path || ""
      row.appendChild(pathLine)

      const commentLine = document.createElement("div")
      commentLine.textContent = c.comment
      if (isResolved) commentLine.style.textDecoration = "line-through"
      row.appendChild(commentLine)

      const actions = document.createElement("div")
      actions.style.marginTop = "4px"
      const del = document.createElement("a")
      del.href = "#"
      del.textContent = "Delete"
      del.style.color = "#f97316"
      del.style.fontSize = "11px"
      del.addEventListener("click", (ev) => {
        ev.preventDefault()
        this._deleteComment(c.id)
      })
      actions.appendChild(del)
      row.appendChild(actions)

      this.panelTarget.appendChild(row)
    })

    const refreshBtn = document.createElement("button")
    refreshBtn.type = "button"
    refreshBtn.textContent = "Refresh"
    refreshBtn.style.marginTop = "8px"
    refreshBtn.addEventListener("click", () => this.refresh())
    this.panelTarget.appendChild(refreshBtn)
  }

  _fetchServerComments() {
    return fetch(INDEX_URL, { headers: { "Accept": "application/json" } })
      .then((r) => r.json())
      .then((j) => {
        this.serverComments = Array.isArray(j.annotations) ? j.annotations : []
      })
      .catch(() => {
        this.serverComments = []
      })
  }

  _deleteComment(id) {
    if (!id) return
    fetch(DELETE_URL(id), { method: "DELETE", headers: { "Accept": "application/json" } })
      .then(() => this._fetchServerComments())
      .then(() => { this._renderPanel(); this._renderMarkers() })
      .catch((err) => alert(`Delete failed: ${err.message || err}`))
  }

  _markersContainer() {
    if (this._markersEl && document.body.contains(this._markersEl)) return this._markersEl
    const el = document.createElement("div")
    el.className = "design-annotation-markers"
    document.body.appendChild(el)
    this._markersEl = el
    return el
  }

  _clearMarkers() {
    if (this._markersEl) this._markersEl.innerHTML = ""
  }

  _renderMarkers() {
    const container = this._markersContainer()
    container.innerHTML = ""

    const path = window.location.pathname
    const onPage = (this.serverComments || []).filter((c) => (c.page_path || null) === path)

    onPage.forEach((c, idx) => {
      const root = document.querySelector(`[data-design-annotation-id="${CSS.escape(c.node_id)}"]`)
      if (!root) return
      let target = root
      if (c.selector) {
        try { target = root.querySelector(c.selector) || root } catch (_) { /* invalid selector */ }
      }
      const r = target.getBoundingClientRect()
      if (r.width === 0 && r.height === 0) return // detached / hidden

      const isResolved = c.status === "addressed"
      const marker = document.createElement("button")
      marker.type = "button"
      marker.className = "design-annotation-marker" + (isResolved ? " is-resolved" : "")
      marker.textContent = isResolved ? "✓" : String(idx + 1)
      marker.title = `${c.component || ""} — ${c.comment || ""}`.trim()
      marker.style.left = `${r.left + window.scrollX}px`
      marker.style.top = `${r.top + window.scrollY}px`
      marker.addEventListener("click", (ev) => {
        ev.preventDefault()
        ev.stopPropagation()
        target.scrollIntoView({ behavior: "smooth", block: "center" })
        // Briefly highlight target
        target.classList.add("design-annotation-highlight")
        setTimeout(() => target.classList.remove("design-annotation-highlight"), 1200)
        // Open the popover so the user can re-read / edit / delete
        this._currentHighlight = target
        this._openPopover(r.left, r.top, c.node_id, c.selector || null)
      })
      container.appendChild(marker)
    })
  }

  _readBootstrapTree() {
    const el = document.getElementById("design-annotation-tree")
    if (!el) return []
    try {
      return JSON.parse(el.textContent)
    } catch {
      return []
    }
  }

  _indexTree(nodes, acc = {}) {
    for (const node of nodes) {
      acc[node.id] = node
      this._indexTree(node.children || [], acc)
    }
    return acc
  }

  _enrichDom() {
    const walker = document.createTreeWalker(document.documentElement, NodeFilter.SHOW_COMMENT)
    const open = []
    while (walker.nextNode()) {
      const text = walker.currentNode.nodeValue.trim()
      const begin = text.match(/^design-annotation:begin id="([^"]+)"/)
      const end = text.match(/^design-annotation:end id="([^"]+)"/)
      if (begin) {
        open.push({ id: begin[1], commentNode: walker.currentNode })
      } else if (end) {
        const top = open.pop()
        if (!top) continue
        if (top.id !== end[1]) {
          console.warn(`[design-annotation] marker mismatch: begin=${top.id} end=${end[1]}`)
          continue
        }
        let sibling = top.commentNode.nextSibling
        while (sibling && sibling !== walker.currentNode) {
          if (sibling.nodeType === 1) {
            if (!sibling.hasAttribute("data-design-annotation-id")) {
              sibling.setAttribute("data-design-annotation-id", top.id)
            } else {
              const existing = sibling.getAttribute("data-design-annotation-ids") || sibling.getAttribute("data-design-annotation-id")
              const ids = new Set(existing.split(/\s+/))
              ids.add(top.id)
              sibling.setAttribute("data-design-annotation-ids", [...ids].join(" "))
            }
          }
          sibling = sibling.nextSibling
        }
      }
    }
  }

  _domPathRelativeTo(root, target) {
    const parts = []
    let el = target
    while (el && el !== root) {
      const parent = el.parentElement
      if (!parent) break

      const tag = el.tagName.toLowerCase()
      let segment = tag

      if (el.id) {
        segment += `#${this._escapeIdent(el.id)}`
      }

      const classes = this._meaningfulClasses(el)
      if (classes.length > 0) {
        segment += `.${classes.map((c) => this._escapeIdent(c)).join(".")}`
      }

      const sameTagSiblings = Array.from(parent.children).filter(
        (c) => c.tagName === el.tagName
      )
      if (sameTagSiblings.length > 1) {
        const index = sameTagSiblings.indexOf(el) + 1
        segment += `:nth-of-type(${index})`
      }

      parts.unshift(segment)
      el = parent
    }
    return parts.join(" > ")
  }

  _meaningfulClasses(el) {
    if (!el.classList || el.classList.length === 0) return []
    const skipExact = new Set([
      "design-annotation-highlight",
      "design-annotation-highlight-tag",
    ])
    return Array.from(el.classList).filter(
      (c) => !skipExact.has(c) && !c.startsWith("design-annotation-")
    )
  }

  _escapeIdent(value) {
    if (typeof CSS !== "undefined" && typeof CSS.escape === "function") {
      return CSS.escape(value)
    }
    return value.replace(/[^a-zA-Z0-9_-]/g, "\\$&")
  }

  _textExcerpt(el) {
    if (!el) return null
    const text = (el.textContent || "").replace(/\s+/g, " ").trim()
    if (text.length === 0) return null
    return text.length > 120 ? `${text.slice(0, 117)}…` : text
  }

  _setCookie(name, value, days = 30) {
    const expires =
      days < 0
        ? "expires=Thu, 01 Jan 1970 00:00:00 GMT"
        : `expires=${new Date(Date.now() + days * 864e5).toUTCString()}`
    document.cookie = `${name}=${value}; path=/; ${expires}`
  }
}
