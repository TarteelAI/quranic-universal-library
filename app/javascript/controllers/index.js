import { application } from "./application";

import SegmentFailurePlayerController from './segments/failure_player_controller';
application.register("segments--failure-player", SegmentFailurePlayerController);
