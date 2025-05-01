import { application } from "./application"

import AjaxModalController from "./ajax_modal_controller.js"
application.register("ajax-modal", AjaxModalController)

import ConfirmLeaveController from "./confirm_leave_controller.js"
application.register("confirm-leave", ConfirmLeaveController)

import DatepickerController from "./datepicker_controller.js"
application.register("datepicker", DatepickerController)

import RemoteSelect2Controller from "./remote_select2_controller.js"
application.register("remote-select2", RemoteSelect2Controller)

import MushafPageController from "./mushaf_page_controller.js"
application.register("mushaf-page", MushafPageController)

import Select2Controller from "./select2_controller.js"
application.register("select2", Select2Controller)

import TajweedHighlightController from "./tajweed_highlight_controller.js"
application.register("tajweed-highlight", TajweedHighlightController)

import TajweedFontController from "./tajweed_font_controller.js"
application.register("tajweed-font", TajweedFontController)

import TranslationController from "./translation_controller.js"
application.register("translation", TranslationController)

import TinymceController from "./tinymce_controller.js"
application.register("tinymce", TinymceController)

import PdfViewerController from "./pdf_viewer_controller.js"
application.register("pdf-viewer", PdfViewerController)

import JsonEditController from "./json_editor_controller.js"
application.register("json-editor", JsonEditController)

import FlashMessageController from "./flash_message_controller.js"
application.register("flash-message", FlashMessageController)

import PeityController from "./peity_controller.js"
application.register("peity", PeityController)

import AdminPageController from "./admin_page_controller.js"
application.register("admin-page", AdminPageController)

import TogglePasswordController from './toggle_password_controller';
application.register("toggle-password", TogglePasswordController);

import FilterAyahController from './filter_ayah_controller';
application.register("filter-ayah", FilterAyahController);

import ResizeableController from "./resizeable_controller.js"
application.register("resizeable", ResizeableController)

import EventTrackerController from "./event_tracker_controller"
application.register("event-tracker", EventTrackerController);