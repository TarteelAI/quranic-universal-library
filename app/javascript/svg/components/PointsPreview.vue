<template>
  <div class="row my-2">
    <div class="col-12 my-2 d-flex justify-content-center align-items-center">
      <div id="path-info">
        <table class="table table-bordered">
          <thead>
          <tr>
            <th>Rule</th>
            <th>Color</th>
            <th>Original Points</th>
            <th>New Points</th>
          </tr>
          </thead>
          <tbody>
          <tr v-for="(path, index) in paths"
              :key="index">
            <td>
              {{ path.rule }}
            </td>
            <td>
              {{ path.color }}
            </td>
            <td>

            </td>
            <td>
              {{ path.points.length }}
            </td>
          </tr>
          </tbody>
        </table>
      </div>
      <div id="point-canvas">
      </div>
    </div>

    <div class="col-12">
      <div id="info-canvas">
      </div>
    </div>

    <div class="col-12">
      <div id="merged-base-path-canvas">
      </div>
    </div>
  </div>
</template>

<script>
import {mapState} from "vuex";
import Raphael from "raphael";
import {Tooltip} from "bootstrap";

export default {
  name: "PointsPreview",
  data() {
    return {
      paper: null,
      infoPaper: null
    }
  },
  mounted() {},
  created() {
    this.unwatchBasePathCanvas = this.$store.watch(
        (state) => state.mergedBasePath,
        (newValue, _) => {
          if (newValue.path) {
            this.renderMergedBasePath();
          }
        }
    );

    this.unwatch = this.$store.watch(
        (state) => state.paths,
        (newValue, _) => {
          if (newValue.length > 0) {
            this.render();
          }
        }
    );
  },
  computed: {
    ...mapState([
      "paths",
      "stepSize",
      "viewBox",
      "mergedBasePath"
    ]),
    pathsAreReady() {
      return this.paths.length > 0
    }
  },
  methods: {
    renderMergedBasePath(){
      this.mergedBasePaper = this.mergedBasePaper || Raphael(document.getElementById("merged-base-path-canvas"), '600px', '600px');
      this.mergedBasePaper.setViewBox(this.viewBox.x, this.viewBox.y, this.viewBox.width, this.viewBox.height);
      this.mergedBasePaper.clear();
      const path = this.mergedBasePath.path.replace(' ', ',');
      this.mergedBasePaper.path(path);
    },

    render() {
      this.paper = this.paper || Raphael(document.getElementById("point-canvas"), '900px', '700px');
      this.paper.clear();

      this.renderInfo = true;
      if (this.renderInfo) {
        this.infoPaper = this.infoPaper || Raphael(document.getElementById("info-canvas"), '600px', '600px');
        this.infoPaper.setViewBox(this.viewBox.x, this.viewBox.y, this.viewBox.width, this.viewBox.height);
        this.infoPaper.clear();
      }

      var boundingBox = this.getBoundingBox(this.paths, this.paper);
      var offset_path_x = (boundingBox.x * boundingBox.scale * -1) + (this.paper.canvas.clientWidth / 2) - (boundingBox.width * boundingBox.scale / 2);
      var offset_path_y = (boundingBox.y * boundingBox.scale * -1) + (this.paper.canvas.clientHeight / 2) - (boundingBox.height * boundingBox.scale / 2);

      for (var i = 0; i < this.paths.length; ++i) {
        const color = this.paths[i].color;
        const path = this.paths[i].path.replace(' ', ',');
        const rule = this.paths[i].rule;

        if (this.renderInfo) {
          var shape = this.infoPaper.path(path);
          var bbox_path = shape.getBBox();
          shape.id = rule;
          shape.attr({fill: color, id: rule});

          //shape.remove();
          const container = this.infoPaper.rect(bbox_path.x, bbox_path.y, bbox_path.width, bbox_path.height);
          container.attr("stroke", "red");
        }

        var c;
        for (c = 0; c < Raphael.getTotalLength(path); c += this.stepSize) {
          const point = Raphael.getPointAtLength(path, c);

          const circle = this.paper.circle(point.x * boundingBox.scale, point.y * boundingBox.scale, 2)
              .attr("fill", color)
              .attr("stroke", "none")
              .transform("T" + offset_path_x * boundingBox.scale + "," + offset_path_y * boundingBox.scale);
        }
      }
    },

    renderInfo() {
      var boundingBox = this.getBoundingBox(this.paths, this.paper);

      // paper.path(path);
      //var container = paper.rect(bbox_path.x, bbox_path.y, bbox_path.width, bbox_path.height);
      //container.attr("stroke", "red");
    },

    getBoundingBox(shapes, paper) {
      let boundingBox = [];
      let initialized = false;
      for (var i = 0; i < shapes.length; ++i) {
        const path = shapes[i].path.replace(' ', ',');
        let shape = paper.path(path);
        const bboxPath = shape.getBBox();
        shape.remove();

        // Draw the shape
        //var shape = paper.path(path);
        //var bboxPath = shape.getBBox();
        //shape.remove();

        // Show shapes infos
        // paper.path(path);
        //var container = paper.rect(bboxPath.x, bboxPath.y, bboxPath.width, bboxPath.height);
        //container.attr("stroke", "red");

        if (!initialized) {
          initialized = true;
          boundingBox.bbox_top = boundingBox.bbox_bottom = boundingBox.bbox_left = boundingBox.bbox_right = bboxPath;
          continue;
        }

        if (boundingBox.bbox_top != bboxPath && (boundingBox.bbox_top.y > bboxPath.y))
          boundingBox.bbox_top = bboxPath;
        if (boundingBox.bbox_bottom != bboxPath && (bboxPath.y + bboxPath.height > boundingBox.bbox_bottom.y + boundingBox.bbox_bottom.height))
          boundingBox.bbox_bottom = bboxPath;
        if (boundingBox.bbox_left != bboxPath && (boundingBox.bbox_left.x > bboxPath.x))
          boundingBox.bbox_left = bboxPath;
        if (boundingBox.bbox_right != bboxPath && (bboxPath.x + bboxPath.width > boundingBox.bbox_right.x + boundingBox.bbox_right.width))
          boundingBox.bbox_right = bboxPath;
      }

      boundingBox.width = (boundingBox.bbox_right.x + boundingBox.bbox_right.width) - boundingBox.bbox_left.x;
      boundingBox.height = (boundingBox.bbox_bottom.y + boundingBox.bbox_bottom.height) - boundingBox.bbox_top.y;
      boundingBox.x = boundingBox.bbox_left.x;
      boundingBox.y = boundingBox.bbox_top.y;
      if (boundingBox.height > boundingBox.width)
        boundingBox.scale = (boundingBox.height > paper.canvas.clientHeight) ? (paper.canvas.clientHeight / boundingBox.height) : 1;
      else
        boundingBox.scale = (boundingBox.width > paper.canvas.clientWidth) ? (paper.canvas.clientWidth / boundingBox.width) : 1;

      // console.log(boundingBox);
      // Display bboxes used for centering paths
      // var bboxes = [boundingBox.bbox_right, boundingBox.bbox_left, boundingBox.bbox_top, boundingBox.bbox_bottom];
      // for (var i = 0; i < 4; ++i) {
      //     var container = paper.rect(bboxes[i].x + 300, bboxes[i].y + 300, bboxes[i].width, bboxes[i].height);
      //     container.attr("stroke", "red");
      // }

      return boundingBox;
    },
  },
};
</script>

<style>
#point-canvas {
  flex-grow: 2;
}
</style>
