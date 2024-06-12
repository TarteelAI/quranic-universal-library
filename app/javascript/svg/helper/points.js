//https://shinao.github.io/PathToPoints/
// https://github.com/Yqnn/svg-path-editor
// http://bl.ocks.org/bycoffe/18441cddeb8fe147b719fab5e30b5d45
// https://stackoverflow.com/questions/41609438/how-to-split-one-path-into-two-paths-in-svg
// https://gist.github.com/iconifyit/958e7abba71806d663de6c2c273dc0da
// https://codepen.io/thebabydino/pen/EKLNvZ
// http://mourner.github.io/simplify-js/
import simplify from 'simplify-js';
import Raphael from "raphael";

const simplifyPoints = (points) => simplify(points);

const parseSvgPaths = (svg, stepSize) => {
    const parser = new DOMParser();
    const doc = parser.parseFromString(svg, "application/xml");
    const paths = doc.getElementsByTagName("path");
    let svgPaths = [];
    const viewBox = doc.firstChild.viewBox.baseVal;

    for (var i = 0; i < paths.length; ++i) {
        var node = $($(paths).get(i));
        var color = node.attr('fill');
        var rule = node.attr('id');
        var path = node.attr('d').replace(' ', ',');

        // get points at regular intervals
        var pathPoints = [];

        var c;
        for (c = 0; c < Raphael.getTotalLength(path); c += stepSize) {
            var point = Raphael.getPointAtLength(path, c);
            pathPoints.push([point.x, point.y])
        }

        svgPaths.push(
            {
                rule: rule,
                color: color,
                path: path,
                points: pathPoints
            }
        )
    }

    return {paths: svgPaths, viewBox: viewBox};
}

function getInfosFromPaths(paths, paper) {
    let info = [];
    let initialized = false;
    let allPath = $(paths);

    for (var i = 0; i < paths.length; ++i) {
        var path = $(allPath.get(i)).attr('d').replace(' ', ',');
        var shape = paper.path(path);
        var bbox_path = shape.getBBox();
        shape.remove();

        if (!initialized) {
            initialized = true;
            info.bbox_top = info.bbox_bottom = info.bbox_left = info.bbox_right = bbox_path;
            continue;
        }

        if (info.bbox_top != bbox_path && (info.bbox_top.y > bbox_path.y))
            info.bbox_top = bbox_path;
        if (info.bbox_bottom != bbox_path && (bbox_path.y + bbox_path.height > info.bbox_bottom.y + info.bbox_bottom.height))
            info.bbox_bottom = bbox_path;
        if (info.bbox_left != bbox_path && (info.bbox_left.x > bbox_path.x))
            info.bbox_left = bbox_path;
        if (info.bbox_right != bbox_path && (bbox_path.x + bbox_path.width > info.bbox_right.x + info.bbox_right.width))
            info.bbox_right = bbox_path;
    }

    info.width = (info.bbox_right.x + info.bbox_right.width) - info.bbox_left.x;
    info.height = (info.bbox_bottom.y + info.bbox_bottom.height) - info.bbox_top.y;
    info.x = info.bbox_left.x;
    info.y = info.bbox_top.y;
    if (info.height > info.width)
        info.scale = (info.height > paper.canvas.clientHeight) ? (paper.canvas.clientHeight / info.height) : 1;
    else
        info.scale = (info.width > paper.canvas.clientWidth) ? (paper.canvas.clientWidth / info.width) : 1;

    return info;
}

export {
    simplifyPoints,
    parseSvgPaths
};