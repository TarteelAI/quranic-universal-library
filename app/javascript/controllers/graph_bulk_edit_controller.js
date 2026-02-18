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

  refreshGraphPreview() {
    window.dispatchEvent(new CustomEvent("refresh-graph-preview"));
  }

  saveNodeField(event) {
    const input = event.target;
    const nodeId = input.dataset.nodeId;
    const field = input.dataset.field;
    const value = input.value;

    if (!nodeId || !field) return;
    const graphId = this.getGraphId();

    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;

    fetch(
      `/morphology/dependency-graphs/${graphId}/nodes/${nodeId}?${field}=${encodeURIComponent(value)}`,
      {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrfToken,
          Accept: "application/json",
        },
      }
    )
      .then((response) => {
        if (response.ok) {
          this.showSaveIndicator(input, "success");
          this.refreshGraphPreview();
        } else {
          this.showSaveIndicator(input, "error");
        }
      })
      .catch((error) => {
        console.error("Error saving node:", error);
        this.showSaveIndicator(input, "error");
      });
  }

  saveEdgeField(event) {
    const input = event.target;
    const edgeId = input.dataset.edgeId;
    const field = input.dataset.field;
    const value = input.value;

    if (!edgeId || !field) return;
    const graphId = this.getGraphId();

    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;

    fetch(
      `/morphology/dependency-graphs/${graphId}/edges/${edgeId}?${field}=${encodeURIComponent(value)}`,
      {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrfToken,
          Accept: "application/json",
        },
      }
    )
      .then((response) => {
        if (response.ok) {
          this.showSaveIndicator(input, "success");
          this.refreshGraphPreview();
        } else {
          this.showSaveIndicator(input, "error");
        }
      })
      .catch((error) => {
        console.error("Error saving edge:", error);
        this.showSaveIndicator(input, "error");
      });
  }

  showSaveIndicator(input, status) {
    const originalBorder = input.style.borderColor;
    input.style.borderColor = status === "success" ? "#28a745" : "#dc3545";
    setTimeout(() => {
      input.style.borderColor = originalBorder;
    }, 1000);
  }

  savePhraseNodeField(event) {
    const input = event.target;
    const nodeId = input.dataset.nodeId;
    const row = document.querySelector(`.node-row[data-node-id="${nodeId}"]`);

    if (!row) return;
    const graphId = this.getGraphId();

    const phrasePos = row.querySelector(".phrase-pos-input")?.value || "";
    const phraseSource =
      row.querySelector(".phrase-source-select")?.value || "";
    const phraseTarget =
      row.querySelector(".phrase-target-select")?.value || "";

    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;

    const params = new URLSearchParams({
      phrase_pos: phrasePos,
      phrase_source: phraseSource,
      phrase_target: phraseTarget,
    });

    fetch(`/morphology/dependency-graphs/${graphId}/nodes/${nodeId}?${params.toString()}`, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        Accept: "application/json",
      },
    })
      .then((response) => {
        if (response.ok) {
          this.showSaveIndicator(input, "success");
          this.refreshGraphPreview();
        } else {
          this.showSaveIndicator(input, "error");
        }
      })
      .catch((error) => {
        console.error("Error saving phrase node:", error);
        this.showSaveIndicator(input, "error");
      });
  }

  handleNodeTypeChange(event) {
    const nodeId = event.target.dataset.nodeId;
    const nodeType = event.target.value;
    const graphId = this.getGraphId();

    this.saveNodeField(event);

    fetch(
      `/morphology/dependency-graphs/${graphId}/nodes/${nodeId}/fields?node_type=${nodeType}`,
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
      resourceTypeSelect.value = "Morphology::DependencyGraph::GraphNodeEdge";
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

    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;
    const graphId = this.getGraphId();

    fetch(`/morphology/dependency-graphs/${graphId}/nodes/${nodeId}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": csrfToken,
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => {
        if (response.ok) {
          return response.text();
        } else {
          throw new Error("Failed to delete node");
        }
      })
      .then((html) => {
        Turbo.renderStreamMessage(html);
        this.updateNodeCount();
        this.updatePhraseNodeCount();
        this.refreshGraphPreview();
      })
      .catch((error) => {
        console.error("Error:", error);
        alert("Failed to delete node");
      });
  }

  addNodeAfter(event) {
    event.preventDefault();
    const currentNodeId = event.currentTarget.dataset.nodeId;
    const graphId = this.getGraphId();

    fetch(
      `/morphology/dependency-graphs/${graphId}/nodes?after_node_id=${currentNodeId}`,
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
        this.refreshGraphPreview();
      })
      .catch((error) => {
        console.error("Error adding node:", error);
      });
  }

  getGraphId() {
    const graphIdInput =
      document.getElementById("graph_id") ||
      document.querySelector('input[name="graph_id"]');
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

  updatePhraseNodeCount() {
    const rows = document.querySelectorAll("#phrase_nodes_tbody .node-row");
    const countSpan = document.querySelector(".phrase-node-count");
    if (countSpan) {
      countSpan.textContent = rows.length;
    }
  }

  addPhraseNode(event) {
    event.preventDefault();
    const graphId = this.getGraphId();
    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;

    fetch(`/morphology/dependency-graphs/${graphId}/nodes?type=phrase`, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => response.text())
      .then((html) => {
        Turbo.renderStreamMessage(html);
        this.updatePhraseNodeCount();
        this.refreshGraphPreview();
      })
      .catch((error) => {
        console.error("Error adding phrase node:", error);
        alert("Failed to add phrase node");
      });
  }

  addEdge(event) {
    event.preventDefault();
    const graphId = this.getGraphId();
    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;

    fetch(`/morphology/dependency-graphs/${graphId}/edges`, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => response.text())
      .then((html) => {
        Turbo.renderStreamMessage(html);
        this.updateEdgeCount();
        this.refreshGraphPreview();
      })
      .catch((error) => {
        console.error("Error adding edge:", error);
        alert("Failed to add edge");
      });
  }

  removeEdge(event) {
    const edgeId = event.currentTarget.dataset.edgeId;
    const row = document.querySelector(`.edge-row[data-edge-id="${edgeId}"]`);
    if (!row) return;

    if (!confirm("Are you sure you want to delete this edge?")) return;

    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;
    const graphId = this.getGraphId();

    fetch(`/morphology/dependency-graphs/${graphId}/edges/${edgeId}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": csrfToken,
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => {
        if (response.ok) {
          return response.text();
        } else {
          throw new Error("Failed to delete edge");
        }
      })
      .then((html) => {
        Turbo.renderStreamMessage(html);
        this.updateEdgeCount();
        this.refreshGraphPreview();
      })
      .catch((error) => {
        console.error("Error deleting edge:", error);
        alert("Failed to delete edge");
      });
  }

  updateEdgeCount() {
    const rows = document.querySelectorAll(".edge-row");
    const countSpan = document.querySelector(".edge-count");
    if (countSpan) {
      countSpan.textContent = rows.length;
    }
  }
}
