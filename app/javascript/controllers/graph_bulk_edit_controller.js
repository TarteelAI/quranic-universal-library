import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    document.querySelectorAll(".node-row").forEach((row) => {
      const nodeId = row.dataset.nodeId;
      const typeSelect = row.querySelector(".node-type-select");
      if (typeSelect && typeSelect.value) {
        this.updateResourceType(nodeId, typeSelect.value);
      }
    });
  }

  handleNodeTypeChange(event) {
    const nodeId = event.target.dataset.nodeId;
    const nodeType = event.target.value;
    const graphId = this.getGraphId();

    console.log("=== handleNodeTypeChange ===");
    console.log("Node ID:", nodeId);
    console.log("Node Type:", nodeType);
    console.log("Turbo Frame ID:", `node_${nodeId}_fields`);

    fetch(
      `/morphology/treebank/update_node_fields?graph_id=${graphId}&node_id=${nodeId}&node_type=${nodeType}`,
      {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
        },
      }
    )
      .then((response) => response.text())
      .then((html) => {
        console.log("Turbo Stream Response:", html);
        Turbo.renderStreamMessage(html);
        if (nodeType === "phrase") {
          this.updatePhraseDropdowns();
        }
        this.updateResourceType(nodeId, nodeType);
      })
      .catch((error) => {
        console.error("Error updating node fields:", error);
      });
  }

  updateResourceType(nodeId, nodeType) {
    const row = document.querySelector(`.node-row[data-node-id="${nodeId}"]`);
    if (!row) return;

    const resourceTypeSelect = row.querySelector(".resource-type-select");
    if (!resourceTypeSelect) return;

    if (nodeType === "word" || nodeType === "reference") {
      resourceTypeSelect.value = "Morphology::Word";
    } else if (nodeType === "phrase") {
      resourceTypeSelect.value = "Morphology::GraphNodeEdge";
    } else if (nodeType === "elided") {
      resourceTypeSelect.value = "";
    }
  }

  updatePhraseValue(event) {
    const nodeId = event.currentTarget.dataset.nodeId;
    const row = document.querySelector(`.node-row[data-node-id="${nodeId}"]`);
    if (!row) return;

    const posInput = row.querySelector(".phrase-pos-input");
    const sourceSelect = row.querySelector(".phrase-source-select");
    const targetSelect = row.querySelector(".phrase-target-select");
    const valueField = row.querySelector(".phrase-value-field");
    const posField = row.querySelector(".phrase-pos-field");

    if (!posInput || !sourceSelect || !targetSelect || !valueField) return;

    const pos = posInput.value.trim();
    const source = sourceSelect.value;
    const target = targetSelect.value;

    if (pos && source && target) {
      valueField.value = `${pos}(n${source} - n${target})`;
    } else if (pos) {
      valueField.value = pos;
    } else {
      valueField.value = "";
    }

    if (posField) {
      posField.value = pos;
    }
  }

  updatePhraseDropdowns() {
    const nodeNumbers = [];
    document.querySelectorAll(".node-row").forEach((row) => {
      const numberCell = row.querySelector(".node-number");
      if (numberCell) {
        const numberText = numberCell.textContent.trim();
        if (numberText.startsWith("new-number-")) {
          return;
        }
        const match = numberText.match(/n(\d+)/);
        if (match) {
          nodeNumbers.push({
            display: numberText,
            value: match[1],
          });
        }
      }
    });

    document
      .querySelectorAll(".phrase-source-select, .phrase-target-select")
      .forEach((select) => {
        const currentValue = select.value;

        select.innerHTML = '<option value="">Select</option>';
        nodeNumbers.forEach((node) => {
          const option = document.createElement("option");
          option.value = node.value;
          option.textContent = node.display;
          if (node.value === currentValue) {
            option.selected = true;
          }
          select.appendChild(option);
        });
      });
  }

  showField(cell) {
    if (!cell) return;
    const content = cell.querySelector(".field-content");
    const placeholder = cell.querySelector(".field-placeholder");
    if (content) content.style.display = "block";
    if (placeholder) placeholder.style.display = "none";
  }

  hideField(cell) {
    if (!cell) return;
    const content = cell.querySelector(".field-content");
    const placeholder = cell.querySelector(".field-placeholder");
    if (content) content.style.display = "none";
    if (placeholder) placeholder.style.display = "block";
  }

  updateResourceDropdown(nodeId, resourceType) {
    const container = document.querySelector(
      `.resource-dropdowns[data-node-id="${nodeId}"]`
    );
    if (!container) return;

    const wordDisplay = container.querySelector(".word-resource-display");
    const edgeDropdown = container.querySelector(".edge-resource-dropdown");

    if (wordDisplay) wordDisplay.style.display = "none";
    if (edgeDropdown) edgeDropdown.style.display = "none";

    if (resourceType === "Morphology::Word" && wordDisplay) {
      wordDisplay.style.display = "block";
      this.updateSegmentField(nodeId, true);
    } else if (resourceType === "Morphology::GraphNodeEdge" && edgeDropdown) {
      edgeDropdown.style.display = "block";
      this.updateSegmentField(nodeId, false);
    }
  }

  updateSegmentField(nodeId, showDisplay) {
    const row = document.querySelector(`.node-row[data-node-id="${nodeId}"]`);
    if (!row) return;

    const segmentField = row.querySelector(".segment-field");
    if (!segmentField) return;

    const segmentDisplay = segmentField.querySelector(".segment-display");
    const segmentDropdown = segmentField.querySelector(".segment-dropdown");

    if (showDisplay) {
      if (segmentDisplay) segmentDisplay.style.display = "block";
      if (segmentDropdown) segmentDropdown.style.display = "none";
    } else {
      if (segmentDisplay) segmentDisplay.style.display = "none";
      if (segmentDropdown) segmentDropdown.style.display = "block";
    }
  }

  handleResourceTypeChange(event) {
    const nodeId = event.target.dataset.nodeId;
    const resourceType = event.target.value;
    this.updateResourceDropdown(nodeId, resourceType);
  }

  removeNode(event) {
    const nodeId = event.currentTarget.dataset.nodeId;
    const row = document.querySelector(`.node-row[data-node-id="${nodeId}"]`);

    if (!row) return;

    if (
      !confirm(
        "Are you sure you want to remove this node? This will also remove any edges connected to it."
      )
    ) {
      return;
    }

    const destroyFlag = row.querySelector(".destroy-flag");
    if (destroyFlag) {
      destroyFlag.value = "1";
    }
    row.style.opacity = "0.5";
    row.style.textDecoration = "line-through";

    row.querySelectorAll("input, select, button").forEach((input) => {
      if (!input.classList.contains("destroy-flag")) {
        input.disabled = true;
      }
    });

    const removeBtn = event.currentTarget;
    removeBtn.innerHTML = '<i class="fa fa-undo"></i> Undo';
    removeBtn.classList.remove("btn-danger");
    removeBtn.classList.add("btn-warning");
    removeBtn.disabled = false;
    removeBtn.dataset.action = "click->graph-bulk-edit#undoRemoveNode";
  }

  undoRemoveNode(event) {
    const nodeId = event.currentTarget.dataset.nodeId;
    const row = document.querySelector(`.node-row[data-node-id="${nodeId}"]`);

    if (!row) return;

    const destroyFlag = row.querySelector(".destroy-flag");
    if (destroyFlag) {
      destroyFlag.value = "0";
    }
    row.style.opacity = "1";
    row.style.textDecoration = "none";

    row.querySelectorAll("input, select, button").forEach((input) => {
      if (!input.classList.contains("destroy-flag")) {
        input.disabled = false;
      }
    });

    const removeBtn = event.currentTarget;
    removeBtn.innerHTML = '<i class="fa fa-trash"></i>';
    removeBtn.classList.remove("btn-warning");
    removeBtn.classList.add("btn-danger");
    removeBtn.dataset.action = "click->graph-bulk-edit#removeNode";
  }

  addNodeAfter(event) {
    event.preventDefault();
    const currentNodeId = event.currentTarget.dataset.nodeId;
    const graphId = this.getGraphId();

    fetch(
      `/morphology/treebank/add_node_row?graph_id=${graphId}&after_node_id=${currentNodeId}`,
      {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
        },
      }
    )
      .then((response) => response.text())
      .then((html) => {
        Turbo.renderStreamMessage(html);
        this.updatePhraseDropdowns();
        this.updateNodeCount();
      })
      .catch((error) => {
        console.error("Error adding node:", error);
      });
  }

  removeNewNode(event) {
    const nodeId = event.currentTarget.dataset.nodeId;
    const row = document.querySelector(`.node-row[data-node-id="${nodeId}"]`);
    const turboFrame = document.querySelector(`#new_node_after_${nodeId}`);

    if (!row) return;

    if (confirm("Remove this new node?")) {
      row.remove();
      if (turboFrame) turboFrame.remove();
      this.updateNodeCount();
      this.updatePhraseDropdowns();
    }
  }

  getGraphId() {
    const form = document.querySelector("form");
    const graphIdInput = form?.querySelector('input[name="graph_id"]');
    return graphIdInput?.value || "";
  }

  updateNodeCount() {
    const rows = document.querySelectorAll(
      '.node-row:not([style*="display: none"])'
    );
    const countSpan = document.querySelector(".node-count");
    if (countSpan) {
      countSpan.textContent = rows.length;
    }
  }

  addEdgeRow(event) {
    event.preventDefault();
    const edgesSection = event.currentTarget.closest(".edit-section");
    const tbody = edgesSection?.querySelector(".edit-table tbody");
    if (!tbody) {
      console.error("Could not find edges table tbody");
      return;
    }

    const timestamp = Date.now();
    const tempId = `new_${timestamp}`;
    const availableNodes = this.getAvailableNodesForEdges();

    const newRow = document.createElement("tr");
    newRow.className = "edge-row edge-type-word";
    newRow.dataset.edgeId = tempId;
    newRow.innerHTML = `
      <td class="edge-id">NEW</td>
      <td>
        <span class="status_tag word">Word</span>
      </td>
      <td>
        <select name="new_edges[${tempId}][source_id]" class="form-select">
          <option value="">Select Source</option>
          ${availableNodes}
        </select>
      </td>
      <td>
        <select name="new_edges[${tempId}][target_id]" class="form-select">
          <option value="">Select Target</option>
          ${availableNodes}
        </select>
      </td>
      <td>
        <input type="text" 
               name="new_edges[${tempId}][relation]" 
               class="form-control" 
               list="edge-relations" 
               placeholder="Relation">
      </td>
      <td class="actions-cell">
        <button type="button" 
                class="btn btn-danger btn-sm remove-edge-btn bg-white"
                data-edge-id="${tempId}"
                data-action="click->graph-bulk-edit#removeNewEdge"
                title="Remove edge">
          <i class="fa fa-trash"></i>
        </button>
      </td>
    `;

    tbody.appendChild(newRow);
    this.updateEdgeCount();
  }

  removeEdge(event) {
    const edgeId = event.currentTarget.dataset.edgeId;
    const row = document.querySelector(`.edge-row[data-edge-id="${edgeId}"]`);
    if (!row) return;

    if (!confirm("Mark this edge for deletion?")) return;

    const destroyFlag = row.querySelector(".destroy-flag");
    if (destroyFlag) {
      destroyFlag.value = "1";
    }

    row.style.opacity = "0.5";
    row.style.textDecoration = "line-through";

    row.querySelectorAll("input, select, button").forEach((input) => {
      if (!input.classList.contains("destroy-flag")) {
        input.disabled = true;
      }
    });

    const removeBtn = event.currentTarget;
    removeBtn.innerHTML = '<i class="fa fa-undo"></i> Undo';
    removeBtn.classList.remove("btn-danger");
    removeBtn.classList.add("btn-warning");
    removeBtn.disabled = false;
    removeBtn.dataset.action = "click->graph-bulk-edit#undoRemoveEdge";
  }

  undoRemoveEdge(event) {
    const edgeId = event.currentTarget.dataset.edgeId;
    const row = document.querySelector(`.edge-row[data-edge-id="${edgeId}"]`);
    if (!row) return;

    const destroyFlag = row.querySelector(".destroy-flag");
    if (destroyFlag) {
      destroyFlag.value = "0";
    }

    row.style.opacity = "1";
    row.style.textDecoration = "none";

    row.querySelectorAll("input, select, button").forEach((input) => {
      if (!input.classList.contains("destroy-flag")) {
        input.disabled = false;
      }
    });

    const removeBtn = event.currentTarget;
    removeBtn.innerHTML = '<i class="fa fa-trash"></i>';
    removeBtn.classList.remove("btn-warning");
    removeBtn.classList.add("btn-danger");
    removeBtn.dataset.action = "click->graph-bulk-edit#removeEdge";
  }

  removeNewEdge(event) {
    const edgeId = event.currentTarget.dataset.edgeId;
    const row = document.querySelector(`.edge-row[data-edge-id="${edgeId}"]`);
    if (!row) return;

    if (confirm("Remove this new edge?")) {
      row.remove();
      this.updateEdgeCount();
    }
  }

  getAvailableNodesForEdges() {
    const nodes = [];
    document.querySelectorAll(".node-row").forEach((row) => {
      const nodeId = row.querySelector(".node-id")?.textContent?.trim();
      const nodeNumber = row.querySelector(".node-number")?.textContent?.trim();
      const nodeType = row.querySelector(".node-type-select")?.value;

      if (
        nodeId &&
        nodeId !== "NEW" &&
        nodeNumber &&
        !nodeNumber.startsWith("new-number-")
      ) {
        nodes.push(
          `<option value="${nodeId}">${nodeNumber} - ${nodeType}</option>`
        );
      }
    });
    return nodes.join("");
  }

  updateEdgeCount() {
    const rows = document.querySelectorAll(
      '.edge-row:not([style*="display: none"])'
    );
    const heading = document.querySelector(".edit-section h2");
    if (heading) {
      heading.textContent = `Graph Edges (${rows.length})`;
    }
  }
}
