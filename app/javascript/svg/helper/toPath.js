import {toPath} from 'svg-points'
//import { remove } from 'points'

import simplify from 'simplify-js';
import Snap from 'snapsvg';

const mergeBasePath = (points) => {
    const basePaths = points
        .filter(path => path.rule == 'rule_normal');

    let basePathPoints = [];
    /*
    basePaths.forEach((path) => {
        path.points.forEach(point => {
            basePathPoints.push({x: point[0], y: point[1]})
        })
    })

    return toPath(basePathPoints);
    */

    basePaths.forEach((path) => {
      basePathPoints.push(path.path)
    })

    const continousPath = joinPath(basePathPoints)
    return continousPath.join("");
    /*
    const allPaths = continousPath.forEach(p => {
     return {'type': 'path', 'd': p}
    })

    return toPath(allPaths)*/
}

const joinPath = (pathData)  => {
    function pathToAbsoluteSubPaths(path_string) {
        var path_commands = Snap.parsePathString(path_string),
            end_point = [0,0],
            sub_paths = [],
            command = [],
            i = 0;

        while (i < path_commands.length) {

            command = path_commands[i];
            end_point = getNextEndPoint(end_point, command);
            if (command[0] === 'm') {
                command = ['M', end_point[0], end_point[1]];
            }
            var sub_path = [command.join(' ')];


            i++;

            while (!endSubPath(path_commands, i)) {

                command = path_commands[i];
                sub_path.push(command.join(' '));
                end_point = getNextEndPoint(end_point, command);
                i++;
            }

            sub_paths.push(sub_path.join(' '));
        };

        return sub_paths;
    };

    function getNextEndPoint(end_point, command) {
        var x = end_point[0], y = end_point[1];
        if (isRelative(command)) {
            switch(command[0]) {
                case 'h':
                    x += command[1];
                    break;
                case 'v':
                    y += command[1];
                    break;
                case 'z':
                    // back to [0,0]?
                    x = 0;
                    y = 0;
                    break;
                default:
                    x += command[command.length - 2];
                    y += command[command.length - 1];
            };
        } else {
            switch(command[0]) {
                case 'H':
                    x = command[1];
                    break;
                case 'V':
                    y = command[1];
                    break;
                case 'Z':
                    // back to [0,0]?
                    x = 0;
                    y = 0
                    break;
                default:
                    x = command[command.length - 2];
                    y = command[command.length - 1];
            };
        }
        return [x, y];
    }

    function isRelative(command) {
        return command[0] === command[0].toLowerCase();
    }

    function endSubPath(commands, index) {
        if (index >= commands.length) {
            return true;
        } else {
            return commands[index][0].toLowerCase() === 'm';
        }
    }

    return pathToAbsoluteSubPaths(pathData);
};


export default mergeBasePath;