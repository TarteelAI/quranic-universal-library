import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "loadingState",
    "contentState",
    "graphsContainer",
    "graphTemplate",
    "nodeTemplate",
    "errorContainer",
    "saveButton",
    "saveButtonText",
    "saveButtonSpinner",
    "dropzone"
  ];

  static values = {
    chapter: Number,
    verse: Number
  };

  connect() {
    this.draggedNode = null;
    this.sourceGraphId = null;
    this.graphsData = [];
    this.nextTempGraphId = -1;
    
    const modalElement = document.getElementById("graphSplitterModal");
    if (modalElement) {
      this.setupModal(modalElement);
    }
  }

  setupModal(modalElement) {
    const showButtons = document.querySelectorAll('[data-bs-target="#graphSplitterModal"]');
    showButtons.forEach(button => {
      button.addEventListener('click', (e) => {
        e.preventDefault();
        this.showModal(modalElement);
        this.loadGraphsData();
      });
    });

    const closeButtons = modalElement.querySelectorAll('[data-action*="closeModal"], [data-bs-dismiss="modal"]');
    closeButtons.forEach(button => {
      button.addEventListener('click', (e) => {
        e.preventDefault();
        this.hideModal(modalElement);
      });
    });

    modalElement.addEventListener('click', (e) => {
      if (e.target === modalElement) {
        this.hideModal(modalElement);
      }
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !modalElement.classList.contains('tw-hidden')) {
        this.hideModal(modalElement);
      }
    });
  }

  showModal(modalElement) {
    const backdrop = document.createElement('div');
    backdrop.className = 'modal-backdrop tw-fixed tw-inset-0 tw-bg-black tw-bg-opacity-50 tw-transition-opacity tw-duration-300 tw-z-[9998]';
    backdrop.style.opacity = '0';
    document.body.appendChild(backdrop);
    
    modalElement.classList.remove('tw-hidden');
    modalElement.setAttribute('aria-hidden', 'false');
    document.body.classList.add('modal-open');
    document.body.style.overflow = 'hidden';
    
    requestAnimationFrame(() => {
      backdrop.style.opacity = '1';
      modalElement.classList.remove('tw-opacity-0');
      modalElement.classList.add('tw-opacity-100');
    });
  }

  async loadGraphsData() {
    console.log("loadGraphsData called", this.chapterValue, this.verseValue);
    try {
      const url = `/morphology/treebank/verse_graphs_data?chapter_number=${this.chapterValue}&verse_number=${this.verseValue}`;
      console.log("Fetching from:", url);
      
      const response = await fetch(url);
      console.log("Response status:", response.status);
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error("Response error:", errorText);
        throw new Error(`HTTP ${response.status}: ${errorText}`);
      }
      
      const data = await response.json();
      console.log("Data received:", data);
      
      this.graphsData = data.graphs;
      this.renderGraphs();
      
      this.loadingStateTarget.classList.add("tw-hidden");
      this.contentStateTarget.classList.remove("tw-hidden");
    } catch (error) {
      console.error("Error loading graphs:", error);
      this.showError("Failed to load graphs data. Please try again.");
      this.loadingStateTarget.classList.add("tw-hidden");
      this.contentStateTarget.classList.remove("tw-hidden");
    }
  }

  renderGraphs() {
    this.graphsContainerTarget.innerHTML = "";
    
    this.graphsData.forEach(graph => {
      const graphElement = this.createGraphElement(graph);
      this.graphsContainerTarget.appendChild(graphElement);
    });
  }

  createGraphElement(graph) {
    const template = this.graphTemplateTarget.content.cloneNode(true);
    const graphCard = template.querySelector(".graph-card");
    
    graphCard.dataset.graphId = graph.id;
    graphCard.querySelector(".graph-number").textContent = `#${graph.graph_number}`;
    graphCard.querySelector(".node-count").textContent = `${graph.nodes.length} nodes`;
    
    const nodesList = graphCard.querySelector(".nodes-list");
    const emptyState = graphCard.querySelector(".empty-state");
    
    if (graph.nodes.length === 0) {
      emptyState.classList.remove("tw-hidden");
    } else {
      graph.nodes.forEach(node => {
        const nodeElement = this.createNodeElement(node);
        nodesList.appendChild(nodeElement);
      });
    }
    
    return graphCard;
  }

  createNodeElement(node) {
    const template = this.nodeTemplateTarget.content.cloneNode(true);
    const nodeItem = template.querySelector(".node-item");
    
    nodeItem.dataset.nodeId = node.id;
    nodeItem.dataset.allNodeIds = JSON.stringify(node.all_node_ids || [node.id]);
    nodeItem.querySelector(".node-display-text").textContent = node.text;
    nodeItem.querySelector(".node-location").textContent = node.location;
    nodeItem.querySelector(".node-type").textContent = node.type;
    
    return nodeItem;
  }

  createNewGraph() {
    const newGraph = {
      id: this.nextTempGraphId--,
      graph_number: "New",
      nodes: []
    };
    
    this.graphsData.push(newGraph);
    
    const graphElement = this.createGraphElement(newGraph);
    this.graphsContainerTarget.appendChild(graphElement);
  }

  handleDragStart(event) {
    this.draggedNode = event.currentTarget;
    this.sourceGraphId = event.currentTarget.closest(".graph-card").dataset.graphId;
    
    event.currentTarget.classList.add("tw-opacity-50");
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/html", event.currentTarget.innerHTML);
  }

  handleDragEnd(event) {
    event.currentTarget.classList.remove("tw-opacity-50");
    
    this.dropzoneTargets.forEach(dropzone => {
      dropzone.classList.remove("tw-border-blue-500", "tw-bg-blue-50");
    });
  }

  handleDragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";
    
    const dropzone = event.currentTarget;
    dropzone.classList.add("tw-border-blue-500", "tw-bg-blue-50");
  }

  handleDragLeave(event) {
    const dropzone = event.currentTarget;
    
    if (!dropzone.contains(event.relatedTarget)) {
      dropzone.classList.remove("tw-border-blue-500", "tw-bg-blue-50");
    }
  }

  handleDrop(event) {
    event.preventDefault();
    event.stopPropagation();
    
    if (!this.draggedNode) return;
    
    // Find the dropzone - could be the current target or a parent
    let dropzone = event.currentTarget;
    if (!dropzone.classList.contains('graph-dropzone')) {
      dropzone = dropzone.closest('.graph-dropzone');
    }
    
    // Remove highlight from all dropzones
    this.dropzoneTargets.forEach(dz => {
      dz.classList.remove("tw-border-blue-500", "tw-bg-blue-50");
    });
    
    const targetGraphCard = dropzone.closest(".graph-card");
    const targetGraphId = targetGraphCard.dataset.graphId;
    
    if (this.sourceGraphId === targetGraphId) {
      return;
    }
    
    const nodesList = dropzone.querySelector(".nodes-list");
    const emptyState = dropzone.querySelector(".empty-state");
    
    nodesList.appendChild(this.draggedNode);
    emptyState.classList.add("tw-hidden");
    
    this.updateNodeCounts();
    this.updateEmptyStates();
    
    this.draggedNode = null;
    this.sourceGraphId = null;
  }

  updateNodeCounts() {
    const graphCards = this.graphsContainerTarget.querySelectorAll(".graph-card");
    
    graphCards.forEach(card => {
      const nodeCount = card.querySelectorAll(".node-item").length;
      card.querySelector(".node-count").textContent = `${nodeCount} nodes`;
    });
  }

  updateEmptyStates() {
    const graphCards = this.graphsContainerTarget.querySelectorAll(".graph-card");
    
    graphCards.forEach(card => {
      const nodesList = card.querySelector(".nodes-list");
      const emptyState = card.querySelector(".empty-state");
      const hasNodes = nodesList.querySelectorAll(".node-item").length > 0;
      
      if (hasNodes) {
        emptyState.classList.add("tw-hidden");
      } else {
        emptyState.classList.remove("tw-hidden");
      }
    });
  }

  async saveChanges() {
    this.hideError();
    
    const changedGraphs = this.getChangedGraphs();
    
    if (changedGraphs.length === 0) {
      this.showError("No changes detected. Please move some nodes between graphs.");
      return;
    }
    
    this.saveButtonTarget.disabled = true;
    this.saveButtonTextTarget.classList.add("tw-hidden");
    this.saveButtonSpinnerTarget.classList.remove("tw-hidden");
    
    try {
      for (const change of changedGraphs) {
        await this.splitGraph(change.sourceGraphId, change.nodeIds);
      }
      
      const modalElement = document.getElementById("graphSplitterModal");
      if (modalElement) {
        this.hideModal(modalElement);
      }
      
      window.location.reload();
    } catch (error) {
      console.error("Error saving changes:", error);
      this.showError(error.message || "Failed to save changes. Please try again.");
      
      this.saveButtonTarget.disabled = false;
      this.saveButtonTextTarget.classList.remove("tw-hidden");
      this.saveButtonSpinnerTarget.classList.add("tw-hidden");
    }
  }

  getChangedGraphs() {
    const changes = [];
    const graphCards = this.graphsContainerTarget.querySelectorAll(".graph-card");
    
    graphCards.forEach(card => {
      const graphId = parseInt(card.dataset.graphId);
      
      // Collect all node IDs including segments
      const currentNodeIds = Array.from(card.querySelectorAll(".node-item"))
        .map(node => parseInt(node.dataset.nodeId));
      
      const currentAllNodeIds = Array.from(card.querySelectorAll(".node-item"))
        .flatMap(node => JSON.parse(node.dataset.allNodeIds || '[]'));
      
      const originalGraph = this.graphsData.find(g => g.id === graphId);
      if (!originalGraph) return;
      
      const originalNodeIds = originalGraph.nodes.map(n => n.id);
      
      const addedNodes = currentNodeIds.filter(id => !originalNodeIds.includes(id));
      
      if (addedNodes.length > 0) {
        // Get all node IDs (including segments) for the added nodes
        const addedNodeElements = Array.from(card.querySelectorAll(".node-item"))
          .filter(node => addedNodes.includes(parseInt(node.dataset.nodeId)));
        
        const allNodeIdsToMove = addedNodeElements
          .flatMap(node => JSON.parse(node.dataset.allNodeIds || '[]'));
        
        changes.push({
          sourceGraphId: this.findOriginalGraphForNodes(addedNodes),
          targetGraphId: graphId,
          nodeIds: allNodeIdsToMove
        });
      }
    });
    
    return changes;
  }

  findOriginalGraphForNodes(nodeIds) {
    for (const graph of this.graphsData) {
      const hasAllNodes = nodeIds.every(nodeId => 
        graph.nodes.some(n => n.id === nodeId)
      );
      if (hasAllNodes) {
        return graph.id;
      }
    }
    return null;
  }

  async splitGraph(sourceGraphId, nodeIds) {
    const response = await fetch("/morphology/treebank/split_graph", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({
        graph_id: sourceGraphId,
        node_ids: nodeIds
      })
    });
    
    const data = await response.json();
    
    if (!response.ok || !data.success) {
      throw new Error(data.errors?.join(", ") || "Failed to split graph");
    }
    
    return data;
  }

  showError(message) {
    this.errorContainerTarget.querySelector('p').textContent = message;
    this.errorContainerTarget.classList.remove("tw-hidden");
  }

  hideError() {
    this.errorContainerTarget.classList.add("tw-hidden");
  }

  closeModal(event) {
    const modalElement = document.getElementById("graphSplitterModal");
    if (modalElement) {
      this.hideModal(modalElement);
    }
  }

  hideModal(modalElement) {
    modalElement.classList.remove('tw-opacity-100');
    modalElement.classList.add('tw-opacity-0');
    modalElement.setAttribute('aria-hidden', 'true');
    
    const backdrop = document.querySelector('.modal-backdrop');
    if (backdrop) {
      backdrop.style.opacity = '0';
      setTimeout(() => {
        if (backdrop.parentNode) {
          backdrop.parentNode.removeChild(backdrop);
        }
      }, 300);
    }
    
    document.body.classList.remove('modal-open');
    document.body.style.overflow = '';
    document.body.style.paddingRight = '';
    
    setTimeout(() => {
      modalElement.classList.add('tw-hidden');
    }, 300);
  }
}
