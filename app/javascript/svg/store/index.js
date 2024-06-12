import {
    createStore,
    createLogger
} from "vuex";

import {simplifyPoints, parseSvgPaths} from "../helper/points";
import mergeBasePath from "../helper/toPath";

const debug = process.env.NODE_ENV !== "production";

const store = createStore({
    state() {
        return {
            alert: null,
            file: null,
            fileSize: 0,
            fileName: null,
            paths: [],
            svgData: null,
            stepSize: 10,
            viewBox: {},
            mergedBasePath: {}
        };
    },
    getters: {},
    mutations: {
        SET_ALERT(state, payload) {
          state.alert = payload.text;
        },
        SET_STEP_SIZE(state, payload){
          state.stepSize = Number(payload.size);
        }
    },
    actions: {
        LOAD_SVG_FILE({state}, payload) {
            state.file = payload.file;
            state.fileName = payload.file.name;
            state.fileSize = payload.file.size;
            state.alert = 'Loading';

            const reader = new FileReader();
            reader.readAsBinaryString(payload.file);
            reader.onloadend = () => {
                state.svgData = reader.result;
                state.alert = 'Ready'
            }
        },
        GENERATE_POINTS({state}, payload) {
            const result = parseSvgPaths(state.svgData, state.stepSize)
            state.paths = result.paths
            state.viewBox = result.viewBox;
        },
        MERGE_BASE_PATH({state}, payload) {
           const mergedBasePath = mergeBasePath(state.paths);
           state.mergedBasePath = {path: mergedBasePath, points: []};
          // state.paths = mergeBasePaths(state.paths);
        }
    },
    plugins: debug ? [createLogger()] : [],
});

export default store;